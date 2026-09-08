import SwiftUI

struct ResultView: View {
    let video: StudioVideo
    @Environment(AppSettings.self) private var settings
    @Environment(StudioModel.self) private var studio
    @State private var share: ShareFile?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VideoHero(video: video)
                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.text("جاهز.", "Ready.")).font(TypeStyle.hero).accessibilityIdentifier("result-ready")
                    Label(settings.text("تم التحقق من الملف بعد التصدير", "Verified after export"), systemImage: "checkmark.seal")
                        .font(.subheadline).foregroundStyle(Palette.accent)
                }
                VideoMetrics(report: video.report, output: true)
                Button { Task { await studio.save(video.url, settings: settings) } } label: {
                    HStack {
                        if studio.saving { ProgressView() }
                        Text(studio.saved ? settings.text("تم الحفظ في الصور", "Saved to Photos") : settings.text("حفظ في الصور", "Save to Photos"))
                    }
                }.buttonStyle(PrimaryButtonStyle()).disabled(studio.saving || studio.saved)
                HStack {
                    Button { share = ShareFile(url: video.url) } label: { Label(settings.text("مشاركة", "Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44) }
                    Button(settings.text("فيديو جديد", "New video")) { studio.reset() }.frame(maxWidth: .infinity, minHeight: 44)
                }
            }.padding(20)
        }.sheet(item: $share) { SystemShareSheet(url: $0.url) }
    }
}
