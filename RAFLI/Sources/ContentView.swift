import SwiftUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation
import PhotosUI

struct ContentView: View {
    @AppStorage("rafli_language") private var language = "ar"
    @AppStorage("rafli_theme") private var theme = "dark"
    @AppStorage("rafli_access_v11") private var accessGranted = false

    @State private var code = ""
    @State private var loginError = ""
    @State private var tab = 0
    @State private var filter = 0
    @State private var showFiles = false
    @State private var photoItem: PhotosPickerItem?
    @State private var sourceURL: URL?
    @State private var outputURL: URL?
    @State private var report = VideoReport()
    @State private var preset: RAFLIPreset = .maxQuality
    @State private var busy = false
    @State private var progress = 0.0
    @State private var status = ""
    @State private var shareItem: ShareItem?
    @State private var glow = false
    @StateObject private var uploader = RAFLIUploadEngine()

    private var isArabic: Bool { language == "ar" }
    private var isLight: Bool { theme == "light" }

    var body: some View {
        ZStack {
            background
            if accessGranted { shell } else { login }
        }
        .preferredColorScheme(isLight ? .light : .dark)
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first { loadFile(url) }
        }
        .onChange(of: photoItem) { item in
            if let item { loadPhoto(item) }
        }
        .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
        .onAppear {
            status = t("اختر فيديو من الصور أو الملفات", "Choose a video from Photos or Files")
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: isLight
                    ? [Color(red: 0.95, green: 0.98, blue: 0.97), .white]
                    : [Color.black, Color(red: 0.0, green: 0.055, blue: 0.045), Color(red: 0.0, green: 0.018, blue: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            Circle()
                .fill(Color.mint.opacity(isLight ? 0.14 : 0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: glow ? 120 : 60, y: -250)

            Circle()
                .fill(Color.green.opacity(isLight ? 0.09 : 0.06))
                .frame(width: 240, height: 240)
                .blur(radius: 100)
                .offset(x: -130, y: glow ? 300 : 220)
        }
    }

    private var shell: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 1: videosPage
                case 2: profilePage
                default: homePage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
    }

    private var login: some View {
        VStack(spacing: 22) {
            Spacer()

            Image("RAFLILogo")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .mint.opacity(glow ? 0.38 : 0.16), radius: glow ? 26 : 10)

            VStack(spacing: 4) {
                Text("RAFLI").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Higher Quality. Always.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.mint)
            }

            VStack(spacing: 13) {
                HStack {
                    Image(systemName: "lock.fill").foregroundStyle(.mint)
                    Text(t("رمز الدخول", "Access Code")).font(.headline)
                    Spacer()
                }

                SecureField(t("أدخل 1v", "Enter 1v"), text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { authenticate() }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.mint.opacity(0.25)))

                if !loginError.isEmpty {
                    Text(loginError).font(.caption.bold()).foregroundStyle(.red)
                }

                Button(action: authenticate) {
                    HStack {
                        Text(t("دخول", "Enter")).fontWeight(.bold)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(RAFLIPrimaryButton())
            }
            .padding(18)
            .glassCard()
            .padding(.horizontal, 24)

            Text(t("الكود الصحيح فقط يفتح التطبيق", "Only the correct code unlocks the app"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var homePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                compactHeader
                importCard

                if let sourceURL {
                    previewCard(url: sourceURL)
                    statsGrid
                    modeCard
                    processCard
                }

                if let sourceURL, let outputURL {
                    compareCard(original: sourceURL, enhanced: outputURL)
                    resultActions(url: outputURL)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 10) {
            Image("RAFLILogo")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 1) {
                Text("RAFLI").font(.title3.bold())
                Text("Higher Quality. Always.").font(.caption2).foregroundStyle(.mint)
            }
            Spacer()
            Button { tab = 2 } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.mint)
            }.buttonStyle(.plain)
        }
    }

    private var importCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(LinearGradient(colors: [.mint, .green.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                .clipShape(Circle())
                .shadow(color: .mint.opacity(0.22), radius: 14)

            VStack(spacing: 3) {
                Text(t("اختر فيديو", "Choose Video")).font(.headline.bold())
                Text(t("من الصور أو الملفات", "From Photos or Files"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .videos) {
                    sourceButton(t("الصور", "Photos"), icon: "photo.on.rectangle", tint: .pink)
                }
                .buttonStyle(.plain)

                Button { showFiles = true } label: {
                    sourceButton(t("الملفات", "Files"), icon: "folder.fill", tint: .mint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard()
    }

    private func sourceButton(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.18)))
    }

    private func previewCard(url: URL) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 10) {
            HStack {
                Text(t("الفيديو الأصلي", "Original Video")).font(.subheadline.bold())
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint)
            }
            VideoThumbnailView(url: url)
                .frame(height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(14)
        .glassCard()
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            stat(t("الدقة", "Resolution"), "\(report.width)×\(report.height)", "rectangle.expand.vertical")
            stat("FPS", String(format: "%.0f", report.fps), "waveform")
            stat(t("الترميز", "Codec"), report.codec.uppercased(), "film")
            stat(t("البت ريت", "Bitrate"), String(format: "%.1f Mbps", report.bitrateMbps), "gauge")
        }
    }

    private func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 5) {
            Image(systemName: icon).foregroundStyle(.mint)
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
        .padding(12)
        .glassCard()
    }

    private var modeCard: some View {
        HStack {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 3) {
                Text(t("وضع الجودة", "Quality Mode")).font(.subheadline.bold())
                Text(presetDescription).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Picker("Preset", selection: $preset) {
                ForEach(RAFLIPreset.allCases) { item in Text(displayName(item)).tag(item) }
            }
            .pickerStyle(.menu)
            .tint(.mint)
        }
        .padding(14)
        .glassCard()
    }

    private var processCard: some View {
        VStack(spacing: 10) {
            if busy {
                ProgressView(value: progress)
                    .tint(.mint)
                Text("\(Int(progress * 100))%").font(.caption.bold().monospacedDigit())
            }
            Text(status).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { processVideo() } label: {
                HStack {
                    Image(systemName: busy ? "hourglass" : "bolt.fill")
                    Text(busy ? t("جاري المعالجة", "Processing") : t("ابدأ التحسين", "Start Enhancement"))
                }
            }
            .buttonStyle(RAFLIPrimaryButton())
            .disabled(busy)
        }
        .padding(14)
        .glassCard()
    }

    private func compareCard(original: URL, enhanced: URL) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 10) {
            Text(t("قبل / بعد", "Before / After")).font(.subheadline.bold())
            HStack(spacing: 10) {
                miniVideo(t("الأصلي", "Original"), original)
                miniVideo(t("بعد التعديل", "Enhanced"), enhanced)
            }
        }
        .padding(14)
        .glassCard()
    }

    private func miniVideo(_ title: String, _ url: URL) -> some View {
        VStack(spacing: 6) {
            VideoThumbnailView(url: url).frame(height: 118).clipShape(RoundedRectangle(cornerRadius: 14))
            Text(title).font(.caption.bold())
        }.frame(maxWidth: .infinity)
    }

    private func resultActions(url: URL) -> some View {
        VStack(spacing: 9) {
            Button {
                Task { try? await uploader.saveToPhotos(file: url) }
            } label: { Label(t("حفظ في الصور", "Save to Photos"), systemImage: "square.and.arrow.down") }
            .buttonStyle(RAFLIPrimaryButton())

            HStack(spacing: 9) {
                Button { shareItem = ShareItem(url: url) } label: { Label(t("مشاركة", "Share"), systemImage: "square.and.arrow.up") }
                    .buttonStyle(RAFLISecondaryButton())
                Button { reset() } label: { Label(t("جديد", "New"), systemImage: "plus") }
                    .buttonStyle(RAFLISecondaryButton())
            }
        }
    }

    private var videosPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                pageHeader(t("فيديوهاتي", "My Videos"), subtitle: t("الأصلي والنسخة المحسنة", "Original and enhanced"))

                Picker("Filter", selection: $filter) {
                    Text(t("الكل", "All")).tag(0)
                    Text(t("الأصلي", "Original")).tag(1)
                    Text(t("المحسن", "Enhanced")).tag(2)
                }
                .pickerStyle(.segmented)

                if sourceURL == nil && outputURL == nil {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack.badge.play").font(.system(size: 34)).foregroundStyle(.mint)
                        Text(t("لا توجد فيديوهات بعد", "No videos yet")).font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                    .glassCard()
                } else {
                    if filter != 2, let sourceURL { libraryCard(t("الفيديو الأصلي", "Original Video"), tag: t("أصلي", "ORIGINAL"), url: sourceURL) }
                    if filter != 1, let outputURL { libraryCard(t("الفيديو المحسن", "Enhanced Video"), tag: t("محسن", "ENHANCED"), url: outputURL) }
                }
            }
            .padding(14)
            .padding(.bottom, 22)
        }
    }

    private func libraryCard(_ title: String, tag: String, url: URL) -> some View {
        HStack(spacing: 12) {
            VideoThumbnailView(url: url).frame(width: 112, height: 86).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 5) {
                Text(title).font(.subheadline.bold())
                Text(tag).font(.caption2.bold()).foregroundStyle(.mint)
                Button { shareItem = ShareItem(url: url) } label: {
                    Label(t("مشاركة", "Share"), systemImage: "square.and.arrow.up").font(.caption)
                }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .glassCard()
    }

    private var profilePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                pageHeader(t("الملف الشخصي", "Profile"), subtitle: t("الإعدادات", "Settings"))

                HStack(spacing: 12) {
                    Image("RAFLILogo")
                        .resizable().scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: isArabic ? .trailing : .leading, spacing: 3) {
                        Text("RAFLI").font(.headline.bold())
                        Text(t("الإصدار 1.1", "Version 1.1")).font(.caption).foregroundStyle(.mint)
                    }
                    Spacer()
                }
                .padding(14)
                .glassCard()

                Button {
                    if let url = URL(string: "https://t.me/ucorc") { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.blue)
                            .clipShape(Circle())
                        VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                            Text(t("المطور", "Developer")).font(.subheadline.bold())
                            Text("@ucorc").font(.caption.bold()).foregroundStyle(.mint)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward").foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(14)
                .glassCard()

                VStack(spacing: 0) {
                    settingsRow(t("اللغة", "Language"), icon: "globe") {
                        Picker("Language", selection: $language) {
                            Text("العربية").tag("ar")
                            Text("English").tag("en")
                        }.pickerStyle(.menu).tint(.mint)
                    }
                    Divider().opacity(0.2)
                    settingsRow(t("المظهر", "Appearance"), icon: isLight ? "sun.max.fill" : "moon.fill") {
                        Picker("Theme", selection: $theme) {
                            Text(t("زجاجي غامق", "Dark Glass")).tag("dark")
                            Text(t("زجاجي فاتح", "Light Glass")).tag("light")
                        }.pickerStyle(.menu).tint(.mint)
                    }
                    Divider().opacity(0.2)
                    settingsRow(t("الإصدار", "Version"), icon: "info.circle") {
                        Text("1.1").foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .glassCard()

                Button {
                    accessGranted = false
                    code = ""
                    loginError = ""
                } label: { Label(t("تسجيل خروج", "Log Out"), systemImage: "rectangle.portrait.and.arrow.right") }
                .buttonStyle(RAFLISecondaryButton())
            }
            .padding(14)
            .padding(.bottom, 22)
        }
    }

    private func settingsRow<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Label(title, systemImage: icon).font(.subheadline)
            Spacer()
            content()
        }.padding(.vertical, 13)
    }

    private var bottomBar: some View {
        HStack(spacing: 4) {
            nav(0, t("الرئيسية", "Home"), "house.fill")
            nav(1, t("فيديوهاتي", "Videos"), "rectangle.stack.fill")
            nav(2, t("الملف", "Profile"), "person.fill")
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.mint.opacity(0.10)).frame(height: 1) }
    }

    private func nav(_ index: Int, _ title: String, _ icon: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { tab = index }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(tab == index ? Color.mint : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(tab == index ? Color.mint.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }

    private func pageHeader(_ title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func authenticate() {
        let entered = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entered == "1v" else {
            loginError = t("الكود غير صحيح", "Incorrect code")
            accessGranted = false
            return
        }
        loginError = ""
        accessGranted = true
    }

    private func loadPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                try data.write(to: url, options: .atomic)
                try await analyze(url)
            } catch { await MainActor.run { status = error.localizedDescription } }
        }
    }

    private func loadFile(_ url: URL) {
        Task {
            let security = url.startAccessingSecurityScopedResource()
            defer { if security { url.stopAccessingSecurityScopedResource() } }
            do {
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
                try FileManager.default.copyItem(at: url, to: temp)
                try await analyze(temp)
            } catch { await MainActor.run { status = error.localizedDescription } }
        }
    }

    private func analyze(_ url: URL) async throws {
        let r = try await VideoAnalyzer.analyze(url)
        await MainActor.run {
            sourceURL = url
            outputURL = nil
            report = r
            progress = 0
            status = t("تم تحليل الفيديو", "Video analyzed")
            tab = 0
        }
    }

    private func processVideo() {
        guard let sourceURL else { return }
        busy = true
        progress = 0
        status = t("جاري المعالجة…", "Processing…")
        Task {
            do {
                let out = try await VideoProcessor.export(source: sourceURL, preset: preset, report: report) { value in
                    Task { @MainActor in progress = value }
                }
                await MainActor.run {
                    outputURL = out
                    busy = false
                    progress = 1
                    status = t("الفيديو جاهز", "Video ready")
                }
            } catch {
                await MainActor.run { busy = false; status = error.localizedDescription }
            }
        }
    }

    private func reset() {
        sourceURL = nil
        outputURL = nil
        report = VideoReport()
        photoItem = nil
        progress = 0
        status = t("اختر فيديو من الصور أو الملفات", "Choose a video from Photos or Files")
    }

    private func t(_ ar: String, _ en: String) -> String { isArabic ? ar : en }

    private func displayName(_ p: RAFLIPreset) -> String {
        switch p {
        case .preserve: return t("الحفاظ على الأصل", "Preserve")
        case .smart: return t("ذكي", "Smart")
        case .tiktokSafe: return "TikTok 1080"
        case .highMotion: return t("حركة عالية", "High Motion")
        case .maxQuality: return "ULTRA MAX"
        case .compact: return t("خفيف", "Compact")
        }
    }

    private var presetDescription: String {
        switch preset {
        case .preserve: return t("يحافظ على الملف بدون إعادة ترميز عند الإمكان", "Keeps the source when possible")
        case .smart: return t("إعداد تلقائي حسب المصدر", "Adapts to the source")
        case .tiktokSafe: return "Balanced 1080p H.264"
        case .highMotion: return t("بت ريت أعلى للمشاهد السريعة", "Higher bitrate for motion")
        case .maxQuality: return t("أقوى إعداد داخل RAFLI", "Highest RAFLI preset")
        case .compact: return t("حجم أقل مع جودة مناسبة", "Smaller practical output")
        }
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.20)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { ProgressView().tint(.mint) }
            Image(systemName: "play.fill")
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.42))
                .clipShape(Circle())
        }
        .clipped()
        .task { image = await makeThumbnail() }
    }

    private func makeThumbnail() async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)
        do {
            let cg = try generator.copyCGImage(at: CMTime(seconds: 0.2, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: cg)
        } catch { return nil }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct RAFLIPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .foregroundStyle(.black)
            .background(LinearGradient(colors: [.mint.opacity(configuration.isPressed ? 0.72 : 0.98), .green.opacity(configuration.isPressed ? 0.48 : 0.72)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct RAFLISecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .foregroundStyle(.mint)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mint.opacity(0.18)))
    }
}

extension View {
    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.mint.opacity(0.10), lineWidth: 1))
    }
}
