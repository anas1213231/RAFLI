@preconcurrency import AVFoundation
import CoreVideo
@preconcurrency import CoreImage
import UIKit

final class VideoProcessor {
    static func export(source: URL, preset: RAFLIPreset, report: VideoReport, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        if preset == .preserve { return try await passthrough(source: source) }
        return try await transcode(source: source, preset: preset, report: report, progress: progress)
    }

    private static func passthrough(source: URL) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { throw err(2, "Passthrough unavailable") }
        let out = persistentURL("RAFLI_ORIGINAL.mp4")
        try? FileManager.default.removeItem(at: out)
        session.outputURL = out; session.outputFileType = .mp4; session.shouldOptimizeForNetworkUse = true
        await session.export()
        guard session.status == .completed else { throw session.error ?? err(3, "Export failed") }
        UserDefaults.standard.set(out.path, forKey: "rafli_last_output")
        return out
    }

    private static func transcode(source: URL, preset: RAFLIPreset, report: VideoReport, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let vTrack = try await asset.loadTracks(withMediaType: .video).first else { throw err(4, "No video track") }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let natural = try await vTrack.load(.naturalSize)
        let preferred = try await vTrack.load(.preferredTransform)
        let transformed = natural.applying(preferred)
        let portrait = abs(transformed.height) >= abs(transformed.width)
        let targetW = portrait ? 1080 : 1920, targetH = portrait ? 1920 : 1080
        let sourceFPS = max(1.0, report.fps)
        // Never lie about FPS: source timing is preserved. A 30fps source is not labelled as true 60fps.
        let targetFPS = min(60.0, sourceFPS)
        let targetBitrate: Int = preset == .smart ? min(22_000_000, max(10_000_000, Int(max(6.0, report.bitrateMbps) * 1_000_000))) : preset.targetBitrate

        let reader = try AVAssetReader(asset: asset)
        let vOut = AVAssetReaderTrackOutput(track: vTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange])
        vOut.alwaysCopiesSampleData = false
        guard reader.canAdd(vOut) else { throw err(5, "Video reader unavailable") }; reader.add(vOut)

        var aOut: AVAssetReaderTrackOutput?
        if let aTrack = audioTracks.first {
            let output = AVAssetReaderTrackOutput(track: aTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: false, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsNonInterleaved: false])
            if reader.canAdd(output) { reader.add(output); aOut = output }
        }

        let outURL = persistentURL("RAFLI_ENHANCED.mp4")
        try? FileManager.default.removeItem(at: outURL)
        let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true; writer.movieFragmentInterval = .invalid
        let gop = max(1, Int((targetFPS * preset.keyframeSeconds).rounded()))
        let compression: [String: Any] = [AVVideoAverageBitRateKey: targetBitrate, AVVideoExpectedSourceFrameRateKey: Int(targetFPS.rounded()), AVVideoMaxKeyFrameIntervalKey: gop, AVVideoMaxKeyFrameIntervalDurationKey: preset.keyframeSeconds, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel, AVVideoAllowFrameReorderingKey: true, AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC]
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: targetW, AVVideoHeightKey: targetH, AVVideoCompressionPropertiesKey: compression])
        vIn.expectsMediaDataInRealTime = false
        guard writer.canAdd(vIn) else { throw err(6, "Video writer unavailable") }; writer.add(vIn)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vIn, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelBufferWidthKey as String: targetW, kCVPixelBufferHeightKey as String: targetH, kCVPixelBufferIOSurfacePropertiesKey as String: [:]])

        var aIn: AVAssetWriterInput?
        if aOut != nil {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 256_000])
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) { writer.add(input); aIn = input }
        }
        guard reader.startReading(), writer.startWriting() else { throw reader.error ?? writer.error ?? err(7, "Could not start encoding") }
        writer.startSession(atSourceTime: .zero)

        let duration = max(0.01, report.duration), ci = CIContext(options: [.cacheIntermediates: false])
        let targetRect = CGRect(x: 0, y: 0, width: targetW, height: targetH)
        let group = DispatchGroup(), stateQ = DispatchQueue(label: "com.ucorc.rafli.state")
        var failure: Error?
        group.enter()
        vIn.requestMediaDataWhenReady(on: DispatchQueue(label: "com.ucorc.rafli.video", qos: .userInitiated)) {
            while vIn.isReadyForMoreMediaData {
                if stateQ.sync(execute: { failure != nil }) { vIn.markAsFinished(); group.leave(); return }
                guard let sb = vOut.copyNextSampleBuffer() else { vIn.markAsFinished(); group.leave(); return }
                guard let src = CMSampleBufferGetImageBuffer(sb) else { continue }
                let pts = CMSampleBufferGetPresentationTimeStamp(sb); progress(min(0.985, max(0, pts.seconds / duration)))
                guard let pool = adaptor.pixelBufferPool else { stateQ.sync { failure = err(8, "Pixel buffer pool unavailable") }; reader.cancelReading(); vIn.markAsFinished(); group.leave(); return }
                var dst: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dst)
                guard let dst else { stateQ.sync { failure = err(9, "Could not allocate output frame") }; reader.cancelReading(); vIn.markAsFinished(); group.leave(); return }
                var image = CIImage(cvPixelBuffer: src).transformed(by: preferred)
                let e = image.extent; image = image.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
                let ie = image.extent, scale = max(targetRect.width / ie.width, targetRect.height / ie.height)
                image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                let se = image.extent, dx = (targetRect.width - se.width) / 2 - se.minX, dy = (targetRect.height - se.height) / 2 - se.minY
                image = image.transformed(by: CGAffineTransform(translationX: dx, y: dy)).cropped(to: targetRect)
                ci.render(image, to: dst, bounds: targetRect, colorSpace: CGColorSpaceCreateDeviceRGB())
                if !adaptor.append(dst, withPresentationTime: pts) { stateQ.sync { failure = writer.error ?? err(10, "Video append failed") }; reader.cancelReading(); vIn.markAsFinished(); group.leave(); return }
            }
        }
        if let aOut, let aIn {
            group.enter()
            aIn.requestMediaDataWhenReady(on: DispatchQueue(label: "com.ucorc.rafli.audio", qos: .userInitiated)) {
                while aIn.isReadyForMoreMediaData {
                    if stateQ.sync(execute: { failure != nil }) { aIn.markAsFinished(); group.leave(); return }
                    guard let sb = aOut.copyNextSampleBuffer() else { aIn.markAsFinished(); group.leave(); return }
                    if !aIn.append(sb) { stateQ.sync { failure = writer.error ?? err(11, "Audio append failed") }; reader.cancelReading(); aIn.markAsFinished(); group.leave(); return }
                }
            }
        }
        return try await withCheckedThrowingContinuation { cont in
            group.notify(queue: .global(qos: .userInitiated)) {
                if let f = stateQ.sync(execute: { failure }) { writer.cancelWriting(); cont.resume(throwing: f); return }
                writer.finishWriting {
                    if writer.status == .completed { UserDefaults.standard.set(outURL.path, forKey: "rafli_last_output"); progress(1); cont.resume(returning: outURL) }
                    else { cont.resume(throwing: writer.error ?? err(12, "Writer failed")) }
                }
            }
        }
    }

    private static func err(_ code: Int, _ text: String) -> NSError { NSError(domain: "RAFLI", code: code, userInfo: [NSLocalizedDescriptionKey: text]) }
    private static func persistentURL(_ name: String) -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("RAFLI Videos", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6))_\(name)")
    }
}
