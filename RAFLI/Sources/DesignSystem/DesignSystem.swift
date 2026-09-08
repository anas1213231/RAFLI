import SwiftUI

enum Space {
    static let xs: CGFloat = 4, sm: CGFloat = 8, md: CGFloat = 12
    static let lg: CGFloat = 16, page: CGFloat = 20, xl: CGFloat = 24, section: CGFloat = 32
}
enum TypeStyle {
    static let hero = Font.system(.largeTitle, design: .default, weight: .semibold)
    static let title = Font.system(.title, design: .default, weight: .semibold)
    static let heading = Font.system(.headline, design: .default)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
}
enum Palette {
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.64, green: 0.82, blue: 0.73, alpha: 1) : UIColor(red: 0.16, green: 0.36, blue: 0.28, alpha: 1) })
    static let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.031, green: 0.047, blue: 0.043, alpha: 1) : UIColor(red: 0.97, green: 0.965, blue: 0.95, alpha: 1) })
    static let surface = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.063, green: 0.082, blue: 0.075, alpha: 1) : .white })
}
struct BrandLogo: View {
    var size: CGFloat = 64
    var body: some View {
        Image("RAFLILogo").resizable().scaledToFit()
            .padding(size * 0.08).frame(width: size, height: size)
            .accessibilityLabel("ارفعلي — RAFLI")
    }
}
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 20).padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(Palette.background)
            .background(Palette.accent.opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4), in: RoundedRectangle(cornerRadius: 16))
    }
}
struct PageBackground: ViewModifier {
    @Environment(AppSettings.self) private var settings
    func body(content: Content) -> some View {
        content.background((settings.appearance == .oled ? Color.black : Palette.background).ignoresSafeArea())
    }
}
extension View { func pageBackground() -> some View { modifier(PageBackground()) } }
