import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import AVKit
import UIKit

struct IRFA3LIIdentityView: View {
    @AppStorage("irfa3li_language") private var language = "ar"
    @AppStorage("irfa3li_oled") private var oled = false
    @AppStorage("irfa3li_haptics") private var haptics = true

    @State private var unlocked = false
    @State private var accessCode = ""
    @State private var accessError = false
    @State private var tab: IRTab = .studio
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var sourceURL: URL?
    @State private var outputURL: URL?
    @State private var sourceReport = VideoReport()
    @State private var outputReport = VideoReport()
    @State private var preset: RAFLIPreset = .maxQuality
    @State private var processing = false
    @State private var progress = 0.0
    @State private var status = ""
    @State private var alertMessage: String?
    @State private var library: [URL] = []
    @State private var playerItem: IRVideoItem?
    @State private var shareItem: IRVideoItem?
    @StateObject private var uploader = RAFLIUploadEngine()

    private var ar: Bool { language == "ar" }
    private var canvas: Color { oled ? .black : IRBrand.ink }

    var body: some View {
        ZStack {
            IRBrandBackground(oled: oled)
            if unlocked { appShell } else { lockScreen }
            if processing { processScene }
        }
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, ar ? .rightToLeft : .leftToRight)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            importFromFiles(url)
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            importFromPhotos(item)
        }
        .fullScreenCover(item: $playerItem) { item in IRPlayer(url: item.url) }
        .sheet(item: $shareItem) { item in IRShareSheet(items: [item.url]) }
        .alert(t("ارفعلي", "IRFA3LI"), isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button(t("حسنًا", "OK"), role: .cancel) { alertMessage = nil }
        } message: { Text(alertMessage ?? "") }
        .onAppear {
            sourceURL = RAFLIStorage.shared.restoredSource()
            outputURL = RAFLIStorage.shared.restoredOutput()
            refreshLibrary()
            if let sourceURL { analyzeSource(sourceURL) }
            if let outputURL { analyzeOutput(outputURL) }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("RAFLILogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
                .shadow(color: IRBrand.mint.opacity(0.18), radius: 28, y: 12)

            Text(t("ارفعلي", "IRFA3LI"))
                .font(.system(size: 37, weight: .bold))
                .padding(.top, 24)
            Text(t("جودة الفيديو، بدون ضجيج.", "Video quality, without the noise."))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(IRBrand.secondary)
                .padding(.top, 6)

            VStack(spacing: 12) {
                SecureField(t("رمز الدخول", "Access code"), text: $accessCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 17)
                    .frame(height: 56)
                    .background(IRBrand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(accessError ? Color.red.opacity(0.8) : IRBrand.line, lineWidth: 1))
                    .onSubmit(unlock)

                Button(action: unlock) {
                    HStack(spacing: 9) {
                        Text(t("دخول", "Enter"))
                        Image(systemName: ar ? "arrow.left" : "arrow.right")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(IRPrimaryButtonStyle())
            }
            .padding(.horizontal, 26)
            .padding(.top, 32)

            Spacer()
            HStack(spacing: 6) {
                Circle().fill(IRBrand.mint).frame(width: 5, height: 5)
                Text("@ucorc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(IRBrand.secondary)
            }
            .padding(.bottom, 20)
        }
    }

    private var appShell: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .studio: studio
                case .library: libraryView
                case .profile: profile
                case .settings: settings
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            IRTabBar(tab: $tab, ar: ar)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
    }

    private var studio: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                pageHeader(title: t("ارفعلي", "IRFA3LI"), subtitle: t("استوديو الجودة", "Quality studio"))

                if sourceURL == nil {
                    heroUploader
                } else if let sourceURL {
                    sourceCard(sourceURL)
                }

                if let outputURL {
                    resultCard(outputURL)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
    }

    private var heroUploader: some View {
        VStack(alignment: ar ? .trailing : .leading, spacing: 22) {
            VStack(alignment: ar ? .trailing : .leading, spacing: 7) {
                Text(t("ابدأ من الفيديو الأصلي", "Start with the original"))
                    .font(.system(size: 30, weight: .bold))
                Text(t("نقرأ الملف أولًا، ثم نعالجه بأعلى إعداد عملي من دون ادعاءات وهمية.", "We inspect first, then process at the strongest practical setting without fake claims."))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(IRBrand.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(IRBrand.heroGradient)
                    .frame(height: 300)

                VStack(spacing: 18) {
                    Image("RAFLILogo")
                        .resizable().scaledToFit()
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                    Text(t("اختر مقطعك", "Choose your video"))
                        .font(.system(size: 22, weight: .semibold))
                    Text(t("Photos أو Files", "Photos or Files"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .videos) {
                    IRActionPill(title: t("الصور", "Photos"), icon: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                Button { showFiles = true } label: {
                    IRActionPill(title: t("الملفات", "Files"), icon: "folder")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sourceCard(_ url: URL) -> some View {
        VStack(spacing: 16) {
            Button { playerItem = IRVideoItem(url: url) } label: {
                ZStack(alignment: .bottomLeading) {
                    IRThumbnail(url: url)
                        .frame(height: 360)
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                    HStack {
                        Label(t("تشغيل", "Play"), systemImage: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("SOURCE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(IRBrand.mint)
                    }
                    .padding(17)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                metric("FPS", String(format: "%.0f", sourceReport.fps))
                metric("RES", "\(sourceReport.width)×\(sourceReport.height)")
                metric("Mbps", String(format: "%.1f", sourceReport.bitrateMbps))
                metric("MB", String(format: "%.0f", sourceReport.fileSizeMB))
            }

            HStack {
                VStack(alignment: ar ? .trailing : .leading, spacing: 4) {
                    Text(t("ملف المعالجة", "Processing profile"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(IRBrand.secondary)
                    Picker("Preset", selection: $preset) {
                        ForEach(RAFLIPreset.allCases) { item in
                            Text(presetName(item)).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
                Spacer()
                Image(systemName: sourceReport.is60 ? "60.circle.fill" : "waveform.path")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(IRBrand.mint)
            }
            .padding(16)
            .background(IRBrand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(sourceReport.is60 ? t("المصدر 60fps حقيقي — سيتم الحفاظ عليه حتى 60fps.", "True 60fps source — preserved up to 60fps.") : t("المصدر أقل من 60fps — ارفعلي لن يسميه 60fps بشكل وهمي.", "Source is below 60fps — IRFA3LI will not label it fake 60fps."))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(IRBrand.secondary)
                .frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)

            Button(action: process) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text(t("جهّز النسخة", "Prepare video"))
                    Spacer()
                    Image(systemName: ar ? "arrow.left" : "arrow.right")
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .padding(.horizontal, 18)
            }
            .buttonStyle(IRPrimaryButtonStyle())
        }
    }

    private func resultCard(_ url: URL) -> some View {
        VStack(alignment: ar ? .trailing : .leading, spacing: 16) {
            HStack {
                VStack(alignment: ar ? .trailing : .leading, spacing: 4) {
                    Text(t("النسخة الجاهزة", "Ready version"))
                        .font(.system(size: 24, weight: .bold))
                    Text(t("تم فحص الملف بعد التصدير", "Verified after export"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(IRBrand.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(IRBrand.mint)
            }

            Button { playerItem = IRVideoItem(url: url) } label: {
                IRThumbnail(url: url)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                metric("FPS", String(format: "%.0f", outputReport.fps))
                metric("RES", "\(outputReport.width)×\(outputReport.height)")
                metric("Mbps", String(format: "%.1f", outputReport.bitrateMbps))
            }

            HStack(spacing: 10) {
                Button { saveToPhotos(url) } label: { IRActionPill(title: t("حفظ", "Save"), icon: "arrow.down.to.line") }
                    .buttonStyle(.plain)
                Button { shareItem = IRVideoItem(url: url) } label: { IRActionPill(title: t("مشاركة", "Share"), icon: "square.and.arrow.up") }
                    .buttonStyle(.plain)
                Button { resetStudio() } label: { IRIconButton(icon: "plus") }
                    .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(IRBrand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(IRBrand.line, lineWidth: 1))
    }

    private var libraryView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                pageHeader(title: t("الفيديوهات", "Videos"), subtitle: t("مكتبتك المحلية", "Your local library"))

                if library.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 46, weight: .light))
                            .foregroundStyle(IRBrand.mint)
                        Text(t("لا توجد فيديوهات بعد", "No videos yet"))
                            .font(.system(size: 20, weight: .semibold))
                        Text(t("أي فيديو تستورده أو تصدّره سيظهر هنا.", "Anything you import or export appears here."))
                            .font(.system(size: 14))
                            .foregroundStyle(IRBrand.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(library, id: \.path) { url in
                            Button { playerItem = IRVideoItem(url: url) } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    IRThumbnail(url: url)
                                        .frame(height: 215)
                                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    Text(url.lastPathComponent.contains("OUTPUT") ? t("نسخة معالجة", "Processed") : t("أصلي", "Original"))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundStyle(IRBrand.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .onAppear(perform: refreshLibrary)
    }

    private var profile: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                pageHeader(title: t("الملف الشخصي", "Profile"), subtitle: "@ucorc")

                VStack(spacing: 16) {
                    Image("RAFLILogo")
                        .resizable().scaledToFit()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    Text("@ucorc")
                        .font(.system(size: 25, weight: .bold))
                    Text(t("المطور والمالك", "Developer & Owner"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(IRBrand.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)

                infoRow(icon: "film", title: t("الفيديوهات المحلية", "Local videos"), value: "\(library.count)")
                infoRow(icon: "cpu", title: t("المعالجة", "Processing"), value: "H.264 High • CABAC")
                infoRow(icon: "person.crop.circle.badge.checkmark", title: t("الحقوق", "Rights"), value: "© @ucorc")
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .onAppear(perform: refreshLibrary)
    }

    private var settings: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                pageHeader(title: t("الإعدادات", "Settings"), subtitle: t("تجربة ارفعلي", "IRFA3LI experience"))

                settingsSection(title: t("اللغة", "Language")) {
                    Picker("Language", selection: $language) {
                        Text("العربية").tag("ar")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                }

                settingsSection(title: t("المظهر", "Appearance")) {
                    Toggle(t("أسود OLED", "OLED black"), isOn: $oled)
                        .tint(IRBrand.mint)
                    Divider().overlay(IRBrand.line)
                    Toggle(t("اهتزازات الواجهة", "Interface haptics"), isOn: $haptics)
                        .tint(IRBrand.mint)
                }

                settingsSection(title: t("عن ارفعلي", "About IRFA3LI")) {
                    infoLine(t("الهوية", "Identity"), t("أخضر عميق + فضي", "Deep green + silver"))
                    infoLine(t("المعالجة", "Processing"), "On-device")
                    infoLine(t("معدل الإطارات", "Frame rate"), t("حتى 60fps حسب المصدر", "Up to 60fps from source"))
                    infoLine(t("الحقوق", "Rights"), "@ucorc")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
    }

    private var processScene: some View {
        ZStack {
            canvas.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 26) {
                Spacer()
                Image("RAFLILogo")
                    .resizable().scaledToFit()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                VStack(spacing: 7) {
                    Text(t("جاري تجهيز الفيديو", "Preparing video"))
                        .font(.system(size: 27, weight: .bold))
                    Text(status)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(IRBrand.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 10) {
                    ProgressView(value: progress)
                        .tint(IRBrand.mint)
                    HStack {
                        Text("H.264 HIGH • CABAC")
                        Spacer()
                        Text("\(Int(progress * 100))%")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(IRBrand.secondary)
                }
                .padding(.horizontal, 34)
                Spacer()
                Text(t("لا تغلق ارفعلي أثناء المعالجة", "Keep IRFA3LI open while processing"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(IRBrand.secondary)
                    .padding(.bottom, 26)
            }
        }
        .transition(.opacity)
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: ar ? .trailing : .leading, spacing: 3) {
                Text(title).font(.system(size: 31, weight: .bold))
                Text(subtitle).font(.system(size: 13, weight: .medium)).foregroundStyle(IRBrand.secondary)
            }
            Spacer()
            Image("RAFLILogo")
                .resizable().scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(IRBrand.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(IRBrand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 24).foregroundStyle(IRBrand.mint)
            Text(title).font(.system(size: 15, weight: .medium))
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundStyle(IRBrand.secondary)
        }
        .padding(17)
        .background(IRBrand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: ar ? .trailing : .leading, spacing: 14) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(IRBrand.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)
        .padding(18)
        .background(IRBrand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func infoLine(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(IRBrand.secondary) }
            .font(.system(size: 14, weight: .medium))
    }

    private func presetName(_ preset: RAFLIPreset) -> String {
        guard ar else { return preset.rawValue }
        switch preset {
        case .preserve: return "حفظ الأصلي"
        case .smart: return "ارفعلي ذكي"
        case .tiktokSafe: return "TikTok 1080"
        case .highMotion: return "حركة عالية"
        case .maxQuality: return "أقصى جودة"
        case .compact: return "حجم مضغوط"
        }
    }

    private func unlock() {
        guard accessCode.trimmingCharacters(in: .whitespacesAndNewlines) == "1v" else {
            accessError = true
            feedback(.error)
            return
        }
        accessError = false
        accessCode = ""
        feedback(.success)
        withAnimation(.easeOut(duration: 0.28)) { unlocked = true }
    }

    private func importFromPhotos(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let target = RAFLIStorage.shared.importURL(ext: "mov")
                try data.write(to: target, options: .atomic)
                await MainActor.run { acceptSource(target) }
            } catch { await MainActor.run { alertMessage = error.localizedDescription } }
        }
    }

    private func importFromFiles(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
            let target = RAFLIStorage.shared.importURL(ext: ext)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: url, to: target)
            acceptSource(target)
        } catch { alertMessage = error.localizedDescription }
    }

    private func acceptSource(_ url: URL) {
        sourceURL = url
        outputURL = nil
        outputReport = VideoReport()
        RAFLIStorage.shared.rememberSource(url)
        analyzeSource(url)
        refreshLibrary()
        feedback(.success)
    }

    private func analyzeSource(_ url: URL) {
        Task {
            do { let report = try await VideoAnalyzer.analyze(url); await MainActor.run { sourceReport = report } }
            catch { await MainActor.run { alertMessage = error.localizedDescription } }
        }
    }

    private func analyzeOutput(_ url: URL) {
        Task {
            do { let report = try await VideoAnalyzer.analyze(url); await MainActor.run { outputReport = report } }
            catch { await MainActor.run { alertMessage = error.localizedDescription } }
        }
    }

    private func process() {
        guard let sourceURL else { return }
        processing = true
        progress = 0
        status = t("تحليل خصائص الملف…", "Inspecting source…")
        feedback(.medium)

        Task {
            do {
                let temp = try await VideoProcessor.export(source: sourceURL, preset: preset, report: sourceReport) { value in
                    Task { @MainActor in
                        progress = value
                        status = t("معالجة الفيديو على الجهاز…", "Processing on device…")
                    }
                }
                await MainActor.run { status = t("فحص النسخة الناتجة…", "Verifying output…") }
                let ext = temp.pathExtension.isEmpty ? "mp4" : temp.pathExtension
                let final = RAFLIStorage.shared.outputURL(ext: ext)
                try? FileManager.default.removeItem(at: final)
                try FileManager.default.copyItem(at: temp, to: final)
                let report = try await VideoAnalyzer.analyze(final)
                await MainActor.run {
                    outputURL = final
                    outputReport = report
                    RAFLIStorage.shared.rememberOutput(final)
                    progress = 1
                    processing = false
                    refreshLibrary()
                    feedback(.success)
                }
            } catch {
                await MainActor.run {
                    processing = false
                    alertMessage = error.localizedDescription
                    feedback(.error)
                }
            }
        }
    }

    private func saveToPhotos(_ url: URL) {
        Task {
            do {
                try await uploader.saveToPhotos(file: url)
                await MainActor.run { feedback(.success); alertMessage = t("تم حفظ الفيديو في الصور.", "Saved to Photos.") }
            } catch { await MainActor.run { alertMessage = error.localizedDescription } }
        }
    }

    private func resetStudio() {
        sourceURL = nil
        outputURL = nil
        sourceReport = VideoReport()
        outputReport = VideoReport()
        photoItem = nil
        feedback(.medium)
    }

    private func refreshLibrary() { library = RAFLIStorage.shared.allVideos() }

    private func feedback(_ type: IRFeedback) {
        guard haptics else { return }
        switch type {
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func t(_ arText: String, _ enText: String) -> String { ar ? arText : enText }
}

private enum IRFeedback { case medium, success, error }
private enum IRTab: CaseIterable { case studio, library, profile, settings }

private enum IRBrand {
    static let ink = Color(red: 0.025, green: 0.085, blue: 0.072)
    static let forest = Color(red: 0.035, green: 0.18, blue: 0.145)
    static let mint = Color(red: 0.67, green: 0.86, blue: 0.79)
    static let silver = Color(red: 0.80, green: 0.84, blue: 0.83)
    static let secondary = Color.white.opacity(0.56)
    static let surface = Color.white.opacity(0.055)
    static let line = Color.white.opacity(0.085)
    static let heroGradient = LinearGradient(colors: [Color(red: 0.08, green: 0.28, blue: 0.23), Color(red: 0.02, green: 0.10, blue: 0.085)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private struct IRBrandBackground: View {
    let oled: Bool
    var body: some View {
        ZStack {
            (oled ? Color.black : IRBrand.ink).ignoresSafeArea()
            RadialGradient(colors: [IRBrand.forest.opacity(oled ? 0.32 : 0.58), .clear], center: .topTrailing, startRadius: 30, endRadius: 520)
                .ignoresSafeArea()
            LinearGradient(colors: [.clear, Color.black.opacity(0.28)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

private struct IRPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.015, green: 0.08, blue: 0.065))
            .background(IRBrand.mint.opacity(configuration.isPressed ? 0.76 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct IRActionPill: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 14, weight: .semibold))
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(IRBrand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(IRBrand.line, lineWidth: 1))
    }
}

private struct IRIconButton: View {
    let icon: String
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 52, height: 52)
            .background(IRBrand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(IRBrand.line, lineWidth: 1))
    }
}

private struct IRTabBar: View {
    @Binding var tab: IRTab
    let ar: Bool

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.studio, ar ? "الرئيسية" : "Studio", "sparkles.rectangle.stack")
            tabButton(.library, ar ? "الفيديوهات" : "Videos", "play.square.stack")
            tabButton(.profile, ar ? "حسابي" : "Profile", "person.crop.circle")
            tabButton(.settings, ar ? "الإعدادات" : "Settings", "slider.horizontal.3")
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(IRBrand.line, lineWidth: 1))
    }

    private func tabButton(_ item: IRTab, _ title: String, _ icon: String) -> some View {
        Button { withAnimation(.easeOut(duration: 0.18)) { tab = item } } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(title).font(.system(size: 9, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(tab == item ? IRBrand.mint : IRBrand.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(tab == item ? Color.white.opacity(0.065) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct IRVideoItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct IRThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.04))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "video.fill").font(.system(size: 30)).foregroundStyle(IRBrand.secondary)
            }
        }
        .clipped()
        .task(id: url.path) { image = await thumbnail(url) }
    }

    private func thumbnail(_ url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)
        do {
            let cg = try generator.copyCGImage(at: CMTime(seconds: 0.15, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: cg)
        } catch { return nil }
    }
}

private struct IRPlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: AVPlayer(url: url)).ignoresSafeArea()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).frame(width: 42, height: 42).background(.ultraThinMaterial).clipShape(Circle())
            }
            .padding(18)
        }
    }
}

private struct IRShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
