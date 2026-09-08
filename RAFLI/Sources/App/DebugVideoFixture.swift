#if DEBUG
import AVFoundation
import CoreVideo

// Only compiled into Debug builds. UI tests feed a real generated file through the normal import pipeline.
enum DebugVideoFixture {
    static func make() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Test-Motion-\(UUID()).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 568])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 568])
        writer.add(input)
        guard writer.startWriting() else { throw AppFailure.importFailed }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var pixel: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixel) == kCVReturnSuccess, let pixel else { throw AppFailure.importFailed }
            CVPixelBufferLockBaseAddress(pixel, [])
            let row = CVPixelBufferGetBytesPerRow(pixel)
            let bytes = CVPixelBufferGetBaseAddress(pixel)!.assumingMemoryBound(to: UInt8.self)
            for y in 0..<568 { for x in 0..<320 {
                let i = y * row + x * 4
                bytes[i] = UInt8(70 + y / 5)
                bytes[i + 1] = UInt8(60 + x / 3)
                bytes[i + 2] = UInt8(120 + frame)
                bytes[i + 3] = 255
            } }
            CVPixelBufferUnlockBaseAddress(pixel, [])
            guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else { throw AppFailure.importFailed }
        }
        input.markAsFinished(); writer.endSession(atSourceTime: CMTime(seconds: 2, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw AppFailure.importFailed }
        return url
    }
}
#endif
