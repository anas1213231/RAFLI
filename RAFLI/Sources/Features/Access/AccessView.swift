import SwiftUI

struct AccessView: View {
    let unlock: () -> Void
    @Environment(AppSettings.self) private var settings
    @State private var code = ""
    @State private var invalid = false
    @FocusState private var focused: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 32)
                VStack(spacing: 12) {
                    BrandLogo(size: 104)
                    Text("ارفعلي").font(TypeStyle.hero)
                    Text("RAFLI").font(.caption.weight(.medium)).tracking(3).foregroundStyle(.secondary)
                }
                VStack(spacing: 8) {
                    Text(settings.text("محرك الفيديو الخاص بك.", "Your personal video engine.")).font(.title3.weight(.medium))
                    Text(settings.text("معالجة محلية. جودة حقيقية.", "Local processing. Real quality.")).font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(spacing: 16) {
                    SecureField(settings.text("رمز الدخول", "Access code"), text: $code)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go)
                        .keyboardType(.asciiCapable).environment(\.layoutDirection, .leftToRight)
                        .padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                        .focused($focused).onSubmit(enter).accessibilityIdentifier("access-code")
                    if invalid { Text(settings.text("رمز الدخول غير صحيح.", "The access code is incorrect.")).font(.caption).foregroundStyle(.red).accessibilityIdentifier("access-error") }
                    Button(settings.text("دخول", "Continue"), action: enter).buttonStyle(PrimaryButtonStyle()).disabled(code.isEmpty).accessibilityIdentifier("access-continue")
                }.frame(maxWidth: 360)
                Spacer(minLength: 24)
            }.padding(24).frame(maxWidth: .infinity)
        }.pageBackground()
    }
    private func enter() {
        guard code == "1v" else { invalid = true; code = ""; focused = true; settings.feedback(.error); return }
        focused = false; code = ""; settings.feedback(); unlock()
    }
}
