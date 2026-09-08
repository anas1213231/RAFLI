import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryModel.self) private var library
    @Environment(StudioModel.self) private var studio
    @State private var clearProcessed = false
    @State private var clearCache = false
    @State private var cleaning = false
    @State private var failure: AppFailure?
    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section(settings.text("عام", "General")) {
                    Picker(settings.text("اللغة", "Language"), selection: $settings.language) { Text("العربية").tag("ar"); Text("English").tag("en") }.accessibilityIdentifier("language-setting")
                    Picker(settings.text("المظهر", "Appearance"), selection: $settings.appearance) {
                        Text(settings.text("النظام", "System")).tag(Appearance.system)
                        Text(settings.text("فاتح", "Light")).tag(Appearance.light)
                        Text(settings.text("داكن", "Dark")).tag(Appearance.dark)
                        Text(settings.text("أسود OLED", "OLED Black")).tag(Appearance.oled)
                    }
                    Toggle(settings.text("الاهتزازات", "Haptics"), isOn: $settings.haptics)
                    Picker(settings.text("الحركة", "Motion"), selection: $settings.reducedMotion) {
                        Text(settings.text("كاملة", "Full")).tag(false)
                        Text(settings.text("مخفّضة", "Reduced")).tag(true)
                    }
                }
                Section(settings.text("الفيديو", "Video")) {
                    Picker(settings.text("الإعداد الافتراضي", "Default profile"), selection: $settings.preset) {
                        ForEach(RAFLIPreset.visible) { preset in Text(settings.presetTitle(preset)).tag(preset) }
                    }
                    Toggle(settings.text("حفظ تلقائي في الصور", "Auto-save to Photos"), isOn: $settings.autoSave)
                    Toggle(settings.text("الاحتفاظ بنسخة أصلية", "Keep original copy"), isOn: $settings.keepOriginal)
                }
                Section {
                    LabeledContent(settings.text("المساحة المستخدمة", "Storage used"), value: ByteCountFormatter.string(fromByteCount: library.bytes, countStyle: .file))
                    Button(settings.text("حذف الملفات المجهّزة", "Clear processed files"), role: .destructive) { clearProcessed = true }.disabled(studio.state.busy || cleaning || library.items.allSatisfy { $0.kind == .original })
                    Button(settings.text("مسح الملفات المؤقتة", "Clear cache")) { clearCache = true }.disabled(studio.state.busy || cleaning)
                    if cleaning { ProgressView() }
                } header: { Text(settings.text("التخزين", "Storage")) } footer: {
                    Text(settings.text("حذف الملفات المؤقتة يغلق الفيديو الحالي غير المحفوظ. فيديوهات المكتبة تبقى محفوظة.", "Clearing cache closes an unsaved current video. Library videos remain saved."))
                }
                Section(settings.text("حول التطبيق", "About")) {
                    LabeledContent(settings.text("الإصدار", "Version"), value: AppVersion.version)
                    LabeledContent(settings.text("البناء", "Build"), value: AppVersion.build)
                    NavigationLink(settings.text("عن ارفعلي", "About RAFLI")) { AboutView() }
                    NavigationLink(settings.text("الخصوصية", "Privacy")) { InformationView(kind: .privacy) }
                    NavigationLink(settings.text("الشروط", "Terms")) { InformationView(kind: .terms) }
                    TelegramRow()
                    Text("© @ucorc · All rights reserved").font(.caption).foregroundStyle(.secondary)
                }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle(settings.text("الإعدادات", "Settings"))
        }.confirmationDialog(settings.text("حذف جميع الملفات المجهّزة من ارفعلي؟", "Delete all prepared files from RAFLI?"), isPresented: $clearProcessed, titleVisibility: .visible) {
            Button(settings.text("حذف", "Delete"), role: .destructive) {
                Task {
                    cleaning = true; studio.reset()
                    await library.delete(library.items.filter { $0.kind == .processed })
                    failure = library.failure; cleaning = false
                }
            }
        }.confirmationDialog(settings.text("مسح الملفات المؤقتة؟", "Clear temporary files?"), isPresented: $clearCache, titleVisibility: .visible) {
            Button(settings.text("مسح", "Clear"), role: .destructive) {
                Task {
                    cleaning = true; studio.reset()
                    do { try await library.storage.clearCache() } catch { failure = .storage(error) }
                    cleaning = false
                }
            }
        }.modifier(FailureAlert(failure: $failure))
    }
}
