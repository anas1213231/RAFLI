import Foundation

struct VideoReport: Codable, Hashable, Sendable {
    var width: Int = 0
    var height: Int = 0
    var fps: Double = 0
    var bitrateMbps: Double = 0
    var codec: String = "unknown"
    var duration: Double = 0
    var fileSizeMB: Double = 0
    var hasAudio: Bool = false
    var is60: Bool { fps >= 59 && fps <= 60.5 }
    var resolution: String { "\(width) × \(height)" }
    var frameRate: String { String(format: "%.2f", fps).replacingOccurrences(of: ".00", with: "") + " FPS" }
    var durationText: String {
        let seconds = Int(max(0, duration.isFinite ? duration : 0))
        return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    var sizeText: String { ByteCountFormatter.string(fromByteCount: Int64(fileSizeMB * 1_048_576), countStyle: .file) }
}
enum RAFLIPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    // Preserve stored raw values for upgrades; user-facing names live in AppSettings.
    case preserve = "Preserve Original", smart = "RAFLI Smart", tiktokSafe = "TikTok Safe 1080"
    case highMotion = "High Motion", maxQuality = "ULTRA MAX", compact = "Compact"
    var id: String { rawValue }
    static let visible: [Self] = [.smart, .tiktokSafe, .highMotion, .maxQuality, .preserve]
    var targetBitrate: Int {
        switch self { case .preserve: 0; case .smart: 20_000_000; case .tiktokSafe: 16_000_000; case .highMotion: 28_000_000; case .maxQuality: 40_000_000; case .compact: 10_000_000 }
    }
    var keyframeSeconds: Double { switch self { case .preserve, .compact, .tiktokSafe: 2; default: 1 } }
}
struct VideoItem: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case original, processed }
    let id: UUID
    let kind: Kind
    let relativePath: String
    let thumbnailPath: String?
    let displayName: String
    let created: Date
    let sourceID: UUID?
    let report: VideoReport
}
struct StudioVideo: Identifiable, Sendable {
    let id: UUID
    let url: URL
    let thumbnail: URL?
    let name: String
    let report: VideoReport
    let libraryID: UUID?
}
enum StudioState {
    case empty, importing, analyzing
    case ready(StudioVideo)
    case processing(StudioVideo, Double?)
    case verifying(StudioVideo)
    case result(StudioVideo)
    case failed(AppFailure)
    var busy: Bool { switch self { case .importing, .analyzing, .processing, .verifying: true; default: false } }
    var phase: Int { switch self { case .empty: 0; case .importing: 1; case .analyzing: 2; case .ready: 3; case .processing: 4; case .verifying: 5; case .result: 6; case .failed: 7 } }
}
enum AppFailure: Error, Identifiable, Equatable {
    case unsupported, importFailed, processFailed, verifyFailed, photosDenied, saveFailed, lowStorage, storageFailed
    var id: String { String(describing: self) }
    @MainActor func message(_ s: AppSettings) -> String {
        switch self {
        case .unsupported: s.text("هذا الملف غير مدعوم.", "This video isn’t supported.")
        case .importFailed: s.text("تعذر قراءة الفيديو.", "We couldn’t import this video.")
        case .processFailed: s.text("تعذر تجهيز الفيديو. حاول اختيار إعداد آخر.", "We couldn’t prepare the video. Try another profile.")
        case .verifyFailed: s.text("تعذر التحقق من الناتج. لم تتم إضافته للمكتبة.", "The output couldn’t be verified and wasn’t added to your library.")
        case .photosDenied: s.text("نحتاج إذن الصور لحفظ الفيديو.", "Allow Photos access to save your video.")
        case .saveFailed: s.text("تعذر حفظ الفيديو في الصور.", "We couldn’t save to Photos.")
        case .lowStorage: s.text("المساحة المتاحة غير كافية.", "There isn’t enough free storage.")
        case .storageFailed: s.text("تعذر تحديث المكتبة. ملفاتك الحالية محفوظة.", "We couldn’t update your library. Existing files are safe.")
        }
    }
    static func storage(_ error: Error) -> Self {
        let e = error as NSError
        return (e.domain == NSCocoaErrorDomain && e.code == NSFileWriteOutOfSpaceError) || (e.domain == NSPOSIXErrorDomain && e.code == 28) ? .lowStorage : .storageFailed
    }
}
