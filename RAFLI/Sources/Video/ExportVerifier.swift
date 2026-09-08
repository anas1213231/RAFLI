import Foundation
import AVFoundation

enum ExportVerifier {
    static func verify(_ url: URL, source: VideoReport, preset: RAFLIPreset) async throws -> VideoReport {
        let actual = try await VideoAnalyzer.analyze(url)
        guard actual.fileSizeMB > 0,
              abs(actual.duration - source.duration) <= max(0.25, 2 / max(1, source.fps)),
              actual.hasAudio == source.hasAudio else { throw AppFailure.verifyFailed }
        if preset != .preserve {
            guard actual.codec == "avc1", actual.fps <= min(60, source.fps) + 0.6,
                  max(actual.width, actual.height) <= 1920, min(actual.width, actual.height) <= 1080,
                  actual.width <= source.width + 1, actual.height <= source.height + 1 else { throw AppFailure.verifyFailed }
            let sourceRatio = Double(source.width) / Double(source.height)
            let actualRatio = Double(actual.width) / Double(actual.height)
            guard abs(sourceRatio - actualRatio) <= 0.015 else { throw AppFailure.verifyFailed }
        }
        // Decode the resulting video, rather than trusting only its container metadata.
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 128, height: 128)
        _ = try await generator.image(at: .zero)
        _ = try await generator.image(at: CMTime(seconds: max(0, actual.duration - 0.15), preferredTimescale: 600))
        return actual
    }
}
