import SwiftUI

struct SelectedVideoView: View {
    let video: StudioVideo
    @Environment(AppSettings.self) private var settings
    @Environment(StudioModel.self) private var studio
    @Environment(LibraryModel.self) private var library
    var body: some View {
        @Bindable var studio = studio
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VideoHero(video: video)
                VideoMetrics(report: video.report)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(settings.text("طريقة التجهيز", "Preparation profile")).font(.headline)
                        Spacer()
                        Picker(settings.text("طريقة التجهيز", "Preparation profile"), selection: $studio.preset) {
                            ForEach(RAFLIPreset.visible) { preset in Text(settings.presetTitle(preset)).tag(preset) }
                        }.pickerStyle(.menu).accessibilityIdentifier("processing-profile")
                    }
                    Text(profileDescription).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(fpsCopy).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Button { Task { await studio.prepare(settings: settings, library: library) } } label: {
                    Text(settings.text("جهّز الفيديو", "Prepare Video"))
                }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("prepare-video")
                Button(settings.text("اختيار فيديو آخر", "Choose another video")) { studio.reset() }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.padding(20)
        }
    }
    private var fpsCopy: String {
        if studio.preset == .preserve { return settings.text("نحتفظ بالفيديو دون إعادة ترميز.", "Your video is kept without re-encoding.") }
        if video.report.fps < 59 { return settings.text("سنحافظ على معدل الإطارات الأصلي بدون 60 وهمي.", "We preserve the source frame rate, without artificial 60 FPS.") }
        return settings.text("حتى 60 إطارًا من المصدر عند الإمكان، دون توليد إطارات.", "Up to 60 source frames per second when possible, without generating frames.")
    }
    private var profileDescription: String {
        switch studio.preset {
        case .smart: settings.text("إعداد متوازن حسب الملف الأصلي.", "A balanced setting based on the source file.")
        case .tiktokSafe: settings.text("فيديو متوافق للنشر. قد يعيد تيك توك ترميزه.", "A compatible file for publishing. TikTok may re-encode it.")
        case .highMotion: settings.text("معدل بت أعلى للمشاهد كثيرة الحركة.", "More bitrate for scenes with movement.")
        case .maxQuality: settings.text("مساحة أكبر للحفاظ على التفاصيل المتاحة في المصدر.", "A larger file to retain detail available in the source.")
        case .preserve: settings.text("نحافظ على التدفق الأصلي؛ قد لا تدعم بعض الملفات هذا الخيار.", "Keeps the original streams; some files may not support this option.")
        case .compact: settings.text("ملف أصغر بمعدل بت أقل.", "A smaller file with a lower bitrate.")
        }
    }
}
