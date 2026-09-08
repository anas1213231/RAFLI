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
        let out = tempURL("RAFLI_PRESERVE.mp4")
        try? FileManager.default.removeItem(at: out)
        session.outputURL = out
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        await session.export()
        guard session.status == .completed else { try? FileManager.default.removeItem(at: out); throw session.error ?? err(3, "Export failed") }
        return out
    }

    private static func transcode(source: URL, preset: RAFLIPreset, report: VideoReport, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let vTrack = try await asset.loadTracks(withMediaType: .video).first else { throw err(4, "No video track") }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let natural = try await vTrack.load(.naturalSize)
        let preferred = try await vTrack.load(.preferredTransform)
        let transformed = CGRect(origin: .zero, size: natural).applying(preferred).size
        let displayW = max(2.0, abs(transformed.width))
        let displayH = max(2.0, abs(transformed.height))
        let portrait = displayH >= displayW

        let maxWidth = portrait ? 1080.0 : 1920.0
        let maxHeight = portrait ? 1920.0 : 1080.0
        let scale = min(1.0, min(maxWidth / displayW, maxHeight / displayH))
        let target = (even(Int((displayW * scale).rounded())), even(Int((displayH * scale).rounded())))
        let targetW = target.0
        let targetH = target.1

        let sourceFPS = max(1.0, report.fps)
        let targetFPS = min(60.0, sourceFPS)
        let targetBitrate = preset == .smart
            ? min(24_000_000, max(10_000_000, Int(max(6.0, report.bitrateMbps) * 1_000_000)))
            : preset.targetBitrate

        let reader = try AVAssetReader(asset: asset)
        let vOut = AVAssetReaderTrackOutput(track: vTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange])
        vOut.alwaysCopiesSampleData = false
        guard reader.canAdd(vOut) else { throw err(5, "Video reader unavailable") }
        reader.add(vOut)

        var aOut: AVAssetReaderTrackOutput?
        var audioChannels = 1
        if let aTrack = audioTracks.first {
            let formats = try await aTrack.load(.formatDescriptions)
            if let format = formats.first, let description = CMAudioFormatDescriptionGetStreamBasicDescription(format) {
                audioChannels = min(2, max(1, Int(description.pointee.mChannelsPerFrame)))
            }
            let output = AVAssetReaderTrackOutput(track: aTrack, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsNonInterleaved: false,
                AVNumberOfChannelsKey: audioChannels,
                AVSampleRateKey: 48_000
            ])
            guard reader.canAdd(output) else { throw err(13, "Audio reader unavailable") }
            reader.add(output); aOut = output
        }

        let outURL = tempURL("RAFLI_READY.mp4")
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: outURL) } }
        try? FileManager.default.removeItem(at: outURL)
        let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        writer.movieFragmentInterval = .invalid

        let gop = max(1, Int((targetFPS * preset.keyframeSeconds).rounded()))
        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: targetBitrate,
            AVVideoExpectedSourceFrameRateKey: Int(targetFPS.rounded()),
            AVVideoMaxKeyFrameIntervalKey: gop,
            AVVideoMaxKeyFrameIntervalDurationKey: preset.keyframeSeconds,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoAllowFrameReorderingKey: true,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
        ]

        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: targetW,
            AVVideoHeightKey: targetH,
            AVVideoCompressionPropertiesKey: compression
        ])
        vIn.expectsMediaDataInRealTime = false
        guard writer.canAdd(vIn) else { throw err(6, "Video writer unavailable") }
        writer.add(vIn)

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vIn, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: targetW,
            kCVPixelBufferHeightKey as String: targetH,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])

        var aIn: AVAssetWriterInput?
        if aOut != nil {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: audioChannels,
                AVEncoderBitRateKey: 256_000
            ])
            input.expectsMediaDataInRealTime = false
            guard writer.canAdd(input) else { throw err(14, "Audio writer unavailable") }
            writer.add(input); aIn = input
        }

        guard reader.startReading(), writer.startWriting() else { throw reader.error ?? writer.error ?? err(7, "Could not start encoding") }
        writer.startSession(atSourceTime: .zero)

        let duration = max(0.01, report.duration)
        let ci = CIContext(options: [.cacheIntermediates: false])
        let targetRect = CGRect(x: 0, y: 0, width: targetW, height: targetH)
        let group = DispatchGroup()
        let stateQ = DispatchQueue(label: "com.ucorc.rafli.state")
        let shared = EncodingState()

        group.enter()
        vIn.requestMediaDataWhenReady(on: DispatchQueue(label: "com.ucorc.rafli.video", qos: .userInitiated)) {
            while vIn.isReadyForMoreMediaData {
                if stateQ.sync(execute: { shared.failure != nil }) { vIn.markAsFinished(); group.leave(); return }
                guard let sb = vOut.copyNextSampleBuffer() else { vIn.markAsFinished(); group.leave(); return }
                guard let src = CMSampleBufferGetImageBuffer(sb) else { continue }
                let pts = CMSampleBufferGetPresentationTimeStamp(sb)
                // Drop source frames above 60 using timestamps; never duplicate or retime frames.
                if sourceFPS > 60.5 {
                    let bucket = Int((pts.seconds * targetFPS + 0.0001).rounded(.down))
                    if bucket <= shared.lastBucket { continue }
                    shared.lastBucket = bucket
                }
                let percent = Int(min(98, max(0, pts.seconds / duration * 100)))
                if percent != shared.lastPercent { shared.lastPercent = percent; progress(Double(percent) / 100) }
                guard let pool = adaptor.pixelBufferPool else {
                    stateQ.sync { shared.failure = err(8, "Pixel buffer pool unavailable") }
                    reader.cancelReading(); vIn.markAsFinished(); group.leave(); return
                }
                var dst: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dst)
                guard let dst else {
                    stateQ.sync { shared.failure = err(9, "Could not allocate output frame") }
                    reader.cancelReading(); vIn.markAsFinished(); group.leave(); return
                }

                var image = CIImage(cvPixelBuffer: src).transformed(by: preferred)
                let e = image.extent
                image = image.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
                let ie = image.extent
                let scale = min(targetRect.width / ie.width, targetRect.height / ie.height)
                image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                let se = image.extent
                let dx = (targetRect.width - se.width) / 2 - se.minX
                let dy = (targetRect.height - se.height) / 2 - se.minY
                image = image.transformed(by: CGAffineTransform(translationX: dx, y: dy))

                ci.render(CIImage(color: .black).cropped(to: targetRect), to: dst, bounds: targetRect, colorSpace: CGColorSpaceCreateDeviceRGB())
                ci.render(image, to: dst, bounds: targetRect, colorSpace: CGColorSpaceCreateDeviceRGB())

                if !adaptor.append(dst, withPresentationTime: pts) {
                    stateQ.sync { shared.failure = writer.error ?? err(10, "Video append failed") }
                    reader.cancelReading(); vIn.markAsFinished(); group.leave(); return
                }
            }
        }

        if let aOut, let aIn {
            group.enter()
            aIn.requestMediaDataWhenReady(on: DispatchQueue(label: "com.ucorc.rafli.audio", qos: .userInitiated)) {
                while aIn.isReadyForMoreMediaData {
                    if stateQ.sync(execute: { shared.failure != nil }) { aIn.markAsFinished(); group.leave(); return }
                    guard let sb = aOut.copyNextSampleBuffer() else { aIn.markAsFinished(); group.leave(); return }
                    if !aIn.append(sb) {
                        stateQ.sync { shared.failure = writer.error ?? err(11, "Audio append failed") }
                        reader.cancelReading(); aIn.markAsFinished(); group.leave(); return
                    }
                }
            }
        }

        let result: URL = try await withCheckedThrowingContinuation { cont in
            group.notify(queue: .global(qos: .userInitiated)) {
                if let f = stateQ.sync(execute: { shared.failure }) {
                    writer.cancelWriting(); try? FileManager.default.removeItem(at: outURL); cont.resume(throwing: f); return
                }
                guard reader.status == .completed else {
                    writer.cancelWriting(); try? FileManager.default.removeItem(at: outURL)
                    cont.resume(throwing: reader.error ?? err(15, "Reader did not complete")); return
                }
                writer.finishWriting {
                    if writer.status == .completed { progress(1); cont.resume(returning: outURL) }
                    else { try? FileManager.default.removeItem(at: outURL); cont.resume(throwing: writer.error ?? err(12, "Writer failed")) }
                }
            }
        }
        completed = true
        return result
    }

    private static func even(_ value: Int) -> Int { max(2, value - (value % 2)) }
    private static func err(_ code: Int, _ text: String) -> NSError { NSError(domain: "RAFLI", code: code, userInfo: [NSLocalizedDescriptionKey: text]) }
    private static func tempURL(_ name: String) -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + name) }
}

// failure is protected by stateQ; cadence/progress fields are confined to the video queue.
private final class EncodingState: @unchecked Sendable {
    var failure: Error?
    var lastBucket = -1
    var lastPercent = -1
}
