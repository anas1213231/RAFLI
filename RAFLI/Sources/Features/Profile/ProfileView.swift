import SwiftUI

struct ProfileView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryModel.self) private var library
    var body: some View {
        NavigationStack {
            List {
                VStack(spacing: 12) {
                    BrandLogo(size: 96)
                    Text("@ucorc").font(.title2.weight(.semibold))
                    Text(settings.text("المطور والمالك", "Developer & Owner")).font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 24).listRowBackground(Color.clear).listRowSeparator(.hidden)
                Section {
                    HStack { Text(settings.text("الفيديوهات المجهّزة المحفوظة", "Saved processed videos")); Spacer(); Text("\(library.items.filter { $0.kind == .processed }.count)").foregroundStyle(.secondary) }
                    HStack { Text(settings.text("المساحة المستخدمة", "Storage used")); Spacer(); Text(ByteCountFormatter.string(fromByteCount: library.bytes, countStyle: .file)).foregroundStyle(.secondary) }
                }
                Section {
                    TelegramRow()
                    NavigationLink(settings.text("عن ارفعلي", "About RAFLI")) { AboutView() }
                    NavigationLink(settings.text("الخصوصية", "Privacy")) { InformationView(kind: .privacy) }
                    NavigationLink(settings.text("الشروط", "Terms")) { InformationView(kind: .terms) }
                }
                Section {
                    LabeledContent(settings.text("الإصدار", "Version"), value: AppVersion.version)
                    Text("© @ucorc · All rights reserved").font(.caption).foregroundStyle(.secondary)
                }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle(settings.text("الملف الشخصي", "Profile"))
        }
    }
}
enum AppVersion {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—" }
}
struct TelegramRow: View {
    @Environment(AppSettings.self) private var settings
    var body: some View {
        Button { UIApplication.shared.open(URL(string: "https://t.me/ucorc")!) } label: {
            HStack { Label(settings.text("تيليجرام", "Telegram"), systemImage: "paperplane"); Spacer(); Text("@ucorc").foregroundStyle(.secondary); Image(systemName: "arrow.up.right").font(.caption) }
        }.foregroundStyle(.primary)
    }
}
struct AboutView: View {
    @Environment(AppSettings.self) private var settings
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BrandLogo(size: 96)
                VStack(alignment: .leading, spacing: 8) {
                    Text("ارفعلي").font(TypeStyle.hero)
                    Text("RAFLI").font(.caption).tracking(3).foregroundStyle(.secondary)
                }
                Text(settings.text("محرك تجهيز فيديو لجودة قوية قبل النشر.", "Prepare a strong video source before publishing.")).font(.title3)
                Text(settings.text("تتم معالجة الفيديو محليًا على جهازك. قد يعيد تيك توك ترميز الفيديو بعد رفعه.", "Video processing happens locally on your device. TikTok may re-encode your video after upload.")).foregroundStyle(.secondary)
                Divider()
                Text(settings.text("المطور والمالك: @ucorc", "Developer & Owner: @ucorc"))
                TelegramRow().frame(minHeight: 44)
                Text("\(AppVersion.version) (\(AppVersion.build))").font(.caption).foregroundStyle(.secondary)
                Text("© @ucorc\nAll rights reserved").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.pageBackground().navigationTitle(settings.text("عن ارفعلي", "About RAFLI")).navigationBarTitleDisplayMode(.inline)
    }
}
struct InformationView: View {
    enum Kind { case privacy, terms }
    let kind: Kind
    @Environment(AppSettings.self) private var settings
    var body: some View {
        ScrollView {
            Text(kind == .privacy ? settings.text("تتم معالجة الفيديو محليًا على جهازك. يحتفظ ارفعلي بالملفات التي تختارها والنتائج في مساحة التطبيق. يمكنك حذفها من المكتبة والإعدادات. المشاركة والحفظ في الصور يحدثان بطلبك، أو عبر الحفظ التلقائي عند تفعيله. تخضع الخدمات التي تشارك معها لسياسات الخصوصية الخاصة بها. اختيار ملف من iCloud قد يتطلب تنزيله من Apple.", "Video processing happens locally on your device. RAFLI stores selected originals and results in the app’s storage. You can delete them from the library and settings. Sharing and saving to Photos happen at your request, or through auto-save when enabled. Services you share with have their own privacy policies. Choosing an iCloud file may require downloading it from Apple.") : settings.text("استخدم الفيديوهات التي تملك حق استخدامها. يجهز ارفعلي الملف قبل النشر؛ لا يضمن جودة المنصة بعد الرفع ولا يضيف تفاصيل غير موجودة في المصدر. رمز الدخول وسيلة وصول خاصة بسيطة، وليس حسابًا أو تشفيرًا للملفات. جميع حقوق التطبيق محفوظة لـ @ucorc.", "Use videos you have the right to use. RAFLI prepares files before publishing; it does not guarantee platform playback quality or add detail absent from the source. The access code is a simple private entry gate, not an account or file encryption. All app rights reserved to @ucorc."))
                .font(.body).lineSpacing(6).frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }.pageBackground().navigationTitle(kind == .privacy ? settings.text("الخصوصية", "Privacy") : settings.text("الشروط", "Terms")).navigationBarTitleDisplayMode(.inline)
    }
}
