import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import AVKit
import UIKit

struct IRFA3LIRebuildView: View {
    @AppStorage("irfa3li_language") private var language = "ar"
    @AppStorage("irfa3li_oled") private var oled = false
    @AppStorage("irfa3li_haptics") private var haptics = true

    @State private var unlocked = false
    @State private var code = ""
    @State private var wrongCode = false
    @State private var tab: RootTab = .home
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
    @State private var alertText: String?
    @State private var library: [URL] = []
    @State private var player: VideoItem?
    @State private var share: VideoItem?
    @State private var logoPulse = false
    @StateObject private var uploader = RAFLIUploadEngine()

    private var ar: Bool { language == "ar" }

    var body: some View {
        ZStack {
            RootBackdrop(oled: oled)
            if unlocked { shell } else { lock }
            if processing { processingScene }
        }
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, ar ? .rightToLeft : .leftToRight)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            importFile(url)
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            importPhoto(item)
        }
        .fullScreenCover(item: $player) { item in VideoPlayer(player: AVPlayer(url: item.url)).ignoresSafeArea() }
        .sheet(item: $share) { item in ActivitySheet(items: [item.url]) }
        .alert(t("ارفعلي", "IRFA3LI"), isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
            Button(t("حسنًا", "OK"), role: .cancel) { alertText = nil }
        } message: { Text(alertText ?? "") }
        .onAppear {
            sourceURL = RAFLIStorage.shared.restoredSource()
            outputURL = RAFLIStorage.shared.restoredOutput()
            refreshLibrary()
            if let sourceURL { analyzeSource(sourceURL) }
            if let outputURL { analyzeOutput(outputURL) }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { logoPulse = true }
        }
    }

    private var lock: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("RAFLILogo")
                .resizable().interpolation(.high).scaledToFit()
                .frame(width: 126, height: 126)
                .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
                .shadow(color: RootBrand.mint.opacity(logoPulse ? 0.30 : 0.12), radius: logoPulse ? 34 : 18, y: 10)

            Text(t("ارفعلي", "IRFA3LI"))
                .font(.system(size: 34, weight: .bold, design: .default))
                .padding(.top, 22)
            Text(t("الفيديو كما يجب أن يصل.", "Video, prepared properly."))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RootBrand.secondary)
                .padding(.top, 6)

            VStack(spacing: 12) {
                SecureField(t("رمز الدخول", "Access code"), text: $code)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 18).frame(height: 56)
                    .background(RootBrand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(wrongCode ? Color.red.opacity(0.75) : RootBrand.line))
                    .onSubmit(unlock)

                Button(action: unlock) {
                    Text(t("دخول", "Enter"))
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 56)
                }
                .buttonStyle(FilledButtonStyle())
            }
            .padding(.horizontal, 26).padding(.top, 30)
            Spacer()

            Button { openTelegram() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "paperplane.fill")
                    Text("Telegram  @ucorc")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RootBrand.secondary)
            }
            .buttonStyle(.plain)
            Text("© @ucorc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RootBrand.secondary.opacity(0.72))
                .padding(.top, 8).padding(.bottom, 18)
        }
    }

    private var shell: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home: home
                case .library: libraryView
                case .profile: profile
                case .settings: settings
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            rootTabBar
        }
    }

    private var home: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                header(title: t("ارفعلي", "IRFA3LI"), subtitle: t("استوديو الفيديو", "Video studio"))
                if sourceURL == nil { emptyHero } else { selectedFlow }
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 34)
        }
    }

    private var emptyHero: some View {
        VStack(spacing: 22) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.055, green: 0.23, blue: 0.19), Color(red: 0.018, green: 0.075, blue: 0.068)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 390)
                    .overlay(alignment: .topTrailing) {
                        Circle().fill(RootBrand.mint.opacity(0.13)).frame(width: 190).blur(radius: 38).offset(x: 55, y: -55)
                    }

                Image("RAFLILogo")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                VStack(alignment: ar ? .trailing : .leading, spacing: 7) {
                    Text(t("ابدأ من الأصل", "Start from the original"))
                        .font(.system(size: 28, weight: .bold))
                    Text(t("اختر الفيديو، وافحصه، ثم جهّز أفضل نسخة عملية للنشر.", "Choose, inspect, then prepare the strongest practical version for publishing."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .videos) {
                    actionCell(title: t("الصور", "Photos"), icon: "photo.on.rectangle.angled")
                }.buttonStyle(.plain)
                Button { showFiles = true } label: { actionCell(title: t("الملفات", "Files"), icon: "folder.fill") }.buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                featureLabel("waveform.path.ecg", t("تحليل حقيقي", "Real analysis"))
                featureLabel("lock.shield", t("محلي على الجهاز", "On-device"))
                featureLabel("checkmark.seal", t("نتيجة قابلة للفحص", "Verified output"))
            }
        }
    }

    private var selectedFlow: some View {
        VStack(spacing: 18) {
            if let sourceURL {
                Button { player = VideoItem(url: sourceURL) } label: {
                    ZStack(alignment: .bottom) {
                        Thumb(url: sourceURL).frame(height: 420)
                        LinearGradient(colors: [.clear, .black.opacity(0.84)], startPoint: .center, endPoint: .bottom)
                        HStack(alignment: .bottom) {
                            VStack(alignment: ar ? .trailing : .leading, spacing: 5) {
                                Text(t("الفيديو الأصلي", "Original video")).font(.system(size: 21, weight: .bold))
                                Text("\(sourceReport.width)×\(sourceReport.height)  •  \(Int(sourceReport.fps.rounded())) FPS  •  \(String(format: "%.1f", sourceReport.bitrateMbps)) Mbps")
                                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.67))
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill").font(.system(size: 38)).foregroundStyle(.white)
                        }.padding(18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                }.buttonStyle(.plain)

                VStack(spacing: 13) {
                    HStack {
                        VStack(alignment: ar ? .trailing : .leading, spacing: 3) {
                            Text(t("طريقة التجهيز", "Preparation mode")).font(.system(size: 13, weight: .medium)).foregroundStyle(RootBrand.secondary)
                            Text(presetName(preset)).font(.system(size: 19, weight: .semibold))
                        }
                        Spacer()
                        Picker("Preset", selection: $preset) {
                            ForEach(RAFLIPreset.allCases) { p in Text(presetName(p)).tag(p) }
                        }
                        .labelsHidden().pickerStyle(.menu).tint(RootBrand.mint)
                    }

                    Divider().overlay(RootBrand.line)

                    HStack(spacing: 0) {
                        stat(title: "FPS", value: String(format: "%.0f", sourceReport.fps))
                        stat(title: "RES", value: "\(sourceReport.width)×\(sourceReport.height)")
                        stat(title: "MB", value: String(format: "%.0f", sourceReport.fileSizeMB))
                    }
                }
                .padding(18)
                .background(RootBrand.surface)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button(action: process) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(t("جهّز الفيديو", "Prepare video"))
                        Spacer()
                        Image(systemName: ar ? "arrow.left" : "arrow.right")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 18).frame(height: 58)
                }.buttonStyle(FilledButtonStyle())

                Button { resetStudio() } label: {
                    Text(t("اختيار فيديو آخر", "Choose another video")).font(.system(size: 14, weight: .medium)).foregroundStyle(RootBrand.secondary)
                }.buttonStyle(.plain)
            }

            if let outputURL { outputSection(outputURL) }
        }
    }

    private func outputSection(_ url: URL) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: ar ? .trailing : .leading, spacing: 3) {
                    Text(t("النسخة الجاهزة", "Ready version")).font(.system(size: 25, weight: .bold))
                    Text(t("تم فحصها بعد التصدير", "Inspected after export")).font(.system(size: 13, weight: .medium)).foregroundStyle(RootBrand.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 27)).foregroundStyle(RootBrand.mint)
            }

            Button { player = VideoItem(url: url) } label: {
                Thumb(url: url).frame(height: 320).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }.buttonStyle(.plain)

            HStack(spacing: 8) {
                statTile("FPS", String(format: "%.0f", outputReport.fps))
                statTile("RES", "\(outputReport.width)×\(outputReport.height)")
                statTile("Mbps", String(format: "%.1f", outputReport.bitrateMbps))
            }

            HStack(spacing: 10) {
                Button { save(url) } label: { actionCell(title: t("حفظ", "Save"), icon: "arrow.down.to.line") }.buttonStyle(.plain)
                Button { share = VideoItem(url: url) } label: { actionCell(title: t("مشاركة", "Share"), icon: "square.and.arrow.up") }.buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    private var libraryView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                header(title: t("الفيديوهات", "Videos"), subtitle: t("مكتبة ارفعلي المحلية", "Your local IRFA3LI library"))
                if library.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "film.stack").font(.system(size: 42, weight: .light)).foregroundStyle(RootBrand.mint)
                        Text(t("مكتبتك فارغة", "Your library is empty")).font(.system(size: 20, weight: .semibold))
                        Text(t("الفيديوهات التي تستوردها أو تصدّرها تظهر هنا.", "Imported and processed videos appear here."))
                            .font(.system(size: 14)).foregroundStyle(RootBrand.secondary)
                    }.padding(.vertical, 90)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(library, id: \.path) { url in
                            Button { player = VideoItem(url: url) } label: {
                                ZStack(alignment: .bottomLeading) {
                                    Thumb(url: url).frame(height: 235)
                                    LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                                    Text(url.lastPathComponent.hasPrefix("RAFLI_OUTPUT") ? t("معالج", "Processed") : t("أصلي", "Original"))
                                        .font(.system(size: 11, weight: .semibold)).padding(10)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 34)
        }
    }

    private var profile: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                header(title: t("الملف الشخصي", "Profile"), subtitle: t("هوية وحقوق ارفعلي", "IRFA3LI identity & rights"))

                VStack(spacing: 17) {
                    Image("RAFLILogo").resizable().interpolation(.high).scaledToFit().frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                    Text("@ucorc").font(.system(size: 24, weight: .bold))
                    Text(t("المطور والمالك", "Developer & Owner")).font(.system(size: 14, weight: .medium)).foregroundStyle(RootBrand.secondary)
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(RootBrand.mint)
                        Text(t("الحقوق محفوظة", "All rights reserved")).font(.system(size: 13, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)

                Button { openTelegram() } label: {
                    profileRow(icon: "paperplane.fill", title: "Telegram", value: "@ucorc")
                }.buttonStyle(.plain)

                profileRow(icon: "film.stack", title: t("الفيديوهات", "Videos"), value: "\(library.count)")
                profileRow(icon: "lock.shield.fill", title: t("المعالجة", "Processing"), value: t("محلي", "On-device"))
                profileRow(icon: "number", title: t("الإصدار", "Version"), value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")

                Text("© 2026 @ucorc • IRFA3LI")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(RootBrand.secondary.opacity(0.7)).padding(.top, 8)
            }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 34)
        }
    }

    private var settings: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                header(title: t("الإعدادات", "Settings"), subtitle: t("التطبيق على طريقتك", "Make it yours"))

                VStack(spacing: 0) {
                    settingRow(icon: "globe", title: t("اللغة", "Language")) {
                        Picker("Language", selection: $language) { Text("العربية").tag("ar"); Text("English").tag("en") }.labelsHidden().pickerStyle(.menu).tint(.white)
                    }
                    Divider().overlay(RootBrand.line).padding(.leading, 50)
                    settingRow(icon: "circle.lefthalf.filled", title: "OLED") { Toggle("", isOn: $oled).labelsHidden().tint(RootBrand.mint) }
                    Divider().overlay(RootBrand.line).padding(.leading, 50)
                    settingRow(icon: "iphone.radiowaves.left.and.right", title: t("الاهتزازات", "Haptics")) { Toggle("", isOn: $haptics).labelsHidden().tint(RootBrand.mint) }
                }
                .background(RootBrand.surface).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: ar ? .trailing : .leading, spacing: 10) {
                    Text(t("عن ارفعلي", "About IRFA3LI")).font(.system(size: 17, weight: .semibold))
                    Text(t("يعالج الفيديو محليًا ويعرض خصائص الملف الحقيقية قبل وبعد التصدير. لا يدّعي 60fps إذا لم يكن المصدر 60fps.", "IRFA3LI processes video locally and shows real file properties before and after export. It never claims 60fps when the source is not 60fps."))
                        .font(.system(size: 13, weight: .regular)).foregroundStyle(RootBrand.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)
                .padding(19).background(RootBrand.surface).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button { openTelegram() } label: {
                    HStack { Image(systemName: "paperplane.fill"); Text(t("تواصل عبر Telegram", "Contact on Telegram")); Spacer(); Text("@ucorc").foregroundStyle(RootBrand.secondary) }
                        .font(.system(size: 15, weight: .semibold)).padding(18)
                        .background(RootBrand.surface).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 34)
        }
    }

    private var processingScene: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 26) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 7).frame(width: 150, height: 150)
                    Circle().trim(from: 0, to: max(0.02, progress)).stroke(RootBrand.mint, style: StrokeStyle(lineWidth: 7, lineCap: .round)).frame(width: 150, height: 150).rotationEffect(.degrees(-90))
                    Image("RAFLILogo").resizable().scaledToFit().frame(width: 86, height: 86).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                Text(t("جاري تجهيز الفيديو", "Preparing your video")).font(.system(size: 26, weight: .bold))
                Text("\(Int(progress * 100))%").font(.system(size: 17, weight: .semibold, design: .monospaced)).foregroundStyle(RootBrand.mint)
                Text(status).font(.system(size: 13, weight: .medium)).foregroundStyle(RootBrand.secondary).multilineTextAlignment(.center).padding(.horizontal, 34)
            }
        }
        .transition(.opacity)
        .zIndex(20)
    }

    private var rootTabBar: some View {
        HStack(spacing: 0) {
            tabButton(.home, "house.fill", t("الرئيسية", "Home"))
            tabButton(.library, "rectangle.stack.fill", t("الفيديوهات", "Videos"))
            tabButton(.profile, "person.crop.circle.fill", t("الحساب", "Profile"))
            tabButton(.settings, "slider.horizontal.3", t("الإعدادات", "Settings"))
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.07)))
        .padding(.horizontal, 14).padding(.bottom, 8)
    }

    private func tabButton(_ item: RootTab, _ icon: String, _ title: String) -> some View {
        Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { tab = item }; tap() } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(title).font(.system(size: 9, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(tab == item ? RootBrand.mint : RootBrand.secondary)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(tab == item ? RootBrand.mint.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func header(title: String, subtitle: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: ar ? .trailing : .leading, spacing: 3) {
                Text(title).font(.system(size: 29, weight: .bold))
                Text(subtitle).font(.system(size: 13, weight: .medium)).foregroundStyle(RootBrand.secondary)
            }
            Spacer()
            Image("RAFLILogo").resizable().interpolation(.high).scaledToFit().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func actionCell(title: String, icon: String) -> some View {
        HStack(spacing: 8) { Image(systemName: icon); Text(title) }
            .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 52)
            .background(RootBrand.surface).clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(RootBrand.line))
    }

    private func featureLabel(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) { Image(systemName: icon).foregroundStyle(RootBrand.mint); Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(RootBrand.secondary).lineLimit(1).minimumScaleFactor(0.7) }
            .frame(maxWidth: .infinity)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 3) { Text(value).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6); Text(title).font(.system(size: 9, weight: .semibold)).foregroundStyle(RootBrand.secondary) }
            .frame(maxWidth: .infinity)
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(value).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.55); Text(title).font(.system(size: 9, weight: .semibold)).foregroundStyle(RootBrand.secondary) }
            .frame(maxWidth: .infinity).frame(height: 60).background(RootBrand.surface).clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 26).foregroundStyle(RootBrand.mint)
            Text(title).font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium)).foregroundStyle(RootBrand.secondary)
        }.padding(18).background(RootBrand.surface).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func settingRow<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 26).foregroundStyle(RootBrand.mint)
            Text(title).font(.system(size: 15, weight: .semibold))
            Spacer(); content()
        }.padding(.horizontal, 18).frame(height: 62)
    }

    private func unlock() {
        if code.trimmingCharacters(in: .whitespacesAndNewlines) == "1v" {
            wrongCode = false; code = ""; tap(success: true)
            withAnimation(.easeOut(duration: 0.28)) { unlocked = true }
        } else { wrongCode = true; tap(success: false) }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw NSError(domain: "IRFA3LI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load video"] ) }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "mov"
                let dst = RAFLIStorage.shared.importURL(ext: ext)
                try data.write(to: dst, options: .atomic)
                await MainActor.run { acceptSource(dst) }
            } catch { await MainActor.run { alertText = error.localizedDescription } }
        }
    }

    private func importFile(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
            let dst = RAFLIStorage.shared.importURL(ext: ext)
            try FileManager.default.copyItem(at: url, to: dst)
            acceptSource(dst)
        } catch { alertText = error.localizedDescription }
    }

    private func acceptSource(_ url: URL) {
        sourceURL = url; outputURL = nil; outputReport = VideoReport()
        RAFLIStorage.shared.rememberSource(url)
        analyzeSource(url); refreshLibrary(); tap()
    }

    private func analyzeSource(_ url: URL) {
        Task { do { let r = try await VideoAnalyzer.analyze(url); await MainActor.run { sourceReport = r } } catch { await MainActor.run { alertText = error.localizedDescription } } }
    }

    private func analyzeOutput(_ url: URL) {
        Task { do { let r = try await VideoAnalyzer.analyze(url); await MainActor.run { outputReport = r } } catch { await MainActor.run { alertText = error.localizedDescription } } }
    }

    private func process() {
        guard let sourceURL else { return }
        processing = true; progress = 0.02; status = t("تحليل الملف وتجهيز المحرك…", "Analyzing file and preparing engine…")
        Task {
            do {
                let temp = try await VideoProcessor.export(source: sourceURL, preset: preset, report: sourceReport) { p in
                    Task { @MainActor in progress = max(progress, min(0.94, p)); status = t("معالجة الفيديو محليًا…", "Processing video on-device…") }
                }
                await MainActor.run { status = t("التحقق من الملف الناتج…", "Verifying processed file…"); progress = 0.96 }
                let ext = temp.pathExtension.isEmpty ? "mp4" : temp.pathExtension
                let dst = RAFLIStorage.shared.outputURL(ext: ext)
                try? FileManager.default.removeItem(at: dst)
                try FileManager.default.copyItem(at: temp, to: dst)
                let report = try await VideoAnalyzer.analyze(dst)
                await MainActor.run {
                    outputURL = dst; outputReport = report; RAFLIStorage.shared.rememberOutput(dst); refreshLibrary(); progress = 1; status = t("جاهز", "Ready")
                    tap(success: true)
                    withAnimation(.easeOut(duration: 0.2)) { processing = false }
                }
            } catch {
                await MainActor.run { processing = false; alertText = error.localizedDescription; tap(success: false) }
            }
        }
    }

    private func save(_ url: URL) {
        Task { do { try await uploader.saveToPhotos(file: url); await MainActor.run { tap(success: true); alertText = t("تم حفظ الفيديو في الصور.", "Video saved to Photos.") } } catch { await MainActor.run { alertText = error.localizedDescription } } }
    }

    private func resetStudio() {
        sourceURL = nil; outputURL = nil; sourceReport = VideoReport(); outputReport = VideoReport(); photoItem = nil
        UserDefaults.standard.removeObject(forKey: "rafli_last_source"); UserDefaults.standard.removeObject(forKey: "rafli_last_output")
        tap()
    }

    private func refreshLibrary() { library = RAFLIStorage.shared.allVideos() }

    private func openTelegram() {
        guard let url = URL(string: "https://t.me/ucorc") else { return }
        UIApplication.shared.open(url); tap()
    }

    private func tap(success: Bool? = nil) {
        guard haptics else { return }
        if let success { UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error) }
        else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func t(_ arText: String, _ enText: String) -> String { ar ? arText : enText }

    private func presetName(_ p: RAFLIPreset) -> String {
        switch p {
        case .preserve: return t("الحفاظ على الأصل", "Preserve Original")
        case .smart: return t("ذكي", "Smart")
        case .tiktokSafe: return t("TikTok 1080", "TikTok 1080")
        case .highMotion: return t("حركة عالية", "High Motion")
        case .maxQuality: return t("أقصى جودة", "Max Quality")
        case .compact: return t("حجم أصغر", "Compact")
        }
    }
}

private enum RootTab { case home, library, profile, settings }
private struct VideoItem: Identifiable { let id = UUID(); let url: URL }

private enum RootBrand {
    static let ink = Color(red: 0.022, green: 0.055, blue: 0.051)
    static let surface = Color.white.opacity(0.055)
    static let line = Color.white.opacity(0.075)
    static let secondary = Color.white.opacity(0.58)
    static let mint = Color(red: 0.61, green: 0.86, blue: 0.79)
}

private struct RootBackdrop: View {
    let oled: Bool
    var body: some View {
        ZStack {
            (oled ? Color.black : RootBrand.ink).ignoresSafeArea()
            if !oled {
                Circle().fill(Color(red: 0.05, green: 0.32, blue: 0.25).opacity(0.18)).frame(width: 360).blur(radius: 90).offset(x: 170, y: -270)
                Circle().fill(Color(red: 0.13, green: 0.20, blue: 0.18).opacity(0.22)).frame(width: 300).blur(radius: 90).offset(x: -170, y: 320)
            }
        }
    }
}

private struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.02, green: 0.075, blue: 0.065))
            .background(RootBrand.mint.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct Thumb: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.04))
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: "video.fill").font(.system(size: 30)).foregroundStyle(RootBrand.secondary) }
        }
        .clipped()
        .task(id: url) {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 700, height: 700)
            do {
                let cg = try gen.copyCGImage(at: CMTime(seconds: 0.2, preferredTimescale: 600), actualTime: nil)
                await MainActor.run { image = UIImage(cgImage: cg) }
            } catch { }
        }
    }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
