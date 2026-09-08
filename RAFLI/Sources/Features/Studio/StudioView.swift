import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct StudioView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StudioModel.self) private var studio
    @Environment(LibraryModel.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var photo: PhotosPickerItem?
    @State private var files = false
    var body: some View {
        @Bindable var studio = studio
        NavigationStack {
            Group {
                switch studio.state {
                case .empty: empty
                case .importing, .analyzing: importing
                case .ready(let video): SelectedVideoView(video: video)
                case .processing, .verifying: Color.clear
                case .result(let video): ResultView(video: video)
                case .failed(let error): failed(error)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).pageBackground()
                .navigationTitle(settings.text("الاستوديو", "Studio")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { BrandLogo(size: 36) } }
                .animation(reduceMotion || settings.reducedMotion ? nil : .easeInOut(duration: 0.25), value: studio.state.phase)
                .fileImporter(isPresented: $files, allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie]) { result in
                    switch result {
                    case .success(let url): Task { await studio.importFile(url, settings: settings, library: library) }
                    case .failure: studio.failure = .importFailed
                    }
                }
                .onChange(of: photo) { _, value in
                    guard let value else { return }
                    Task { await studio.importPhoto(value, settings: settings, library: library); photo = nil }
                }
                .modifier(FailureAlert(failure: $studio.failure))
        }
    }
    private var empty: some View {
        let photosTitle = settings.text("اختيار من الصور", "Choose from Photos")
        return GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 36)
                    Image(systemName: "play.rectangle").font(.system(size: 88, weight: .ultraLight))
                        .foregroundStyle(Palette.accent).frame(height: 160).accessibilityHidden(true)
                    VStack(spacing: 12) {
                        Text(settings.text("اختر الفيديو", "Choose your video")).font(TypeStyle.hero)
                        Text(settings.text("نفحص الملف الحقيقي ونجهزه بأفضل إعداد مناسب قبل التصدير.", "We inspect your video and prepare it with the right settings before export."))
                            .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: 310)
                    Spacer(minLength: 40)
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $photo, matching: .videos, preferredItemEncoding: .current) {
                            Label(photosTitle, systemImage: "photo.on.rectangle")
                        }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("choose-photos").disabled(library.loading || library.failure != nil)
                        Button { files = true } label: {
                            Label(settings.text("اختيار من الملفات", "Choose from Files"), systemImage: "folder")
                                .font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
                        }.accessibilityIdentifier("choose-files").disabled(library.loading || library.failure != nil)
                    }.frame(maxWidth: 360)
                    Spacer(minLength: 24)
                }.padding(.horizontal, 24).frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
    }
    private var importing: some View {
        VStack(spacing: 20) {
            ProgressView().controlSize(.large)
            Text(studio.state.phase == 1 ? settings.text("نستورد الفيديو…", "Importing your video…") : settings.text("نفحص الملف وننشئ المعاينة…", "Inspecting the file and creating a preview…"))
                .font(.headline).multilineTextAlignment(.center)
        }.padding(24).accessibilityElement(children: .combine)
    }
    private func failed(_ error: AppFailure) -> some View {
        ContentUnavailableView {
            Label(settings.text("لم تكتمل العملية", "Something interrupted the task"), systemImage: "exclamationmark.circle")
        } description: { Text(error.message(settings)) } actions: {
            Button(settings.text("حاول مجددًا", "Try again")) { studio.retry() }.buttonStyle(.borderedProminent)
            Button(settings.text("فيديو جديد", "New video")) { studio.reset() }.frame(minHeight: 44)
        }
    }
}
