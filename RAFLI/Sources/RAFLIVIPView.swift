import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import AVKit
import UIKit

struct RAFLIVIPView: View {
    @AppStorage("rafli_vip_language") private var language = "ar"
    @AppStorage("rafli_vip_theme") private var theme = "dark"

    @State private var unlocked = false
    @State private var code = ""
    @State private var codeError = false
    @State private var tab = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var sourceURL: URL?
    @State private var outputURL: URL?
    @State private var sourceReport = VideoReport()
    @State private var outputReport = VideoReport()
    @State private var preset: RAFLIPreset = .maxQuality
    @State private var busy = false
    @State private var progress = 0.0
    @State private var status = ""
    @State private var playItem: VIPPlayItem?
    @State private var shareItem: VIPShareItem?
    @State private var ambient = false
    @StateObject private var uploader = RAFLIUploadEngine()

    private var ar: Bool { language == "ar" }
    private var light: Bool { theme == "light" }

    var body: some View {
        ZStack {
            vipBackground
            if unlocked { shell } else { login }
        }
        .environment(\.layoutDirection, ar ? .rightToLeft : .leftToRight)
        .preferredColorScheme(light ? .light : .dark)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            importFile(url)
        }
        .onChange(of: photoItem) { item in
            if let item { importPhoto(item) }
        }
        .fullScreenCover(item: $playItem) { item in
            VIPVideoPlayer(url: item.url)
        }
        .sheet(item: $shareItem) { item in
            VIPShareSheet(items: [item.url])
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { ambient = true }
            restoreLastSession()
        }
    }

    private var vipBackground: some View {
        ZStack {
            LinearGradient(
                colors: light
                    ? [Color(red: 0.94, green: 0.97, blue: 0.96), .white, Color(red: 0.91, green: 0.96, blue: 0.94)]
                    : [Color(red: 0.005, green: 0.016, blue: 0.015), Color.black, Color(red: 0.0, green: 0.055, blue: 0.043)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            Circle()
                .fill(Color.mint.opacity(light ? 0.17 : 0.09))
                .frame(width: 340, height: 340)
                .blur(radius: 110)
                .offset(x: ambient ? 150 : 70, y: -320)

            Circle()
                .fill(Color.green.opacity(light ? 0.11 : 0.055))
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .offset(x: ambient ? -120 : -180, y: 360)
        }
    }

    private var login: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: max(55, geo.safeAreaInsets.top + 45))

                    Image("RAFLILogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                        .shadow(color: .mint.opacity(ambient ? 0.32 : 0.13), radius: ambient ? 28 : 12)

                    Text("RAFLI")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .padding(.top, 17)

                    Text(t("محرك الفيديو الاحترافي", "Professional Video Engine"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    VStack(spacing: 14) {
                        HStack(spacing: 9) {
                            Image(systemName: "lock.shield.fill").foregroundStyle(.mint)
                            Text(t("دخول خاص", "Private Access")).font(.headline)
                            Spacer()
                            Text("VIP").font(.caption2.black()).foregroundStyle(.mint)
                        }

                        SecureField(t("رمز الدخول", "Access code"), text: $code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.primary.opacity(light ? 0.035 : 0.055))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(codeError ? Color.red.opacity(0.9) : Color.mint.opacity(0.22)))
                            .onSubmit { authenticate() }

                        if codeError {
                            Label(t("الكود غير صحيح", "Incorrect code"), systemImage: "xmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)
                        }

                        Button(action: authenticate) {
                            HStack {
                                Text(t("دخول RAFLI", "Enter RAFLI"))
                                Spacer()
                                Image(systemName: ar ? "arrow.left" : "arrow.right")
                            }
                        }
                        .buttonStyle(VIPPrimaryButton())
                    }
                    .padding(17)
                    .vipGlass(radius: 24, strong: true)
                    .padding(.top, 30)

                    Text(t("يُطلب الرمز عند كل تشغيل جديد", "Code required on each fresh launch"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 12)

                    Spacer(minLength: 50)
                }
                .frame(minHeight: geo.size.height)
                .padding(.horizontal, 22)
            }
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
            vipTabBar
        }
    }

    private var homePage: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                vipHeader
                heroImport

                if let sourceURL {
                    mediaPanel(title: t("الفيديو الأصلي", "Original Video"), tag: "SOURCE", url: sourceURL, report: sourceReport)
                    enginePanel
                }

                if let outputURL {
                    mediaPanel(title: t("نسخة RAFLI", "RAFLI Master"), tag: "VERIFIED", url: outputURL, report: outputReport)
                    proofPanel
                    resultActions(outputURL)
                }
            }
            .padding(.horizontal, 13)
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
    }

    private var vipHeader: some View {
        HStack(spacing: 10) {
            Image("RAFLILogo")
                .resizable().scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: ar ? .trailing : .leading, spacing: 1) {
                Text("RAFLI").font(.system(size: 20, weight: .black, design: .rounded))
                Text("NATIVE VIDEO ENGINE").font(.system(size: 8, weight: .bold)).tracking(1.1).foregroundStyle(.secondary)
            }
            Spacer()
            Text("1.4 VIP")
                .font(.caption2.black())
                .foregroundStyle(.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.mint.opacity(0.09))
                .clipShape(Capsule())
        }
        .frame(height: 54)
    }

    private var heroImport: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: ar ? .trailing : .leading, spacing: 4) {
                    Text(t("ابدأ من الملف الأصلي", "Start from the original"))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Text(t("اختيار مباشر من الصور أو الملفات", "Direct import from Photos or Files"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(Color.mint.opacity(0.12)).frame(width: 54, height: 54)
                    Image(systemName: "arrow.up.to.line.compact").font(.system(size: 21, weight: .bold)).foregroundStyle(.mint)
                }
            }

            HStack(spacing: 9) {
                PhotosPicker(selection: $photoItem, matching: .videos) {
                    importButton(t("الصور", "Photos"), icon: "photo.fill.on.rectangle.fill", accent: .pink)
                }.buttonStyle(.plain)

                Button { showFiles = true } label: {
                    importButton(t("الملفات", "Files"), icon: "folder.fill", accent: .mint)
                }.buttonStyle(.plain)
            }
        }
        .padding(16)
        .vipGlass(radius: 23, strong: true)
    }

    private func importButton(_ title: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(accent)
            Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 47)
        .background(Color.primary.opacity(light ? 0.035 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.16)))
    }

    private func mediaPanel(title: String, tag: String, url: URL, report: VideoReport) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: ar ? .trailing : .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold())
                    Text(tag).font(.system(size: 8, weight: .black)).tracking(1).foregroundStyle(.mint)
                }
                Spacer()
                Button { playItem = VIPPlayItem(url: url) } label: {
                    Label(t("تشغيل", "Play"), systemImage: "play.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.mint)
            }

            Button { playItem = VIPPlayItem(url: url) } label: {
                VIPThumbnail(url: url)
                    .frame(height: 185)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }.buttonStyle(.plain)

            HStack(spacing: 7) {
                metric("\(report.width)×\(report.height)", t("الدقة", "Resolution"))
                metric(String(format: "%.0f", report.fps), "FPS")
                metric(String(format: "%.1fM", report.bitrateMbps), "BITRATE")
            }
        }
        .padding(13)
        .vipGlass(radius: 21)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Color.primary.opacity(light ? 0.03 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var enginePanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: ar ? .trailing : .leading, spacing: 3) {
                    Text(t("محرك RAFLI", "RAFLI Engine")).font(.headline.bold())
                    Text(engineSubtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Preset", selection: $preset) {
                    ForEach(RAFLIPreset.allCases) { p in Text(p.rawValue).tag(p) }
                }
                .pickerStyle(.menu)
                .tint(.mint)
            }

            HStack(spacing: 7) {
                techBadge("1080p", "rectangle.expand.vertical")
                techBadge(sourceReport.is60 ? "TRUE 60" : "SOURCE FPS", "waveform")
                techBadge("H.264 HIGH", "film.fill")
                techBadge(preset == .maxQuality ? "40 Mbps" : bitrateText, "gauge.with.dots.needle.67percent")
            }

            if busy {
                ProgressView(value: progress).tint(.mint)
                HStack {
                    Text(status).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%").font(.caption.bold().monospacedDigit())
                }
            }

            Button { process() } label: {
                HStack(spacing: 9) {
                    Image(systemName: busy ? "hourglass" : "bolt.fill")
                    Text(busy ? t("جاري بناء النسخة", "Building master") : t("ابدأ المعالجة الفعلية", "Start Real Processing"))
                }
            }
            .buttonStyle(VIPPrimaryButton())
            .disabled(busy)
        }
        .padding(14)
        .vipGlass(radius: 22, strong: true)
    }

    private func techBadge(_ text: String, _ icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.caption).foregroundStyle(.mint)
            Text(text).font(.system(size: 8, weight: .bold)).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Color.mint.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var proofPanel: some View {
        VStack(spacing: 9) {
            HStack {
                Label(t("إثبات الملف الناتج", "Verified Output"), systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.mint)
                Spacer()
                Text("\(outputReport.score)/100").font(.caption.black().monospacedDigit())
            }
            comparison(t("الدقة", "Resolution"), "\(sourceReport.width)×\(sourceReport.height)", "\(outputReport.width)×\(outputReport.height)")
            comparison("FPS", String(format: "%.2f", sourceReport.fps), String(format: "%.2f", outputReport.fps))
            comparison("Bitrate", String(format: "%.1fM", sourceReport.bitrateMbps), String(format: "%.1fM", outputReport.bitrateMbps))
            comparison(t("الحجم", "Size"), String(format: "%.1fMB", sourceReport.fileSizeMB), String(format: "%.1fMB", outputReport.fileSizeMB))
        }
        .padding(14)
        .vipGlass(radius: 20)
    }

    private func comparison(_ name: String, _ before: String, _ after: String) -> some View {
        HStack {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(before).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Image(systemName: ar ? "arrow.left" : "arrow.right").font(.caption2).foregroundStyle(.mint)
            Text(after).font(.caption.bold().monospacedDigit())
        }
    }

    private func resultActions(_ url: URL) -> some View {
        HStack(spacing: 9) {
            Button {
                Task {
                    do {
                        try await uploader.saveToPhotos(file: url)
                        await MainActor.run { status = t("تم الحفظ في الصور ✅", "Saved to Photos ✅") }
                    } catch {
                        await MainActor.run { status = error.localizedDescription }
                    }
                }
            } label: {
                Label(t("حفظ في الصور", "Save to Photos"), systemImage: "arrow.down.to.line.compact")
            }.buttonStyle(VIPPrimaryButton())

            Button { shareItem = VIPShareItem(url: url) } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(VIPSecondaryButton())
            .frame(width: 58)
        }
    }

    private var libraryPage: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                pageTitle(t("فيديوهاتي", "My Videos"), t("آخر ملفات RAFLI المحفوظة", "Your latest RAFLI files"))

                if sourceURL == nil && outputURL == nil {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack.badge.play.fill").font(.system(size: 34)).foregroundStyle(.mint)
                        Text(t("لا توجد فيديوهات", "No videos yet")).font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                    .vipGlass(radius: 21)
                }

                if let sourceURL { libraryRow(t("الأصلي", "Original"), sourceURL, sourceReport) }
                if let outputURL { libraryRow(t("نسخة RAFLI", "RAFLI Master"), outputURL, outputReport) }
            }
            .padding(14)
            .padding(.bottom, 24)
        }
    }

    private func libraryRow(_ title: String, _ url: URL, _ report: VideoReport) -> some View {
        Button { playItem = VIPPlayItem(url: url) } label: {
            HStack(spacing: 11) {
                VIPThumbnail(url: url).frame(width: 104, height: 76).clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: ar ? .trailing : .leading, spacing: 4) {
                    Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
                    Text("\(report.width)×\(report.height) • \(Int(report.fps.rounded())) FPS")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(url.lastPathComponent).font(.caption2).foregroundStyle(.mint).lineLimit(1)
                }
                Spacer()
                Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(.mint)
            }
            .padding(11)
        }
        .buttonStyle(.plain)
        .vipGlass(radius: 18)
    }

    private var profilePage: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                pageTitle(t("الملف", "Profile"), t("إعدادات RAFLI", "RAFLI Settings"))

                HStack(spacing: 12) {
                    Image("RAFLILogo").resizable().scaledToFit().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: ar ? .trailing : .leading, spacing: 3) {
                        Text("RAFLI").font(.headline.black())
                        Text("Native Engine 1.4 VIP").font(.caption).foregroundStyle(.mint)
                    }
                    Spacer()
                }
                .padding(14)
                .vipGlass(radius: 21, strong: true)

                Button {
                    if let u = URL(string: "https://t.me/ucorc") { UIApplication.shared.open(u) }
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
                        Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                    }.padding(12)
                }
                .buttonStyle(.plain)
                .vipGlass(radius: 18)

                VStack(spacing: 0) {
                    settingsRow(t("اللغة", "Language"), "globe") {
                        Picker("", selection: $language) {
                            Text("العربية").tag("ar")
                            Text("English").tag("en")
                        }.pickerStyle(.menu).tint(.mint)
                    }
                    Divider().opacity(0.15)
                    settingsRow(t("المظهر", "Appearance"), light ? "sun.max.fill" : "moon.fill") {
                        Picker("", selection: $theme) {
                            Text(t("زجاجي داكن", "Dark Glass")).tag("dark")
                            Text(t("زجاجي فاتح", "Light Glass")).tag("light")
                        }.pickerStyle(.menu).tint(.mint)
                    }
                }
                .padding(.horizontal, 12)
                .vipGlass(radius: 18)

                Button {
                    code = ""
                    codeError = false
                    withAnimation(.easeOut(duration: 0.2)) { unlocked = false }
                } label: {
                    Label(t("قفل التطبيق", "Lock App"), systemImage: "lock.fill")
                }.buttonStyle(VIPSecondaryButton())
            }
            .padding(14)
            .padding(.bottom, 24)
        }
    }

    private func settingsRow<C: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> C) -> some View {
        HStack {
            Label(title, systemImage: icon).font(.subheadline)
            Spacer()
            content()
        }.frame(height: 50)
    }

    private func pageTitle(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: ar ? .trailing : .leading, spacing: 2) {
                Text(title).font(.system(size: 24, weight: .black, design: .rounded))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var vipTabBar: some View {
        HStack(spacing: 5) {
            tabButton(0, t("الرئيسية", "Home"), "house.fill")
            tabButton(1, t("فيديوهاتي", "Videos"), "rectangle.stack.fill")
            tabButton(2, t("الملف", "Profile"), "person.fill")
        }
        .padding(.horizontal, 9)
        .padding(.top, 7)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.mint.opacity(0.08)).frame(height: 0.5) }
    }

    private func tabButton(_ i: Int, _ title: String, _ icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { tab = i }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(tab == i ? Color.mint : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(tab == i ? Color.mint.opacity(0.09) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func authenticate() {
        let entered = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entered == "1v" else {
            codeError = true
            unlocked = false
            return
        }
        codeError = false
        code = ""
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { unlocked = true }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let dest = RAFLIStorage.shared.importURL(ext: "mov")
                try data.write(to: dest, options: .atomic)
                RAFLIStorage.shared.rememberSource(dest)
                try await analyzeSource(dest)
            } catch {
                await MainActor.run { status = error.localizedDescription }
            }
        }
    }

    private func importFile(_ source: URL) {
        Task {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            do {
                let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
                let dest = RAFLIStorage.shared.importURL(ext: ext)
                try FileManager.default.copyItem(at: source, to: dest)
                RAFLIStorage.shared.rememberSource(dest)
                try await analyzeSource(dest)
            } catch {
                await MainActor.run { status = error.localizedDescription }
            }
        }
    }

    private func analyzeSource(_ url: URL) async throws {
        let r = try await VideoAnalyzer.analyze(url)
        await MainActor.run {
            sourceURL = url
            sourceReport = r
            outputURL = nil
            outputReport = VideoReport()
            progress = 0
            status = t("تم تحليل المصدر", "Source analyzed")
            tab = 0
        }
    }

    private func process() {
        guard let sourceURL else { return }
        busy = true
        progress = 0
        outputURL = nil
        outputReport = VideoReport()
        status = t("جاري الترميز الحقيقي…", "Real encoding in progress…")

        Task {
            do {
                let out = try await VideoProcessor.export(source: sourceURL, preset: preset, report: sourceReport) { value in
                    Task { @MainActor in progress = value }
                }
                RAFLIStorage.shared.rememberOutput(out)
                let verified = try await VideoAnalyzer.analyze(out)
                await MainActor.run {
                    outputURL = out
                    outputReport = verified
                    progress = 1
                    busy = false
                    status = t("تم الترميز والتحقق من الملف", "Encoded and verified")
                }
            } catch {
                await MainActor.run {
                    busy = false
                    status = error.localizedDescription
                }
            }
        }
    }

    private func restoreLastSession() {
        if let src = RAFLIStorage.shared.restoredSource() {
            sourceURL = src
            Task { if let r = try? await VideoAnalyzer.analyze(src) { await MainActor.run { sourceReport = r } } }
        }
        if let out = RAFLIStorage.shared.restoredOutput() {
            outputURL = out
            Task { if let r = try? await VideoAnalyzer.analyze(out) { await MainActor.run { outputReport = r } } }
        }
        status = t("جاهز", "Ready")
    }

    private var engineSubtitle: String {
        if sourceReport.is60 { return t("المصدر 60fps حقيقي — سيتم الحفاظ عليه", "True 60fps source — preserved") }
        return t("لا يتم اختراع 60fps وهمي من مصدر أقل", "No fake 60fps is invented from a lower-FPS source")
    }

    private var bitrateText: String {
        String(format: "%.0f Mbps", Double(preset.targetBitrate) / 1_000_000.0)
    }

    private func t(_ arText: String, _ enText: String) -> String { ar ? arText : enText }
}

struct VIPPlayItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct VIPShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct VIPVideoPlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: AVPlayer(url: url)).ignoresSafeArea()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline.bold()).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(.black.opacity(0.55)).clipShape(Circle())
            }.padding()
        }
    }
}

struct VIPThumbnail: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { ProgressView().tint(.mint) }
            Circle().fill(.black.opacity(0.48)).frame(width: 46, height: 46)
            Image(systemName: "play.fill").foregroundStyle(.white).font(.system(size: 15, weight: .bold))
        }
        .clipped()
        .task { image = await thumbnail() }
    }

    private func thumbnail() async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 900, height: 900)
        do {
            let cg = try gen.copyCGImage(at: CMTime(seconds: 0.18, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: cg)
        } catch { return nil }
    }
}

struct VIPShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct VIPPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .frame(height: 49)
            .background(LinearGradient(colors: [Color.mint.opacity(configuration.isPressed ? 0.75 : 1), Color.green.opacity(configuration.isPressed ? 0.55 : 0.78)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: .mint.opacity(0.10), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct VIPSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.mint)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mint.opacity(0.14)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension View {
    func vipGlass(radius: CGFloat, strong: Bool = false) -> some View {
        background(strong ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.16), Color.mint.opacity(0.10), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            )
    }
}
