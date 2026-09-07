import Foundation
import AVFoundation

struct ExportCheck {
    let width: Int
    let height: Int
    let fps: Double
    let bitrateMbps: Double
    let duration: Double
    let fileSizeMB: Double
    let verdict: String
}

enum ExportVerifier {
    static func verify(_ url: URL) async throws -> ExportCheck {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain:"RAFLI.Verify",code:1,userInfo:[NSLocalizedDescriptionKey:"لا يوجد Video Track"])
        }
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let final = size.applying(transform)
        let fps = Double(try await track.load(.nominalFrameRate))
        let br = Double(try await track.load(.estimatedDataRate)) / 1_000_000
        let bytes = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.doubleValue ?? 0
        let w = Int(abs(final.width).rounded())
        let h = Int(abs(final.height).rounded())

        let long = max(w,h), short = min(w,h)
        var verdict = "READY"
        if long < 1920 || short < 1080 { verdict = "RESOLUTION CHECK" }
        if fps > 0 && fps < 29 { verdict = "FPS CHECK" }

        return ExportCheck(width:w,height:h,fps:fps,bitrateMbps:br,duration:duration,fileSizeMB:bytes/1024/1024,verdict:verdict)
    }
}
