import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import UIKit

struct RAFLIRootView: View {
    @AppStorage("rafli_language_v11") private var language = "ar"
    @AppStorage("rafli_theme_v11") private var theme = "dark"

    @State private var unlocked = false
    @State private var code = ""
    @State private var loginError = false
    @State private var tab = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var sourceURL: URL?
    @State private var outputURL: URL?
    @State private var report = VideoReport()
    @State private var busy = false
    @State private var progress = 0.0
    @State private var status = ""
    @State private var pulse = false
    @State private var drift = false
    @State private var shareItem: RAFLIShareItem?
    @StateObject private var uploader = RAFLIUploadEngine()

    private var ar: Bool { language == "ar" }
    private var light: Bool { theme == "light" }

    var body: some View {
        ZStack {
            background
            if unlocked {
                appShell
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                login
                    .transition(.opacity.combined(with: .scale(scale: 1.015)))
            }
        }
        .environment(\.layoutDirection, ar ? .rightToLeft : .leftToRight)
        .preferredColorScheme(light ? .light : .dark)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            importFile(url)
        }
        .sheet(item: $shareItem) { item in
            RAFLIShareSheet(items: [item.url])
        }
        .onChange(of: photoItem) { newItem in
            if let newItem { importPhoto(newItem) }
        }
        .onAppear {
            status = t("اختر فيديو من الصور أو الملفات", "Choose a video from Photos or Files")
            withAnimation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: light
                    ? [Color(red: 0.94, green: 0.98, blue: 0.97), .white, Color(red: 0.86, green: 0.95, blue: 0.92)]
                    : [Color(red: 0.008, green: 0.035, blue: 0.031), .black, Color(red: 0.0, green: 0.075, blue: 0.055)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.mint.opacity(light ? 0.20 : 0.13))
                .frame(width: 280, height: 280)
                .blur(radius: 78)
                .offset(x: drift ? 150 : 70, y: drift ? -270 : -360)

            Circle()
                .fill(Color.green.opacity(light ? 0.12 : 0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 90)
                .offset(x: drift ? -130 : -40, y: drift ? 350 : 260)
        }
    }

    private var login: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: max(44, geo.safeAreaInsets.top + 34))

                    RAFLIExactLogo(size: 112, pulse: pulse)
                        .padding(.bottom, 18)

                    Text("RAFLI")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Higher Quality. Always.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.mint)
                        .padding(.top, 3)

                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.mint)
                            Text(t("رمز الدخول", "Access Code"))
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }

                        SecureField(t("اكتب الكود", "Enter code"), text: $code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 15)
                            .frame(height: 50)
                            .background(light ? Color.white.opacity(0.68) : Color.white.opacity(0.055))
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(loginError ? Color.red.opacity(0.8) : Color.mint.opacity(0.22)))
                            .onSubmit { authenticate() }

                        if loginError {
                            Label(t("الكود غير صحيح", "Incorrect code"), systemImage: "exclamationmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)
                        }

                        Button(action: authenticate) {
                            HStack {
                                Text(t("دخول", "Enter"))
                                Spacer()
                                Image(systemName: ar ? "arrow.left" : "arrow.right")
                            }
                        }
                        .buttonStyle(RAFLINativePrimaryButton())
                    }
                    .padding(16)
                    .rafliGlass(radius: 22, strong: true)
                    .padding(.top, 28)

                    Text(t("الكود مطلوب في كل مرة يفتح فيها التطبيق", "Code is required every time the app launches"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)

                    Spacer(minLength: 40)
                }
                .frame(minHeight: geo.size.height)
                .padding(.horizontal, 22)
            }
        }
    }

    private var appShell: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 1: videos
                case 2: profile
                default: home
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            navBar
        }
    }

    private var home: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                header
                importCard

                if let sourceURL {
                    videoCard(title: t("الفيديو الأصلي", "Original Video"), url: sourceURL, badge: t("أصلي", "ORIGINAL"))
                    stats
                    processCard
                }

                if let sourceURL, let outputURL {
                    compareCard(original: sourceURL, enhanced: outputURL)
                    resultCard(outputURL)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            RAFLIExactLogo(size: 48, pulse: false)
            VStack(alignment: ar ? .trailing : .leading, spacing: 1) {
                Text("RAFLI")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Higher Quality. Always.")
                    .font(.caption2)
                    .foregroundStyle(.mint)
            }
            Spacer()
            Text("1.1")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.mint)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.mint.opacity(0.10))
                .clipShape(Capsule())
        }
        .frame(height: 58)
    }

    private var importCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(pulse ? 0.21 : 0.09))
                    .frame(width: 72, height: 72)
                    .blur(radius: pulse ? 12 : 4)
                Circle()
                    .fill(LinearGradient(colors: [Color.mint, Color.green.opacity(0.62)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(pulse ? 1.03 : 0.98)

            VStack(spacing: 3) {
                Text(t("أضف فيديو", "Add Video"))
                    .font(.system(size: 19, weight: .bold))
                Text(t("اختر من الصور أو الملفات", "Choose from Photos or Files"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .videos) {
                    sourceButton(t("الصور", "Photos"), icon: "photo.on.rectangle", color: .pink)
                }
                .buttonStyle(.plain)

                Button { showFiles = true } label: {
                    sourceButton(t("الملفات", "Files"), icon: "folder.fill", color: .mint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .rafliGlass(radius: 22, strong: true)
    }

    private func sourceButton(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(Color.primary.opacity(light ? 0.045 : 0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.18)))
    }

    private func videoCard(title: String, url: URL, badge: String) -> some View {
        VStack(spacing: 9) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(badge)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.mint)
            }
            RAFLIThumbnail(url: url)
                .frame(height: 178)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .padding(12)
        .rafliGlass(radius: 20)
    }

    private var stats: some View {
        HStack(spacing: 8) {
            stat("FPS", String(format: "%.0f", report.fps))
            stat(t("الدقة", "Resolution"), "\(report.width)×\(report.height)")
            stat(t("البت ريت", "Bitrate"), String(format: "%.1fM", report.bitrateMbps))
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.72)
            Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .rafliGlass(radius: 15)
    }

    private var processCard: some View {
        VStack(spacing: 11) {
            if busy {
                HStack(spacing: 12) {
                    ProgressView(value: progress)
                        .tint(.mint)
                    Text("\(Int(progress * 100))%")
                        .font(.caption.bold().monospacedDigit())
                }
            }

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button { process() } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text(busy ? t("جاري التحسين", "Processing") : t("ابدأ التحسين", "Start Enhancement"))
                }
            }
            .buttonStyle(RAFLINativePrimaryButton())
            .disabled(busy)
        }
        .padding(13)
        .rafliGlass(radius: 20)
    }

    private func compareCard(original: URL, enhanced: URL) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(t("مقارنة النتيجة", "Compare Result")).font(.subheadline.bold())
                Spacer()
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.mint)
            }
            HStack(spacing: 8) {
                compareVideo(t("الأصلي", "Original"), original)
                compareVideo(t("بعد التعديل", "Enhanced"), enhanced)
            }
        }
        .padding(12)
        .rafliGlass(radius: 20, strong: true)
    }

    private func compareVideo(_ title: String, _ url: URL) -> some View {
        VStack(spacing: 6) {
            RAFLIThumbnail(url: url)
                .frame(height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text(title).font(.caption2.bold())
        }
        .frame(maxWidth: .infinity)
    }

    private func resultCard(_ url: URL) -> some View {
        HStack(spacing: 9) {
            Button {
                Task {
                    do { try await uploader.saveToPhotos(file: url); status = t("تم الحفظ في الصور ✅", "Saved to Photos ✅") }
                    catch { status = error.localizedDescription }
                }
            } label: {
                Label(t("حفظ", "Save"), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(RAFLICompactButton())

            Button { shareItem = RAFLIShareItem(url: url) } label: {
                Label(t("مشاركة", "Share"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(RAFLICompactButton())

            Button { reset() } label: {
                Label(t("جديد", "New"), systemImage: "plus")
            }
            .buttonStyle(RAFLICompactButton())
        }
    }

    private var videos: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                sectionHeader(t("فيديوهاتي", "My Videos"), t("الأصل والنسخة المحسنة", "Original and enhanced"))

                if sourceURL == nil && outputURL == nil {
                    VStack(spacing: 9) {
                        Image(systemName: "film.stack").font(.system(size: 30)).foregroundStyle(.mint)
                        Text(t("لا توجد فيديوهات بعد", "No videos yet")).font(.subheadline.bold())
                        Text(t("أضف فيديو من الرئيسية", "Add a video from Home")).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                    .rafliGlass(radius: 20)
                }

                if let sourceURL { libraryRow(t("الفيديو الأصلي", "Original Video"), sourceURL, tag: t("أصلي", "ORIGINAL")) }
                if let outputURL { libraryRow(t("بعد التعديل", "Enhanced Video"), outputURL, tag: t("محسن", "ENHANCED")) }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func libraryRow(_ title: String, _ url: URL, tag: String) -> some View {
        HStack(spacing: 11) {
            RAFLIThumbnail(url: url)
                .frame(width: 88, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            VStack(alignment: ar ? .trailing : .leading, spacing: 5) {
                Text(title).font(.subheadline.bold()).lineLimit(1)
                Text(tag).font(.system(size: 9, weight: .bold)).foregroundStyle(.mint)
            }
            Spacer()
            Button { shareItem = RAFLIShareItem(url: url) } label: {
                Image(systemName: "square.and.arrow.up").foregroundStyle(.mint).frame(width: 36, height: 36)
            }
        }
        .padding(10)
        .rafliGlass(radius: 18)
    }

    private var profile: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                sectionHeader(t("الملف الشخصي", "Profile"), "")

                VStack(spacing: 12) {
                    RAFLIExactLogo(size: 76, pulse: pulse)
                    Text(t("الإصدار 1.1", "Version 1.1"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.mint)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .rafliGlass(radius: 22, strong: true)

                Button {
                    if let url = URL(string: "https://t.me/ucorc") { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 11) {
                        ZStack {
                            Circle().fill(Color.blue).frame(width: 42, height: 42)
                            Image(systemName: "paperplane.fill").foregroundStyle(.white)
                        }
                        VStack(alignment: ar ? .trailing : .leading, spacing: 2) {
                            Text(t("المطور", "Developer")).font(.caption).foregroundStyle(.secondary)
                            Text("@ucorc").font(.subheadline.bold()).foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward").foregroundStyle(.secondary)
                    }
                    .padding(12)
                }
                .buttonStyle(.plain)
                .rafliGlass(radius: 18)

                VStack(spacing: 0) {
                    profileRow(t("اللغة", "Language"), icon: "globe") {
                        Picker("", selection: $language) {
                            Text("العربية").tag("ar")
                            Text("English").tag("en")
                        }.pickerStyle(.menu).tint(.mint)
                    }
                    Divider().opacity(0.15)
                    profileRow(t("المظهر", "Appearance"), icon: light ? "sun.max.fill" : "moon.fill") {
                        Picker("", selection: $theme) {
                            Text(t("زجاجي غامق", "Dark Glass")).tag("dark")
                            Text(t("زجاجي فاتح", "Light Glass")).tag("light")
                        }.pickerStyle(.menu).tint(.mint)
                    }
                }
                .padding(.horizontal, 12)
                .rafliGlass(radius: 18)

                Button {
                    code = ""
                    loginError = false
                    withAnimation { unlocked = false }
                } label: {
                    Label(t("قفل التطبيق", "Lock App"), systemImage: "lock.fill")
                }
                .buttonStyle(RAFLICompactButton())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func profileRow<Content: View>(_ title: String, icon: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Label(title, systemImage: icon).font(.subheadline)
            Spacer()
            trailing()
        }
        .frame(height: 48)
    }

    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: ar ? .trailing : .leading, spacing: 2) {
                Text(title).font(.system(size: 24, weight: .bold, design: .rounded))
                if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
        }
    }

    private var navBar: some View {
        HStack(spacing: 4) {
            navItem(0, t("الرئيسية", "Home"), "house.fill")
            navItem(1, t("فيديوهاتي", "Videos"), "folder.fill")
            navItem(2, t("الملف", "Profile"), "person.crop.circle.fill")
        }
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 5)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.mint.opacity(0.10)).frame(height: 0.5) }
    }

    private func navItem(_ index: Int, _ title: String, _ icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { tab = index }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(tab == index ? Color.mint : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(tab == index ? Color.mint.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func authenticate() {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized == "1v" else {
            loginError = true
            return
        }
        loginError = false
        code = ""
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) { unlocked = true }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("RAFLI_\(UUID().uuidString).mov")
                try data.write(to: url, options: .atomic)
                try await analyze(url)
            } catch { await MainActor.run { status = error.localizedDescription } }
        }
    }

    private func importFile(_ source: URL) {
        Task {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            do {
                let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("RAFLI_\(UUID().uuidString).\(ext)")
                try FileManager.default.copyItem(at: source, to: url)
                try await analyze(url)
            } catch { await MainActor.run { status = error.localizedDescription } }
        }
    }

    private func analyze(_ url: URL) async throws {
        let value = try await VideoAnalyzer.analyze(url)
        await MainActor.run {
            sourceURL = url
            outputURL = nil
            report = value
            progress = 0
            status = t("تم تحليل الفيديو ✅", "Video analyzed ✅")
            tab = 0
        }
    }

    private func process() {
        guard let sourceURL else { return }
        busy = true
        progress = 0
        status = t("جاري تجهيز الفيديو…", "Preparing video…")
        Task {
            do {
                let out = try await VideoProcessor.export(source: sourceURL, preset: .maxQuality, report: report) { value in
                    Task { @MainActor in progress = value }
                }
                await MainActor.run {
                    outputURL = out
                    progress = 1
                    busy = false
                    status = t("تم تجهيز الفيديو ✅", "Video ready ✅")
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
        progress = 0
        photoItem = nil
        status = t("اختر فيديو من الصور أو الملفات", "Choose a video from Photos or Files")
    }

    private func t(_ arabic: String, _ english: String) -> String { ar ? arabic : english }
}

struct RAFLIExactLogo: View {
    let size: CGFloat
    let pulse: Bool
    var body: some View {
        Image("RAFLILogo")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: .mint.opacity(pulse ? 0.32 : 0.12), radius: pulse ? 18 : 8)
            .scaleEffect(pulse ? 1.018 : 0.99)
    }
}

struct RAFLIThumbnail: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { ProgressView().tint(.mint) }
            Circle().fill(Color.black.opacity(0.42)).frame(width: 34, height: 34)
            Image(systemName: "play.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
        }
        .clipped()
        .task { image = await makeThumbnail() }
    }
    private func makeThumbnail() async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 800, height: 800)
        do {
            let cg = try gen.copyCGImage(at: CMTime(seconds: 0.15, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: cg)
        } catch { return nil }
    }
}

struct RAFLIShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct RAFLIShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct RAFLINativePrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 49)
            .background(LinearGradient(colors: [Color.mint.opacity(configuration.isPressed ? 0.72 : 1), Color.green.opacity(configuration.isPressed ? 0.52 : 0.78)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct RAFLICompactButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.mint)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.mint.opacity(0.15)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension View {
    func rafliGlass(radius: CGFloat, strong: Bool = false) -> some View {
        background(strong ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.mint.opacity(strong ? 0.18 : 0.09), lineWidth: 0.8))
    }
}
