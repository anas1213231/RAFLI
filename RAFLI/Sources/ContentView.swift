import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import AVKit
import PhotosUI
import UIKit

struct ContentView: View {
    @AppStorage("rafli_language") private var language = "ar"
    @AppStorage("rafli_theme") private var theme = "dark"

    @StateObject private var library = RAFLIMediaStore()
    @StateObject private var uploader = RAFLIUploadEngine()

    @State private var unlocked = false
    @State private var code = ""
    @State private var loginError = ""
    @State private var tab = 0
    @State private var showFiles = false
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedOriginal: RAFLIMediaItem?
    @State private var selectedEnhanced: RAFLIMediaItem?
    @State private var sourceReport = VideoReport()
    @State private var outputReport = VideoReport()
    @State private var preset: RAFLIPreset = .maxQuality
    @State private var busy = false
    @State private var progress = 0.0
    @State private var status = ""
    @State private var playerItem: PlayerItem?
    @State private var shareItem: ShareItem?
    @State private var glow = false

    private var isArabic: Bool { language == "ar" }
    private var isLight: Bool { theme == "light" }
    private var sourceURL: URL? { selectedOriginal.map { library.url(for: $0) } }
    private var outputURL: URL? { selectedEnhanced.map { library.url(for: $0) } }

    var body: some View {
        ZStack {
            background
            if unlocked { shell } else { login }
        }
        .preferredColorScheme(isLight ? .light : .dark)
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            importFromFiles(url)
        }
        .onChange(of: photoItem) { item in
            if let item { importFromPhotos(item) }
        }
        .fullScreenCover(item: $playerItem) { item in
            RAFLIFullScreenPlayer(url: item.url)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .onAppear {
            status = t("اختر فيديو وابدأ من المصدر الحقيقي", "Choose a video and start from the real source")
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: isLight
                    ? [Color(red: 0.95, green: 0.98, blue: 0.97), .white]
                    : [Color.black, Color(red: 0.0, green: 0.055, blue: 0.045), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            Circle()
                .fill(Color.mint.opacity(isLight ? 0.16 : 0.09))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: glow ? 130 : 40, y: -300)

            Circle()
                .fill(Color.green.opacity(isLight ? 0.10 : 0.055))
                .frame(width: 260, height: 260)
                .blur(radius: 120)
                .offset(x: -150, y: glow ? 360 : 260)
        }
    }

    private var shell: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 1: libraryPage
                case 2: profilePage
                default: homePage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
    }

    private var login: some View {
        VStack(spacing: 20) {
            Spacer()

            RAFLIBrandMark(size: 112)

            Text("RAFLI")
                .font(.system(size: 31, weight: .bold, design: .rounded))

            VStack(spacing: 13) {
                HStack {
                    Label(t("رمز الدخول", "Access Code"), systemImage: "lock.fill")
                        .font(.headline)
                    Spacer()
                }

                SecureField(t("اكتب الكود", "Enter code"), text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(authenticate)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mint.opacity(0.22)))

                if !loginError.isEmpty {
                    Text(loginError).font(.caption.bold()).foregroundStyle(.red)
                }

                Button(action: authenticate) {
                    Text(t("دخول", "Enter"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RAFLIPrimaryButton())
            }
            .padding(18)
            .glassCard()
            .padding(.horizontal, 24)

            Text(t("يُطلب الكود عند كل تشغيل جديد للتطبيق", "The code is required on every fresh app launch"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var homePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                header
                importCard

                if let sourceURL {
                    videoCard(title: t("المصدر", "Source"), badge: t("أصلي", "ORIGINAL"), url: sourceURL, report: sourceReport)
                    engineCard
                }

                if let outputURL {
                    videoCard(title: t("النسخة الجاهزة", "Ready Master"), badge: t("محسن", "ENHANCED"), url: outputURL, report: outputReport)
                    proofCard
                    resultActions(url: outputURL)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            RAFLIBrandMark(size: 44)
            Text("RAFLI")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Spacer()
            Text("1.3")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.mint.opacity(0.10))
                .clipShape(Capsule())
        }
    }

    private var importCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: isArabic ? .trailing : .leading, spacing: 3) {
                    Text(t("اختر الفيديو الأصلي", "Choose Original Video")).font(.headline.bold())
                    Text(t("الصور أو الملفات — بدون كاميرا", "Photos or Files — no camera"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.mint)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .videos) {
                    sourceButton(t("الصور", "Photos"), icon: "photo.on.rectangle.angled", tint: .pink)
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
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.18)))
    }

    private func videoCard(title: String, badge: String, url: URL, report: VideoReport) -> some View {
        VStack(spacing: 11) {
            HStack {
                VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold())
                    Text(badge).font(.caption2.bold()).foregroundStyle(.mint)
                }
                Spacer()
                Button { playerItem = PlayerItem(url: url) } label: {
                    Label(t("تشغيل", "Play"), systemImage: "play.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.mint)
            }

            Button { playerItem = PlayerItem(url: url) } label: {
                VideoThumbnailView(url: url)
                    .frame(height: 188)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 7) {
                metric("FPS", String(format: "%.0f", report.fps))
                metric(t("الدقة", "Size"), "\(report.width)×\(report.height)")
                metric(t("بت ريت", "Bitrate"), String(format: "%.1fM", report.bitrateMbps))
            }
        }
        .padding(14)
        .glassCard()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.caption.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var engineCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: isArabic ? .trailing : .leading, spacing: 3) {
                    Text(t("محرك RAFLI", "RAFLI Engine")).font(.headline.bold())
                    Text(engineDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Preset", selection: $preset) {
                    ForEach(RAFLIPreset.allCases) { item in Text(displayName(item)).tag(item) }
                }
                .pickerStyle(.menu)
                .tint(.mint)
            }

            if busy {
                ProgressView(value: progress).tint(.mint)
                HStack {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption.bold().monospacedDigit())
                }
            }

            Button { processVideo() } label: {
                HStack(spacing: 9) {
                    Image(systemName: busy ? "hourglass" : "wand.and.stars")
                    Text(busy ? t("جاري بناء النسخة", "Building master") : t("بناء نسخة الجودة", "Build Quality Master"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(RAFLIPrimaryButton())
            .disabled(busy)
        }
        .padding(14)
        .glassCard()
    }

    private var proofCard: some View {
        VStack(spacing: 10) {
            HStack {
                Label(t("إثبات الناتج", "Output Proof"), systemImage: "checkmark.seal.fill")
                    .font(.headline.bold())
                    .foregroundStyle(.mint)
                Spacer()
                Text("\(outputReport.score)/100")
                    .font(.caption.bold().monospacedDigit())
            }

            HStack(spacing: 8) {
                proofValue(t("FPS", "FPS"), String(format: "%.0f → %.0f", sourceReport.fps, outputReport.fps))
                proofValue(t("الدقة", "Resolution"), "\(outputReport.width)×\(outputReport.height)")
                proofValue(t("الترميز", "Codec"), outputReport.codec.uppercased())
            }

            Text(fpsTruthText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
        }
        .padding(14)
        .glassCard()
    }

    private func proofValue(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.caption.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.58)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.mint.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func resultActions(url: URL) -> some View {
        HStack(spacing: 9) {
            Button {
                Task {
                    do {
                        try await uploader.saveToPhotos(file: url)
                        await MainActor.run { status = t("تم الحفظ في الصور", "Saved to Photos") }
                    } catch {
                        await MainActor.run { status = error.localizedDescription }
                    }
                }
            } label: {
                Label(t("حفظ", "Save"), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(RAFLIPrimaryButton())

            Button { shareItem = ShareItem(url: url) } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(RAFLISecondaryButton())
            .frame(width: 60)
        }
    }

    private var libraryPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                pageHeader(t("فيديوهاتي", "My Videos"), subtitle: t("محفوظة داخل RAFLI حتى بعد إغلاق التطبيق", "Stored inside RAFLI across app launches"))

                if library.items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack.badge.play").font(.system(size: 36)).foregroundStyle(.mint)
                        Text(t("لا توجد فيديوهات محفوظة", "No saved videos")).font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                    .glassCard()
                } else {
                    ForEach(library.items) { item in
                        libraryCard(item)
                    }
                }
            }
            .padding(14)
            .padding(.bottom, 22)
        }
    }

    private func libraryCard(_ item: RAFLIMediaItem) -> some View {
        let url = library.url(for: item)
        return HStack(spacing: 12) {
            Button { playerItem = PlayerItem(url: url) } label: {
                VideoThumbnailView(url: url)
                    .frame(width: 104, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)

            VStack(alignment: isArabic ? .trailing : .leading, spacing: 5) {
                Text(item.kind == .original ? t("الفيديو الأصلي", "Original") : t("نسخة RAFLI", "RAFLI Master"))
                    .font(.subheadline.bold())
                Text(item.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button {
                    selectLibraryItem(item)
                } label: {
                    Text(t("استخدام", "Use")).font(.caption.bold()).foregroundStyle(.mint)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Menu {
                Button { playerItem = PlayerItem(url: url) } label: { Label(t("تشغيل", "Play"), systemImage: "play.fill") }
                Button { shareItem = ShareItem(url: url) } label: { Label(t("مشاركة", "Share"), systemImage: "square.and.arrow.up") }
                Button(role: .destructive) { library.delete(item) } label: { Label(t("حذف", "Delete"), systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .glassCard()
    }

    private var profilePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                pageHeader(t("الملف", "Profile"), subtitle: t("الإعدادات", "Settings"))

                HStack(spacing: 12) {
                    RAFLIBrandMark(size: 62)
                    VStack(alignment: isArabic ? .trailing : .leading, spacing: 3) {
                        Text("RAFLI").font(.headline.bold())
                        Text(t("الإصدار 1.3", "Version 1.3")).font(.caption).foregroundStyle(.mint)
                    }
                    Spacer()
                }
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
                            Text(t("غامق", "Dark")).tag("dark")
                            Text(t("فاتح", "Light")).tag("light")
                        }.pickerStyle(.menu).tint(.mint)
                    }
                    Divider().opacity(0.2)
                    settingsRow(t("المطور", "Developer"), icon: "paperplane.fill") {
                        Button("@ucorc") {
                            if let url = URL(string: "https://t.me/ucorc") { UIApplication.shared.open(url) }
                        }.foregroundStyle(.mint)
                    }
                }
                .padding(.horizontal, 14)
                .glassCard()

                Button {
                    unlocked = false
                    code = ""
                    loginError = ""
                } label: {
                    Label(t("قفل التطبيق", "Lock App"), systemImage: "lock.fill")
                }
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
        }
        .padding(.vertical, 13)
    }

    private var bottomBar: some View {
        HStack(spacing: 4) {
            nav(0, t("الرئيسية", "Home"), "house.fill")
            nav(1, t("فيديوهاتي", "Videos"), "rectangle.stack.fill")
            nav(2, t("الملف", "Profile"), "person.fill")
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
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
        }
        .buttonStyle(.plain)
    }

    private func pageHeader(_ title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 3) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func authenticate() {
        guard code == "1v" else {
            unlocked = false
            loginError = t("الكود غير صحيح", "Incorrect code")
            return
        }
        loginError = ""
        unlocked = true
    }

    private func importFromPhotos(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                try data.write(to: temp, options: .atomic)
                try await persistAndAnalyze(temp)
                try? FileManager.default.removeItem(at: temp)
            } catch {
                await MainActor.run { status = error.localizedDescription }
            }
        }
    }

    private func importFromFiles(_ url: URL) {
        Task {
            let security = url.startAccessingSecurityScopedResource()
            defer { if security { url.stopAccessingSecurityScopedResource() } }
            do {
                try await persistAndAnalyze(url)
            } catch {
                await MainActor.run { status = error.localizedDescription }
            }
        }
    }

    @MainActor
    private func persistAndAnalyze(_ url: URL) async throws {
        let item = try library.importOriginal(from: url)
        selectedOriginal = item
        selectedEnhanced = nil
        outputReport = VideoReport()
        sourceReport = try await VideoAnalyzer.analyze(library.url(for: item))
        progress = 0
        status = t("تم حفظ وتحليل المصدر الحقيقي", "Original saved and analyzed")
        tab = 0
    }

    private func processVideo() {
        guard let sourceURL, let selectedOriginal else { return }
        busy = true
        progress = 0
        selectedEnhanced = nil
        outputReport = VideoReport()
        status = t("جاري الترميز الحقيقي…", "Real encoding in progress…")

        Task {
            do {
                let tempOutput = try await VideoProcessor.export(source: sourceURL, preset: preset, report: sourceReport) { value in
                    Task { @MainActor in progress = value }
                }
                let saved = await MainActor.run { () throws -> RAFLIMediaItem in
                    try library.saveEnhanced(from: tempOutput, sourceID: selectedOriginal.id)
                }
                let savedURL = await MainActor.run { library.url(for: saved) }
                let verified = try await VideoAnalyzer.analyze(savedURL)
                await MainActor.run {
                    selectedEnhanced = saved
                    outputReport = verified
                    busy = false
                    progress = 1
                    status = t("تم البناء والتحقق من الملف الناتج", "Master built and verified")
                }
                try? FileManager.default.removeItem(at: tempOutput)
            } catch {
                await MainActor.run {
                    busy = false
                    status = error.localizedDescription
                }
            }
        }
    }

    private func selectLibraryItem(_ item: RAFLIMediaItem) {
        Task {
            do {
                let report = try await VideoAnalyzer.analyze(library.url(for: item))
                await MainActor.run {
                    if item.kind == .original {
                        selectedOriginal = item
                        sourceReport = report
                        selectedEnhanced = nil
                        outputReport = VideoReport()
                    } else {
                        selectedEnhanced = item
                        outputReport = report
                    }
                    tab = 0
                }
            } catch {
                await MainActor.run { status = error.localizedDescription }
            }
        }
    }

    private var fpsTruthText: String {
        if sourceReport.fps >= 59 {
            return t("المصدر 60FPS حقيقي، لذلك RAFLI يحافظ على 60FPS في الملف الناتج حتى حد 60.", "The source is real 60 FPS, so RAFLI preserves up to 60 FPS in the output.")
        }
        return t("المصدر أقل من 60FPS؛ RAFLI لا يزوّر الرقم بتكرار الإطارات. الجودة والدقة والبت ريت تُبنى فعليًا، أما 60FPS الحقيقي فيحتاج مصدر 60FPS أو محرك interpolation مخصص.", "The source is below 60 FPS; RAFLI does not fake the number by duplicating frames. Resolution, bitrate and encoding are rebuilt for real.")
    }

    private var engineDescription: String {
        switch preset {
        case .preserve: return t("بدون إعادة ترميز عند الإمكان", "Passthrough when possible")
        case .smart: return t("H.264 High + ضبط تلقائي للبت ريت", "H.264 High + adaptive bitrate")
        case .tiktokSafe: return t("1080 H.264 متوازن", "Balanced 1080 H.264")
        case .highMotion: return t("24 Mbps للمشاهد السريعة", "24 Mbps for fast motion")
        case .maxQuality: return t("36 Mbps + H.264 High + CABAC + AAC 256k", "36 Mbps + H.264 High + CABAC + AAC 256k")
        case .compact: return t("8 Mbps بحجم أخف", "8 Mbps compact output")
        }
    }

    private func displayName(_ preset: RAFLIPreset) -> String {
        switch preset {
        case .preserve: return t("الأصل", "Preserve")
        case .smart: return t("ذكي", "Smart")
        case .tiktokSafe: return "TikTok 1080"
        case .highMotion: return t("حركة عالية", "High Motion")
        case .maxQuality: return "ULTRA MAX"
        case .compact: return t("خفيف", "Compact")
        }
    }

    private func t(_ ar: String, _ en: String) -> String { isArabic ? ar : en }
}

struct RAFLIBrandMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.04, green: 0.22, blue: 0.17), Color(red: 0.0, green: 0.07, blue: 0.055)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)

            Image(systemName: "tray.and.arrow.up.fill")
                .font(.system(size: size * 0.48, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.86))
                .shadow(color: .mint.opacity(0.30), radius: size * 0.12)
        }
        .frame(width: size, height: size)
        .shadow(color: .mint.opacity(0.16), radius: size * 0.16)
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView().tint(.mint)
            }
            Circle().fill(.black.opacity(0.42)).frame(width: 46, height: 46)
            Image(systemName: "play.fill").foregroundStyle(.white)
        }
        .clipped()
        .task { image = await makeThumbnail() }
    }

    private func makeThumbnail() async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
        do {
            let cg = try generator.copyCGImage(at: CMTime(seconds: 0.15, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: cg)
        } catch {
            return nil
        }
    }
}

struct RAFLIFullScreenPlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: player)
                .ignoresSafeArea(edges: .horizontal)
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                }
                .padding()
                Spacer()
            }
        }
        .onAppear { player.play() }
        .onDisappear { player.pause() }
    }
}

struct PlayerItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct RAFLIPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.black)
            .background(LinearGradient(colors: [Color.mint.opacity(configuration.isPressed ? 0.66 : 0.98), Color.green.opacity(configuration.isPressed ? 0.48 : 0.78)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct RAFLISecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.mint)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mint.opacity(configuration.isPressed ? 0.10 : 0.20)))
    }
}

extension View {
    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.mint.opacity(0.10), lineWidth: 1))
    }
}
