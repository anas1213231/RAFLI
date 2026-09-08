import SwiftUI

@main
struct RAFLIApp: App {
    @State private var settings = AppSettings()
    @State private var studio = StudioModel()
    @State private var library = LibraryModel()
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(settings).environment(studio).environment(library)
                .environment(\.locale, Locale(identifier: settings.language))
                .environment(\.layoutDirection, settings.arabic ? .rightToLeft : .leftToRight)
                .preferredColorScheme(settings.appearance.scheme).tint(Palette.accent)
        }
    }
}
struct AppRootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StudioModel.self) private var studio
    @Environment(LibraryModel.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var unlocked = false
    @State private var tab = 0
    var body: some View {
        Group {
            if unlocked {
                TabView(selection: $tab) {
                    StudioView().tabItem { Label(settings.text("الاستوديو", "Studio"), systemImage: "play.rectangle") }.tag(0)
                    LibraryView { video in studio.reprocess(video, settings: settings); tab = 0 }
                        .tabItem { Label(settings.text("فيديوهاتي", "My Videos"), systemImage: "rectangle.stack") }.tag(1)
                    ProfileView().tabItem { Label(settings.text("حسابي", "Profile"), systemImage: "person.crop.circle") }.tag(2)
                    SettingsView().tabItem { Label(settings.text("الإعدادات", "Settings"), systemImage: "gearshape") }.tag(3)
                }.onChange(of: tab) { _, _ in settings.feedback() }
                    .task { await library.refresh() }
            } else { AccessView { unlocked = true } }
        }
        .animation(reduceMotion || settings.reducedMotion ? nil : .easeOut(duration: 0.22), value: unlocked)
        .fullScreenCover(isPresented: Binding(get: { studio.state.phase == 4 || studio.state.phase == 5 }, set: { _ in })) {
            ProcessingView()
        }
    }
}
