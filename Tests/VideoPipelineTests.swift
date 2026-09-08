import XCTest
import AVFoundation
@testable import RAFLI

final class VideoPipelineTests: XCTestCase {
    func testSourceCadenceCanvasAndVerification() async throws {
        for fps in [30, 60, 120] {
            let source = try await fixture(fps: fps)
            defer { try? FileManager.default.removeItem(at: source) }
            let report = try await VideoAnalyzer.analyze(source)
            XCTAssertEqual(report.width, 96)
            XCTAssertEqual(report.height, 160)
            let output = try await VideoProcessor.export(source: source, preset: .smart, report: report) { _ in }
            defer { try? FileManager.default.removeItem(at: output) }
            let actual = try await ExportVerifier.verify(output, source: report, preset: .smart)
            XCTAssertEqual(actual.width, 96, "Small sources must never be upscaled")
            XCTAssertEqual(actual.height, 160)
            XCTAssertEqual(actual.fps, Double(min(fps, 60)), accuracy: 1)
            XCTAssertEqual(actual.codec, "avc1")
        }
    }
    func testPassthroughAndPersistentLibrary() async throws {
        let source = try await fixture(fps: 30)
        defer { try? FileManager.default.removeItem(at: source) }
        let report = try await VideoAnalyzer.analyze(source)
        let output = try await VideoProcessor.export(source: source, preset: .preserve, report: report) { _ in }
        defer { try? FileManager.default.removeItem(at: output) }
        let verified = try await ExportVerifier.verify(output, source: report, preset: .preserve)
        XCTAssertEqual(verified.fps, 30, accuracy: 0.5)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = RAFLIStorage(root: root)
        _ = try await store.load()
        let video = StudioVideo(id: UUID(), url: output, thumbnail: nil, name: "Test", report: verified, libraryID: nil)
        let item = try await store.insert(video, kind: .processed, sourceID: nil)
        let reopened = RAFLIStorage(root: root)
        let items = try await reopened.load()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, item.id)
        try await reopened.delete(items)
        let empty = try await reopened.load()
        XCTAssertTrue(empty.isEmpty)
    }
    func testRotatedVideoKeepsPortraitOrientation() async throws {
        let source = try await fixture(fps: 30, rotated: true)
        defer { try? FileManager.default.removeItem(at: source) }
        let report = try await VideoAnalyzer.analyze(source)
        XCTAssertEqual(report.width, 96)
        XCTAssertEqual(report.height, 160)
        let out = try await VideoProcessor.export(source: source, preset: .tiktokSafe, report: report) { _ in }
        defer { try? FileManager.default.removeItem(at: out) }
        let actual = try await ExportVerifier.verify(out, source: report, preset: .tiktokSafe)
        XCTAssertEqual(actual.resolution, report.resolution)
    }
    private func fixture(fps: Int, rotated: Bool = false) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        let w = rotated ? 160 : 96, h = rotated ? 96 : 160
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        if rotated { input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: CGFloat(h), ty: 0) }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<fps {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer), kCVReturnSuccess)
            let pixel = buffer!
            CVPixelBufferLockBaseAddress(pixel, [])
            memset(CVPixelBufferGetBaseAddress(pixel), Int32(frame * 2 % 255), CVPixelBufferGetDataSize(pixel))
            CVPixelBufferUnlockBaseAddress(pixel, [])
            XCTAssertTrue(adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(fps))))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: 1, preferredTimescale: 600))
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        return url
    }
}
