import SwiftUI
import UIKit

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark, oled
    var id: String { rawValue }
    var scheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark, .oled: .dark } }
}

@MainActor @Observable
final class AppSettings {
    var language: String { didSet { defaults.set(language, forKey: "studio.language") } }
    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: "studio.appearance") } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: "studio.haptics") } }
    var reducedMotion: Bool { didSet { defaults.set(reducedMotion, forKey: "studio.reducedMotion") } }
    var autoSave: Bool { didSet { defaults.set(autoSave, forKey: "studio.autoSave") } }
    var keepOriginal: Bool { didSet { defaults.set(keepOriginal, forKey: "studio.keepOriginal") } }
    var preset: RAFLIPreset { didSet { defaults.set(preset.rawValue, forKey: "studio.preset") } }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = defaults.string(forKey: "studio.language") ?? "ar"
        appearance = Appearance(rawValue: defaults.string(forKey: "studio.appearance") ?? "system") ?? .system
        haptics = defaults.object(forKey: "studio.haptics") as? Bool ?? true
        reducedMotion = defaults.bool(forKey: "studio.reducedMotion")
        autoSave = defaults.bool(forKey: "studio.autoSave")
        keepOriginal = defaults.object(forKey: "studio.keepOriginal") as? Bool ?? true
        preset = RAFLIPreset(rawValue: defaults.string(forKey: "studio.preset") ?? "") ?? .smart
    }
    var arabic: Bool { language == "ar" }
    func text(_ arabic: String, _ english: String) -> String { self.arabic ? arabic : english }
    func feedback(_ type: UINotificationFeedbackGenerator.FeedbackType? = nil) {
        guard haptics else { return }
        if let type { UINotificationFeedbackGenerator().notificationOccurred(type) }
        else { UISelectionFeedbackGenerator().selectionChanged() }
    }
    func presetTitle(_ value: RAFLIPreset) -> String {
        switch value {
        case .smart: text("ذكي", "Smart")
        case .tiktokSafe: text("آمن لتيك توك", "TikTok Safe")
        case .highMotion: text("حركة عالية", "High Motion")
        case .maxQuality: text("أقصى جودة", "Max Quality")
        case .preserve: text("بدون إعادة ترميز", "Preserve Original")
        case .compact: text("حجم أصغر", "Compact")
        }
    }
}
