import SwiftUI

struct VideoDetailView: View {
    let video: StudioVideo
    let reprocess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryModel.self) private var library
    @Environment(StudioModel.self) private var studio
    @State private var share: ShareFile?
    @State private var confirmDelete = false
    @State private var saving = false
    @State private var saved = false
    @State private var failure: AppFailure?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VideoHero(video: video)
                    VideoMetrics(report: video.report, output: true)
                    HStack {
                        Label(video.report.durationText, systemImage: "clock")
                        Spacer()
                        Text(video.report.codec.uppercased())
                    }.font(.subheadline).foregroundStyle(.secondary)
                    if let item = library.items.first(where: { $0.id == video.libraryID }) {
                        Text(item.created, format: .dateTime.day().month(.wide).year()).font(.caption).foregroundStyle(.secondary)
                    }
                    Button { Task { await save() } } label: {
                        HStack { if saving { ProgressView() }; Text(saved ? settings.text("تم الحفظ في الصور", "Saved to Photos") : settings.text("حفظ في الصور", "Save to Photos")) }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(saving || saved)
                    Button { share = ShareFile(url: video.url) } label: { Label(settings.text("مشاركة", "Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44) }
                    Button(settings.text("إعادة التجهيز", "Reprocess")) { reprocess(); dismiss() }.frame(maxWidth: .infinity, minHeight: 44).disabled(studio.state.busy)
                    Button(settings.text("حذف الفيديو", "Delete video"), role: .destructive) { confirmDelete = true }.frame(maxWidth: .infinity, minHeight: 44).disabled(saving || studio.state.busy)
                }.padding(20)
            }.pageBackground().navigationTitle(settings.text("الفيديو", "Video")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(settings.text("تم", "Done")) { dismiss() } } }
        }.sheet(item: $share) { SystemShareSheet(url: $0.url) }
            .confirmationDialog(settings.text("حذف هذا الفيديو من ارفعلي؟", "Delete this video from RAFLI?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(settings.text("حذف", "Delete"), role: .destructive) {
                    Task {
                        if let item = library.items.first(where: { $0.id == video.libraryID }) {
                            await library.delete([item])
                            if library.failure == nil { studio.reset(); dismiss() } else { failure = library.failure }
                        }
                    }
                }
            }.modifier(FailureAlert(failure: $failure))
    }
    private func save() async {
        saving = true; defer { saving = false }
        do { try await RAFLIUploadEngine().saveToPhotos(file: video.url); saved = true; settings.feedback(.success) }
        catch { failure = (error as? RAFLIUploadError) == .photosDenied ? .photosDenied : .saveFailed; settings.feedback(.error) }
    }
}
