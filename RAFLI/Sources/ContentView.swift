import SwiftUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation
import AVKit
import PhotosUI

struct ContentView: View {
    @AppStorage("rafli_language") private var language = "ar"
    @AppStorage("rafli_theme") private var theme = "dark"
    @AppStorage("rafli_access") private var accessGranted = false

    @State private var accessCode = ""
    @State private var loginMessage = ""
    @State private var tab = 0
    @State private var libraryFilter = 0
    @State private var showFilePicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var sourceURL: URL?
    @State private var outputURL: URL?
    @State private var report = VideoReport()
    @State private var preset: RAFLIPreset = .maxQuality
    @State private var busy = false
    @State private var progress = 0.0
    @State private var status = ""
    @State private var shareItem: ShareItem?
    @State private var pulse = false
    @State private var drift = false
    @StateObject private var uploader = RAFLIUploadEngine()

    private var isArabic: Bool { language == "ar" }
    private var isLight: Bool { theme == "light" }

    var body: some View {
        ZStack {
            animatedBackground

            if accessGranted {
                appShell
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                loginScreen
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .preferredColorScheme(isLight ? .light : .dark)
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                loadFileVideo(url)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .onChange(of: photoItem) { newItem in
            guard let newItem else { return }
            loadPhotoVideo(newItem)
        }
        .onAppear {
            status = text("اختر فيديو من الصور أو الملفات", "Choose a video from Photos or Files")
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    private var appShell: some View {
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

    private var animatedBackground: some View {
        ZStack {
            LinearGradient(
                colors: isLight
                    ? [Color.white, Color(red: 0.88, green: 0.98, blue: 0.95), Color(red: 0.80, green: 0.92, blue: 0.90)]
                    : [Color.black, Color(red: 0.0, green: 0.07, blue: 0.055), Color(red: 0.0, green: 0.02, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.mint.opacity(isLight ? 0.22 : 0.14))
                .frame(width: 360, height: 360)
                .blur(radius: 95)
                .offset(x: drift ? 190 : 70, y: drift ? -280 : -380)

            Circle()
                .fill(Color.green.opacity(isLight ? 0.13 : 0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: drift ? -170 : -60, y: drift ? 360 : 220)

            RoundedRectangle(cornerRadius: 160)
                .stroke(Color.mint.opacity(isLight ? 0.10 : 0.07), lineWidth: 1)
                .frame(width: 520, height: 240)
                .rotationEffect(.degrees(drift ? 18 : -8))
                .blur(radius: 1)
                .offset(y: -70)
        }
    }

    private var loginScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer(minLength: 80)

                RAFLILogoView(pulse: pulse)
                    .frame(width: 132, height: 132)

                VStack(spacing: 5) {
                    Text("RAFLI")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                    Text("Higher Quality. Always.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.mint)
                }

                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.mint)

                    Text(text("أدخل كود الدخول", "Enter Access Code"))
                        .font(.title3.bold())

                    SecureField(text("الكود", "Code"), text: $accessCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mint.opacity(0.28)))

                    if !loginMessage.isEmpty {
                        Text(loginMessage)
                            .font(.footnote.bold())
                            .foregroundStyle(.red)
                    }

                    Button {
                        authenticate()
                    } label: {
                        Label(text("دخول", "Enter"), systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(RAFLIPrimaryButton())
                }
                .glassCard(strong: true)

                Text(text("التطبيق مجاني بالكامل", "100% free app"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
    }

    private var homePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                homeHeader
                importCard

                if let sourceURL {
                    sourcePreview(url: sourceURL)
                    qualityStats
                    presetCard
                    encodeCard
                }

                if let sourceURL, let outputURL {
                    comparisonCard(original: sourceURL, enhanced: outputURL)
                    publishCard(url: outputURL)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 14) {
            RAFLILogoView(pulse: pulse)
                .frame(width: 62, height: 62)

            VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                Text("RAFLI")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                Text("Higher Quality. Always.")
                    .font(.caption)
                    .foregroundStyle(.mint)
            }
            Spacer()
        }
    }

    private var importCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(pulse ? 0.25 : 0.10))
                    .frame(width: 112, height: 112)
                    .blur(radius: pulse ? 16 : 5)
                Circle()
                    .fill(LinearGradient(colors: [Color.mint.opacity(0.95), Color.green.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 82, height: 82)
                    .overlay(Circle().stroke(Color.white.opacity(0.30)))
                Image(systemName: "plus")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
            }
            .scaleEffect(pulse ? 1.04 : 0.97)

            VStack(spacing: 4) {
                Text(text("اختر فيديو", "Choose Video"))
                    .font(.title3.bold())
                Text(text("من الصور أو الملفات — من أي مزود ملفات متاح", "From Photos or Files — including available file providers"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .videos) {
                    importSourceButton(title: text("الصور", "Photos"), icon: "photo.on.rectangle.angled", tint: .pink)
                }
                .buttonStyle(.plain)

                Button {
                    showFilePicker = true
                } label: {
                    importSourceButton(title: text("الملفات", "Files"), icon: "folder.fill", tint: .mint)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 9) {
                featureChip("4K", "4k.tv")
                featureChip("60 FPS", "waveform")
                featureChip(text("مجاني", "FREE"), "infinity")
            }
        }
        .padding(.vertical, 22)
        .glassCard(strong: true)
    }

    private func importSourceButton(title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 86)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.25)))
    }

    private func sourcePreview(url: URL) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
            HStack {
                Text(text("الفيديو الأصلي", "Original Video")).font(.headline.bold())
                Spacer()
                Label(text("جاهز", "Ready"), systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.mint)
            }

            VideoThumbnailView(url: url)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 8) {
                        Label("\(report.width)×\(report.height)", systemImage: "rectangle.inset.filled")
                        Label(String(format: "%.0f FPS", report.fps), systemImage: "speedometer")
                    }
                    .font(.caption.bold())
                    .padding(10)
                    .background(.black.opacity(0.60))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(10)
                }
        }
        .glassCard()
    }

    private var qualityStats: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                stat(text("الدقة", "Resolution"), "\(report.width)×\(report.height)", "rectangle.expand.vertical")
                stat("FPS", String(format: "%.2f", report.fps), "waveform.path.ecg")
            }
            HStack(spacing: 10) {
                stat(text("الترميز", "Codec"), report.codec.uppercased(), "film.stack")
                stat(text("البت ريت", "Bitrate"), String(format: "%.1f Mbps", report.bitrateMbps), "gauge.with.dots.needle.67percent")
            }
        }
    }

    private var presetCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
            HStack {
                Text(text("وضع الجودة", "Quality Mode")).font(.headline.bold())
                Spacer()
                Image(systemName: "slider.horizontal.3").foregroundStyle(.mint)
            }

            Picker("Preset", selection: $preset) {
                ForEach(RAFLIPreset.allCases) { item in
                    Text(displayName(item)).tag(item)
                }
            }
            .pickerStyle(.menu)
            .tint(.mint)

            Text(presetDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var encodeCard: some View {
        VStack(spacing: 14) {
            if busy {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.mint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%")
                        .font(.title2.bold().monospacedDigit())
                }
                .frame(width: 114, height: 114)
            }

            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                processVideo()
            } label: {
                Label(busy ? text("جاري المعالجة", "Processing") : text("ابدأ التحسين", "Start Enhancement"), systemImage: busy ? "hourglass" : "bolt.fill")
            }
            .buttonStyle(RAFLIPrimaryButton())
            .disabled(busy)
        }
        .glassCard()
    }

    private func comparisonCard(original: URL, enhanced: URL) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
            Text(text("الفيديو الأصلي / بعد التعديل", "Original / Enhanced"))
                .font(.headline.bold())

            HStack(spacing: 10) {
                miniVideo(title: text("الأصلي", "Original"), url: original, tint: .primary)
                miniVideo(title: text("بعد التعديل", "Enhanced"), url: enhanced, tint: .mint)
            }
        }
        .glassCard(strong: true)
    }

    private func miniVideo(title: String, url: URL, tint: Color) -> some View {
        VStack(spacing: 8) {
            VideoThumbnailView(url: url)
                .frame(height: 145)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(title).font(.caption.bold()).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
    }

    private func publishCard(url: URL) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(text("النتيجة جاهزة", "Result Ready")).font(.headline.bold())
                Spacer()
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.mint)
            }

            Button {
                Task {
                    do { try await uploader.saveToPhotos(file: url); status = text("تم الحفظ في الصور ✅", "Saved to Photos ✅") }
                    catch { status = error.localizedDescription }
                }
            } label: {
                Label(text("حفظ في الصور", "Save to Photos"), systemImage: "square.and.arrow.down.fill")
            }
            .buttonStyle(RAFLIPrimaryButton())

            HStack(spacing: 10) {
                Button { shareItem = ShareItem(url: url) } label: {
                    Label(text("مشاركة", "Share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(RAFLISecondaryButton())

                Button { resetForNewVideo() } label: {
                    Label(text("فيديو جديد", "New Video"), systemImage: "plus")
                }
                .buttonStyle(RAFLISecondaryButton())
            }
        }
        .glassCard()
    }

    private var videosPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                pageTitle(text("فيديوهاتي", "My Videos"), subtitle: text("مرتب بين الأصلي وبعد التعديل", "Organized by original and enhanced"))

                Picker("Library", selection: $libraryFilter) {
                    Text(text("الكل", "All")).tag(0)
                    Text(text("الأصلي", "Original")).tag(1)
                    Text(text("بعد التعديل", "Enhanced")).tag(2)
                }
                .pickerStyle(.segmented)

                if sourceURL == nil && outputURL == nil {
                    emptyVideos
                } else {
                    if libraryFilter != 2, let sourceURL {
                        libraryCard(title: text("الفيديو الأصلي", "Original Video"), badge: text("أصلي", "ORIGINAL"), url: sourceURL, tint: .primary)
                    }
                    if libraryFilter != 1, let outputURL {
                        libraryCard(title: text("الفيديو بعد التعديل", "Enhanced Video"), badge: text("محسن", "ENHANCED"), url: outputURL, tint: .mint)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
    }

    private var emptyVideos: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.play.fill")
                .font(.system(size: 44))
                .foregroundStyle(.mint)
            Text(text("لا توجد فيديوهات بعد", "No videos yet")).font(.headline)
            Text(text("اختر فيديو من الرئيسية وسيظهر هنا الأصل والنتيجة.", "Choose a video on Home and both versions will appear here."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .glassCard()
    }

    private func libraryCard(title: String, badge: String, url: URL, tint: Color) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 11) {
            VideoThumbnailView(url: url)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            HStack {
                VStack(alignment: isArabic ? .trailing : .leading, spacing: 3) {
                    Text(title).font(.headline.bold())
                    Text(badge).font(.caption2.bold()).foregroundStyle(tint)
                }
                Spacer()
                Button { shareItem = ShareItem(url: url) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(.mint)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .glassCard()
    }

    private var profilePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                pageTitle(text("الملف الشخصي", "Profile"), subtitle: text("الإعدادات والحقوق", "Settings and credits"))

                VStack(spacing: 14) {
                    RAFLILogoView(pulse: pulse)
                        .frame(width: 92, height: 92)
                    Text(text("الإصدار 1.1", "Version 1.1"))
                        .font(.headline.bold())
                        .foregroundStyle(.mint)
                }
                .frame(maxWidth: .infinity)
                .glassCard(strong: true)

                Button {
                    if let url = URL(string: "https://t.me/ucorc") { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.blue).frame(width: 48, height: 48)
                            Image(systemName: "paperplane.fill").foregroundStyle(.white)
                        }
                        VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                            Text(text("المطور", "Developer")).font(.headline.bold())
                            Text("@ucorc").font(.subheadline.bold()).foregroundStyle(.mint)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
                .glassCard(strong: true)

                VStack(spacing: 0) {
                    HStack {
                        Label(text("اللغة", "Language"), systemImage: "globe")
                        Spacer()
                        Picker("Language", selection: $language) {
                            Text("العربية").tag("ar")
                            Text("English").tag("en")
                        }
                        .pickerStyle(.menu)
                        .tint(.mint)
                    }
                    .padding(.vertical, 12)

                    Divider().opacity(0.25)

                    HStack {
                        Label(text("المظهر", "Appearance"), systemImage: isLight ? "sun.max.fill" : "moon.stars.fill")
                        Spacer()
                        Picker("Theme", selection: $theme) {
                            Text(text("زجاجي غامق", "Dark Glass")).tag("dark")
                            Text(text("زجاجي فاتح", "Light Glass")).tag("light")
                        }
                        .pickerStyle(.menu)
                        .tint(.mint)
                    }
                    .padding(.vertical, 12)

                    Divider().opacity(0.25)

                    HStack {
                        Label(text("الإصدار", "Version"), systemImage: "info.circle.fill")
                        Spacer()
                        Text("1.1").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                .glassCard()

                Button {
                    withAnimation { accessGranted = false; accessCode = "" }
                } label: {
                    Label(text("تسجيل خروج", "Log Out"), systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(RAFLISecondaryButton())
            }
            .padding(16)
            .padding(.bottom, 24)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            navButton(index: 0, title: text("الرئيسية", "Home"), icon: "house.fill")
            navButton(index: 1, title: text("فيديوهاتي", "Videos"), icon: "folder.fill")
            navButton(index: 2, title: text("الملف", "Profile"), icon: "person.fill")
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.mint.opacity(0.12)).frame(height: 1) }
    }

    private func navButton(index: Int, title: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) { tab = index }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3.bold())
                Text(title).font(.caption.bold())
            }
            .foregroundStyle(tab == index ? Color.mint : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(tab == index ? Color.mint.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func authenticate() {
        if accessCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "1v" {
            loginMessage = ""
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { accessGranted = true }
        } else {
            loginMessage = text("الكود غير صحيح", "Incorrect code")
        }
    }

    private func loadPhotoVideo(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run { status = text("تعذر قراءة الفيديو", "Could not read video") }
                    return
                }
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_PHOTO.mov")
                try data.write(to: temp, options: .atomic)
                try await analyzeAndUse(temp)
            } catch {
                await MainActor.run { status = error.localizedDescription }
            }
        }
    }

    private func loadFileVideo(_ url: URL) {
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_FILE." + ext)
                try? FileManager.default.removeItem(at: temp)
                try FileManager.default.copyItem(at: url, to: temp)
                try await analyzeAndUse(temp)
            } catch {
                await MainActor.run { status = error.localizedDescription }
            }
        }
    }

    private func analyzeAndUse(_ url: URL) async throws {
        let newReport = try await VideoAnalyzer.analyze(url)
        await MainActor.run {
            sourceURL = url
            outputURL = nil
            report = newReport
            progress = 0
            tab = 0
            status = text("تم تحليل الفيديو الحقيقي ✅", "Video analyzed successfully ✅")
        }
    }

    private func processVideo() {
        guard let sourceURL else { return }
        busy = true
        progress = 0
        status = text("جاري تجهيز الفيديو…", "Preparing video…")

        Task {
            do {
                let output = try await VideoProcessor.export(source: sourceURL, preset: preset, report: report) { value in
                    Task { @MainActor in progress = value }
                }
                await MainActor.run {
                    outputURL = output
                    busy = false
                    progress = 1
                    status = text("تم تجهيز الفيديو ✅", "Video ready ✅")
                }
            } catch {
                await MainActor.run {
                    busy = false
                    status = error.localizedDescription
                }
            }
        }
    }

    private func resetForNewVideo() {
        sourceURL = nil
        outputURL = nil
        report = VideoReport()
        progress = 0
        photoItem = nil
        status = text("اختر فيديو جديد من الصور أو الملفات", "Choose a new video from Photos or Files")
    }

    private func pageTitle(_ title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 4) {
                Text(title).font(.largeTitle.bold())
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 7) {
            Image(systemName: icon).foregroundStyle(.mint)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
        .padding(14)
        .glassCard()
    }

    private func featureChip(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.mint.opacity(0.16)))
    }

    private func text(_ ar: String, _ en: String) -> String { isArabic ? ar : en }

    private func displayName(_ preset: RAFLIPreset) -> String {
        switch preset {
        case .preserve: return text("الحفاظ على الأصل", "Preserve Original")
        case .smart: return text("RAFLI ذكي", "RAFLI Smart")
        case .tiktokSafe: return text("TikTok 1080 آمن", "TikTok Safe 1080")
        case .highMotion: return text("حركة عالية", "High Motion")
        case .maxQuality: return text("أقصى جودة", "ULTRA MAX")
        case .compact: return text("حجم أخف", "Compact")
        }
    }

    private var presetDescription: String {
        switch preset {
        case .preserve: return text("بدون إعادة ترميز عندما يكون ذلك ممكنًا.", "Avoids re-encoding when possible.")
        case .smart: return text("يضبط البت ريت تلقائيًا حسب المصدر.", "Adapts bitrate to the source.")
        case .tiktokSafe: return text("1080p H.264 بإعداد متوازن.", "Balanced 1080p H.264 output.")
        case .highMotion: return text("بت ريت أعلى للمشاهد السريعة.", "Higher bitrate for fast motion.")
        case .maxQuality: return text("أقوى إعداد ترميز متاح داخل RAFLI.", "Highest RAFLI encoding preset.")
        case .compact: return text("حجم أصغر مع جودة مناسبة.", "Smaller file with practical quality.")
        }
    }
}

struct RAFLILogoView: View {
    let pulse: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.18, blue: 0.14), Color(red: 0.0, green: 0.045, blue: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .mint.opacity(pulse ? 0.55 : 0.22), radius: pulse ? 26 : 10)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
            VStack(spacing: -2) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.72), lineWidth: 3)
                    Image(systemName: "arrow.up").font(.title2.black()).foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)
                Image(systemName: "tray.fill").font(.system(size: 38, weight: .light)).foregroundStyle(.white.opacity(0.72))
            }
        }
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.black.opacity(0.26))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView().tint(.mint)
            }
            Circle().fill(.black.opacity(0.50)).frame(width: 50, height: 50)
            Image(systemName: "play.fill").foregroundStyle(.white)
        }
        .clipped()
        .task { image = await thumbnail() }
    }

    private func thumbnail() async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
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
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct RAFLIPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.black)
            .background(LinearGradient(colors: [Color.mint.opacity(configuration.isPressed ? 0.62 : 0.98), Color.green.opacity(configuration.isPressed ? 0.44 : 0.76)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .shadow(color: .mint.opacity(0.18), radius: 12)
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
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.mint.opacity(configuration.isPressed ? 0.10 : 0.24)))
    }
}

extension View {
    func glassCard(strong: Bool = false) -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(strong ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.mint.opacity(strong ? 0.20 : 0.10), lineWidth: 1))
    }
}
