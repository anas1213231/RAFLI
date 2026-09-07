import Foundation

struct VideoReport {
    var width: Int = 0
    var height: Int = 0
    var fps: Double = 0
    var bitrateMbps: Double = 0
    var codec: String = "unknown"
    var duration: Double = 0
    var fileSizeMB: Double = 0
    var hasAudio: Bool = false

    var is1080: Bool {
        let long = max(width, height), short = min(width, height)
        return long >= 1920 && short >= 1080
    }
    var is60: Bool { fps >= 59.0 }
    var score: Int {
        var s = 20
        let long = max(width,height), short = min(width,height)
        if long >= 2160 && short >= 1080 { s += 42 }
        else if long >= 1920 && short >= 1080 { s += 38 }
        else if long >= 1280 && short >= 720 { s += 27 }
        else if long >= 854 { s += 15 }
        if fps >= 59 { s += 25 } else if fps >= 29 { s += 15 }
        if bitrateMbps >= 14 { s += 10 } else if bitrateMbps >= 8 { s += 7 } else if bitrateMbps >= 4 { s += 4 }
        if ["avc1","h264","hvc1","hevc"].contains(codec.lowercased()) { s += 5 }
        return min(100,s)
    }
}

enum RAFLIPreset: String, CaseIterable, Identifiable {
    case preserve = "Preserve Original"
    case smart = "RAFLI Smart"
    case tiktokSafe = "TikTok Safe 1080"
    case highMotion = "High Motion"
    case maxQuality = "ULTRA MAX"
    case compact = "Compact"

    var id: String { rawValue }

    var targetBitrate: Int {
        switch self {
        case .preserve: return 0
        case .smart: return 18_000_000
        case .tiktokSafe: return 14_000_000
        case .highMotion: return 22_000_000
        case .maxQuality: return 30_000_000
        case .compact: return 8_000_000
        }
    }
    var keyframeSeconds: Double {
        switch self {
        case .preserve: return 2
        case .compact, .tiktokSafe: return 2
        case .smart, .highMotion, .maxQuality: return 1
        }
    }
}
