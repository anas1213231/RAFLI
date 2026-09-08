import SwiftUI

struct ProcessingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StudioModel.self) private var studio
    var body: some View {
        VStack(spacing: 32) {
            BrandLogo(size: 64)
            if let video {
                FileThumbnail(url: video.thumbnail)
                    .aspectRatio(CGFloat(video.report.width) / CGFloat(max(1, video.report.height)), contentMode: .fit)
                    .frame(maxWidth: 260, maxHeight: 330)
                    .clipShape(RoundedRectangle(cornerRadius: 24)).accessibilityHidden(true)
                VStack(spacing: 12) {
                    Text(verifying ? settings.text("التحقق من الناتج", "Verifying the output") : settings.text("نجهز الفيديو.", "Preparing your video.")).font(TypeStyle.title)
                    if case .processing(_, let progress) = studio.state, let progress {
                        ProgressView(value: progress).tint(Palette.accent)
                        Text(progress, format: .percent.precision(.fractionLength(0))).font(.title2.weight(.semibold)).contentTransition(.numericText())
                    } else {
                        ProgressView().controlSize(.regular)
                    }
                    Text(video.name).lineLimit(1).truncationMode(.middle).font(.caption).foregroundStyle(.secondary)
                    Text(settings.text("أبقِ ارفعلي مفتوحًا حتى تكتمل العملية.", "Keep RAFLI open until the task finishes.")).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: 320)
            }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).pageBackground()
            .interactiveDismissDisabled().accessibilityElement(children: .contain)
    }
    private var video: StudioVideo? { switch studio.state { case .processing(let v, _), .verifying(let v): v; default: nil } }
    private var verifying: Bool { if case .verifying = studio.state { true } else { false } }
}
