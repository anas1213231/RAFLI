import SwiftUI
import AVKit

struct FileThumbnail: View {
    let url: URL?
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Palette.surface
                if let image {
                    Image(uiImage: image).resizable().scaledToFit().frame(width: proxy.size.width, height: proxy.size.height)
                } else { ProgressView().accessibilityLabel("Loading preview") }
            }.frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: url) {
            guard let url else { return }
            image = await Task.detached(priority: .utility) { UIImage(contentsOfFile: url.path) }.value
        }
    }
}
struct VideoHero: View {
    let video: StudioVideo
    @Environment(AppSettings.self) private var settings
    @State private var playing = false
    var body: some View {
        Button { playing = true } label: {
            FileThumbnail(url: video.thumbnail)
                .aspectRatio(CGFloat(video.report.width) / CGFloat(max(1, video.report.height)), contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 360)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay {
                    Image(systemName: "play.fill").font(.title3).foregroundStyle(.white)
                        .frame(width: 52, height: 52).background(.black.opacity(0.48), in: Circle())
                }
        }.buttonStyle(.plain)
            .accessibilityLabel(settings.text("تشغيل الفيديو", "Play video"))
            .sheet(isPresented: $playing) { PlayerScreen(url: video.url) }
    }
}
struct PlayerScreen: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var player: AVPlayer?
    var body: some View {
        NavigationStack {
            VideoPlayer(player: player).background(.black).ignoresSafeArea(edges: .bottom)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(settings.text("تم", "Done")) { dismiss() } } }
                .onAppear { let p = AVPlayer(url: url); p.isMuted = true; player = p }
                .onDisappear { player?.pause(); player = nil }
        }
    }
}
struct VideoMetrics: View {
    let report: VideoReport
    var output = false
    @Environment(AppSettings.self) private var settings
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) { metrics }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) { metrics }
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
    }
    @ViewBuilder private var metrics: some View {
        metric(report.resolution, settings.text("الدقة", "Resolution"))
        metric(report.frameRate, settings.text("الإطارات", "Frame rate"))
        metric(output ? String(format: "%.1f Mbps", report.bitrateMbps) : report.durationText, output ? settings.text("معدل البت", "Bitrate") : settings.text("المدة", "Duration"))
        metric(report.sizeText, settings.text("الحجم", "Size"))
    }
    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.subheadline.weight(.semibold)).environment(\.layoutDirection, .leftToRight).fixedSize(horizontal: true, vertical: false)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}
struct ShareFile: Identifiable { let url: URL; var id: URL { url } }
struct SystemShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
struct FailureAlert: ViewModifier {
    @Binding var failure: AppFailure?
    @Environment(AppSettings.self) private var settings
    func body(content: Content) -> some View {
        content.alert(settings.text("تعذر إكمال العملية", "Couldn’t complete the action"), isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            if failure == .photosDenied {
                Button(settings.text("فتح الإعدادات", "Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Button(settings.text("حسنًا", "OK"), role: .cancel) { failure = nil }
        } message: { Text(failure?.message(settings) ?? "") }
    }
}
