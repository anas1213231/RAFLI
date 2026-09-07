import AVFoundation

final class VideoAnalyzer {
    static func analyze(_ url: URL) async throws -> VideoReport {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            throw NSError(domain: "RAFLI", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track"])
        }

        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let transformed = size.applying(transform)
        let w = Int(abs(transformed.width.rounded()))
        let h = Int(abs(transformed.height.rounded()))
        let fps = Double(try await track.load(.nominalFrameRate))
        let bitrate = Double(try await track.load(.estimatedDataRate)) / 1_000_000.0

        let descs = try await track.load(.formatDescriptions)
        var codec = "Unknown"
        if let fd = descs.first {
            codec = fourCC(CMFormatDescriptionGetMediaSubType(fd))
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attrs[.size] as? NSNumber)?.doubleValue ?? 0

        return VideoReport(
            width: w,
            height: h,
            fps: fps,
            bitrateMbps: bitrate,
            codec: codec,
            duration: duration,
            fileSizeMB: bytes / 1024 / 1024,
            hasAudio: !audioTracks.isEmpty
        )
    }

    private static func fourCC(_ code: FourCharCode) -> String {
        let chars: [UInt8] = [
            UInt8((code >> 24) & 255),
            UInt8((code >> 16) & 255),
            UInt8((code >> 8) & 255),
            UInt8(code & 255)
        ]
        return String(bytes: chars, encoding: .ascii) ?? "Unknown"
    }
}
