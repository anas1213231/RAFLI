import SwiftUI

struct LibraryView: View {
    let reprocess: (StudioVideo) -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryModel.self) private var library
    @State private var selected: StudioVideo?
    var body: some View {
        @Bindable var library = library
        NavigationStack {
            Group {
                if library.loading && library.items.isEmpty { ProgressView() }
                else if library.items.isEmpty {
                    ContentUnavailableView(settings.text("فيديوهاتك هنا", "Your videos live here"), systemImage: "rectangle.stack", description: Text(settings.text("الفيديوهات المحفوظة والجاهزة تظهر هنا.", "Your saved originals and prepared videos appear here.")))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 24) {
                            ForEach(library.items) { item in
                                LibraryTile(item: item) { video in selected = video }
                            }
                        }.padding(20)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).pageBackground()
                .navigationTitle(settings.text("فيديوهاتي", "My Videos"))
                .sheet(item: $selected) { video in VideoDetailView(video: video) { reprocess(video); selected = nil } }
                .modifier(FailureAlert(failure: $library.failure))
        }
    }
}
private struct LibraryTile: View {
    let item: VideoItem
    let select: (StudioVideo) -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryModel.self) private var library
    @State private var video: StudioVideo?
    var body: some View {
        Button { if let video { select(video) } } label: {
            VStack(alignment: .leading, spacing: 8) {
                FileThumbnail(url: video?.thumbnail).aspectRatio(0.8, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .bottomTrailing) {
                        Text(item.report.durationText).font(.caption.weight(.medium)).foregroundStyle(.white)
                            .padding(6).background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6)).padding(8)
                    }
                Text(item.kind == .original ? settings.text("الأصلي", "Original") : settings.text("مجهّز", "Processed")).font(.subheadline.weight(.medium))
                Text(item.report.resolution + " · " + item.report.frameRate).font(.caption2).foregroundStyle(.secondary)
                    .environment(\.layoutDirection, .leftToRight).lineLimit(2)
            }.foregroundStyle(.primary)
        }.buttonStyle(.plain).disabled(video == nil)
            .accessibilityElement(children: .combine)
            .task(id: item.id) { video = await library.studioVideo(item) }
    }
}
