import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import AVKit
import UIKit

struct IRFA3LIVIP2View: View {
    @AppStorage("irfa3li_language") private var language = "ar"
    @AppStorage("irfa3li_oled") private var oled = false
    @AppStorage("irfa3li_haptics") private var haptics = true

    @State private var unlocked = false
    @State private var code = ""
    @State private var wrongCode = false
    @State private var tab: VIPTab = .studio
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var sourceURL: URL?
    @State private var outputURL: URL?
    @State private var sourceReport = VideoReport()
    @State private var outputReport = VideoReport()
    @State private var preset: RAFLIPreset = .maxQuality
    @State private var processing = false
    @State private var progress = 0.0
    @State private var phase = ""
    @State private var alertText: String?
    @State private var library: [URL] = []
    @State private var player: VIPVideo?
    @State private var share: VIPVideo?
    @State private var aura = false

    private var ar: Bool { language == "ar" }

    var body: some View {
        ZStack {
            VIPBackdrop(oled: oled, aura: aura)
            if unlocked { shell } else { lockScreen }
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
        .fullScreenCover(item: $player) { item in
            ZStack {
                Color.black.ignoresSafeArea()
                VideoPlayer(player: AVPlayer(url: item.url)).ignoresSafeArea()
            }
        }
        .sheet(item: $share) { item in VIPShareSheet(items: [item.url]) }
        .alert(t("ارفعلي", "IRFA3LI"), isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
            Button(t("حسنًا", "OK"), role: .cancel) { alertText = nil }
        } message: { Text(alertText ?? "") }
        .onAppear {
            sourceURL = RAFLIStorage.shared.restoredSource()
            outputURL = RAFLIStorage.shared.restoredOutput()
            library = RAFLIStorage.shared.allVideos()
            if let sourceURL { analyzeSource(sourceURL) }
            if let outputURL { analyzeOutput(outputURL) }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { aura = true }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 70)

            ZStack {
                Circle()
                    .fill(VIPBrand.mint.opacity(aura ? 0.18 : 0.07))
                    .frame(width: 230, height: 230)
                    .blur(radius: 48)

                Image("RAFLILogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 142, height: 142)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .shadow(color: VIPBrand.mint.opacity(0.22), radius: 38, y: 18)
            }

            Text(t("ارفعلي", "IRFA3LI"))
                .font(.system(size: 39, weight: .bold))
                .padding(.top, 28)

            Text(t("محرك فيديو خاص بك", "Your private video engine"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(VIPBrand.muted)
                .padding(.top, 7)

            VStack(spacing: 12) {
                SecureField(t("رمز الدخول", "Access code"), text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(.white.opacity(0.055))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(wrongCode ? Color.red.opacity(0.7) : .white.opacity(0.08), lineWidth: 1))
                    .onSubmit(unlock)

                Button(action: unlock) {
                    HStack {
                        Text(t("دخول", "Enter"))
                        Spacer()
                        Image(systemName: ar ? "arrow.left" : "arrow.right")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 20)
                    .frame(height: 58)
                }
                .buttonStyle(VIPPrimaryButton())
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)

            Spacer()

            Button { openTelegram() } label: {
                Label("Telegram  @ucorc", systemImage: "paperplane.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VIPBrand.muted)
            }
            .buttonStyle(.plain)

            Text("© @ucorc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VIPBrand.muted.opacity(0.7))
                .padding(.top, 9)
                .padding(.bottom, 18)
        }
    }

    private var shell: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .studio: studio
                case .library: libraryView
                case .profile: profileView
                case .settings: settingsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            floatingNav
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
    }

    private var studio: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                topBar

                if sourceURL == nil {
                    uploadHero
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else if outputURL == nil {
                    sourceStage
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    resultStage
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.88), value: sourceURL?.path)
        .animation(.spring(response: 0.55, dampingFraction: 0.88), value: outputURL?.path)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image("RAFLILogo")
                .resizable().scaledToFit()
                .frame(width: 43, height: 43)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: ar ? .trailing : .leading, spacing: 1) {
                Text(t("ارفعلي", "IRFA3LI")).font(.system(size: 20, weight: .bold))
                Text(t("استوديو الجودة", "Quality studio")).font(.system(size: 11, weight: .medium)).foregroundStyle(VIPBrand.muted)
            }
            Spacer()
            Button { tab = .profile; impact(.light) } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .buttonStyle(.plain)
        }
    }

    private var uploadHero: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.04, green: 0.22, blue: 0.18), Color(red: 0.012, green: 0.055, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 490)
                    .overlay(RoundedRectangle(cornerRadius: 38).stroke(.white.opacity(0.08), lineWidth: 1))

                Circle()
                    .fill(VIPBrand.mint.opacity(aura ? 0.18 : 0.08))
                    .frame(width: 250, height: 250)
                    .blur(radius: 48)
                    .offset(x: 80, y: -120)

                VStack(spacing: 18) {
                    Spacer()
                    Image("RAFLILogo")
                        .resizable().interpolation(.high).scaledToFit()
                        .frame(width: 126, height: 126)
                        .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
                        .shadow(color: VIPBrand.mint.opacity(0.23), radius: 30, y: 14)

                    Spacer()

                    VStack(alignment: ar ? .trailing : .leading, spacing: 8) {
                        Text(t("اختر الفيديو.", "Choose your video."))
                            .font(.system(size: 31, weight: .bold))
                        Text(t("سنحلل الملف الحقيقي أولًا، ثم نجهّز أفضل نسخة عملية بدون أرقام وهمية.", "We inspect the real file first, then prepare the strongest practical version without fake numbers."))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.64))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)
                }
                .padding(24)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .videos) {
                    vipAction(t("الصور", "Photos"), "photo.on.rectangle.angled")
                }.buttonStyle(.plain)

                Button { showFiles = true; impact(.light) } label: {
                    vipAction(t("الملفات", "Files"), "folder.fill")
                }.buttonStyle(.plain)
            }
        }
    }

    private var sourceStage: some View {
        VStack(spacing: 16) {
            if let sourceURL {
                Button { player = VIPVideo(url: sourceURL) } label: {
                    ZStack(alignment: .bottom) {
                        VIPThumbnail(url: sourceURL)
                            .frame(height: 500)
                        LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
                        HStack(alignment: .bottom) {
                            VStack(alignment: ar ? .trailing : .leading, spacing: 6) {
                                Text(t("الفيديو الأصلي", "Original video"))
                                    .font(.system(size: 22, weight: .bold))
                                Text("\(sourceReport.width)×\(sourceReport.height)  •  \(Int(sourceReport.fps.rounded())) FPS  •  \(String(format: "%.1f", sourceReport.bitrateMbps)) Mbps")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 50, height: 50)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                metric("FPS", String(format: "%.0f", sourceReport.fps))
                metric("RES", "\(sourceReport.width)×\(sourceReport.height)")
                metric("Mbps", String(format: "%.1f", sourceReport.bitrateMbps))
            }

            HStack {
                VStack(alignment: ar ? .trailing : .leading, spacing: 3) {
                    Text(t("نمط المعالجة", "Processing profile"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VIPBrand.muted)
                    Text(presetName(preset))
                        .font(.system(size: 19, weight: .semibold))
                }
                Spacer()
                Picker("Preset", selection: $preset) {
                    ForEach(RAFLIPreset.allCases) { p in Text(presetName(p)).tag(p) }
                }
                .pickerStyle(.menu)
                .tint(VIPBrand.mint)
            }
            .padding(18)
            .background(.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))

            Text(sourceReport.is60 ? t("المصدر 60fps حقيقي — نحافظ عليه حتى 60fps.", "True 60fps source — preserved up to 60fps.") : t("المصدر أقل من 60fps — لن نعرض 60 وهمي.", "Source is below 60fps — no fake 60fps claim."))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VIPBrand.muted)
                .frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)

            Button(action: process) {
                HStack {
                    Image(systemName: "sparkles")
                    Text(t("ابدأ المعالجة", "Start processing"))
                    Spacer()
                    Image(systemName: ar ? "arrow.left" : "arrow.right")
                }
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 20)
                .frame(height: 60)
            }
            .buttonStyle(VIPPrimaryButton())

            Button { resetStudio(); impact(.light) } label: {
                Text(t("اختيار فيديو آخر", "Choose another video"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VIPBrand.muted)
            }
            .buttonStyle(.plain)
        }
    }

    private var resultStage: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: ar ? .trailing : .leading, spacing: 4) {
                    Text(t("جاهز.", "Ready."))
                        .font(.system(size: 34, weight: .bold))
                    Text(t("تم فحص الناتج بعد التصدير", "Output verified after export"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VIPBrand.muted)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(VIPBrand.mint)
            }

            if let outputURL {
                Button { player = VIPVideo(url: outputURL) } label: {
                    ZStack(alignment: .bottomTrailing) {
                        VIPThumbnail(url: outputURL)
                            .frame(height: 520)
                        LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 52, height: 52)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .padding(18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                metric("FPS", String(format: "%.0f", outputReport.fps))
                metric("RES", "\(outputReport.width)×\(outputReport.height)")
                metric("Mbps", String(format: "%.1f", outputReport.bitrateMbps))
            }

            if let outputURL {
                HStack(spacing: 10) {
                    Button { save(outputURL) } label: { vipAction(t("حفظ", "Save"), "arrow.down.to.line") }.buttonStyle(.plain)
                    Button { share = VIPVideo(url: outputURL) } label: { vipAction(t("مشاركة", "Share"), "square.and.arrow.up") }.buttonStyle(.plain)
                }
            }

            Button { resetStudio(); impact(.light) } label: {
                Label(t("فيديو جديد", "New video"), systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VIPBrand.muted)
            }
            .buttonStyle(.plain)
        }
    }

    private var processingScene: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()
            VIPBackdrop(oled: true, aura: aura)

            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle().fill(VIPBrand.mint.opacity(0.12)).frame(width: 230, height: 230).blur(radius: 45)
                    Image("RAFLILogo")
                        .resizable().scaledToFit()
                        .frame(width: 126, height: 126)
                        .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
                        .scaleEffect(aura ? 1.04 : 0.96)
                }

                VStack(spacing: 8) {
                    Text(t("نعالج الفيديو", "Processing video"))
                        .font(.system(size: 30, weight: .bold))
                    Text(phase)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VIPBrand.muted)
                }

                VStack(spacing: 12) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.08))
                            Capsule().fill(VIPBrand.mint).frame(width: max(8, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 6)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 34)

                HStack(spacing: 10) {
                    capsule("H.264 HIGH")
                    capsule("CABAC")
                    capsule(sourceReport.is60 ? "TRUE 60" : "SOURCE FPS")
                }

                Spacer()
                Text("© @ucorc  •  Telegram @ucorc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VIPBrand.muted.opacity(0.72))
                    .padding(.bottom, 22)
            }
        }
        .transition(.opacity)
    }

    private var libraryView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                screenTitle(t("الفيديوهات", "Videos"), t("مكتبتك الخاصة", "Your private library"))

                if library.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(VIPBrand.mint)
                        Text(t("لا توجد فيديوهات بعد", "No videos yet"))
                            .font(.system(size: 21, weight: .semibold))
                        Text(t("كل فيديو تستورده أو تصدره يظهر هنا.", "Every imported or processed video appears here."))
                            .font(.system(size: 13))
                            .foregroundStyle(VIPBrand.muted)
                    }
                    .padding(.top, 90)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(library, id: \.path) { url in
                            Button { player = VIPVideo(url: url) } label: {
                                ZStack(alignment: .bottomLeading) {
                                    VIPThumbnail(url: url).frame(height: 245)
                                    LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .center, endPoint: .bottom)
                                    Text(url.lastPathComponent.hasPrefix("RAFLI_OUTPUT") ? t("معالج", "Processed") : t("أصلي", "Original"))
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(11)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
    }

    private var profileView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                screenTitle(t("الملف الشخصي", "Profile"), t("هوية ارفعلي", "IRFA3LI identity"))

                VStack(spacing: 16) {
                    Image("RAFLILogo")
                        .resizable().scaledToFit()
                        .frame(width: 118, height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    Text("@ucorc").font(.system(size: 27, weight: .bold))
                    Text(t("المطور والمالك", "Developer & Owner"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VIPBrand.muted)

                    HStack(spacing: 8) {
                        profileStat(t("الفيديوهات", "Videos"), "\(library.count)")
                        profileStat(t("المحرك", "Engine"), "H.264")
                    }
                }
                .padding(22)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                Button { openTelegram() } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        VStack(alignment: ar ? .trailing : .leading, spacing: 2) {
                            Text("Telegram").font(.system(size: 16, weight: .semibold))
                            Text("@ucorc").font(.system(size: 12, weight: .medium)).foregroundStyle(VIPBrand.muted)
                        }
                        Spacer()
                        Image(systemName: ar ? "chevron.left" : "chevron.right").foregroundStyle(VIPBrand.muted)
                    }
                    .padding(18)
                    .background(.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("© @ucorc  •  All rights reserved")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VIPBrand.muted.opacity(0.75))
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
    }

    private var settingsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                screenTitle(t("الإعدادات", "Settings"), t("خصص تجربتك", "Make it yours"))

                settingsRow("globe", t("اللغة", "Language")) {
                    Picker("Language", selection: $language) {
                        Text("العربية").tag("ar")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                    .tint(VIPBrand.mint)
                }

                settingsRow("circle.lefthalf.filled", t("OLED أسود", "OLED black")) {
                    Toggle("", isOn: $oled).labelsHidden().tint(VIPBrand.mint)
                }

                settingsRow("iphone.radiowaves.left.and.right", t("الاهتزاز", "Haptics")) {
                    Toggle("", isOn: $haptics).labelsHidden().tint(VIPBrand.mint)
                }

                VStack(alignment: ar ? .trailing : .leading, spacing: 8) {
                    Text(t("عن المحرك", "About the engine"))
                        .font(.system(size: 17, weight: .semibold))
                    Text(t("ارفعلي يحلل الملف الحقيقي ويعالج الفيديو محليًا. إذا كان المصدر أقل من 60fps فلن نسمي الناتج 60fps بشكل وهمي.", "IRFA3LI inspects the real file and processes locally. If the source is below 60fps, it is not falsely labelled as 60fps."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VIPBrand.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)
                .padding(18)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
    }

    private var floatingNav: some View {
        HStack(spacing: 0) {
            ForEach(VIPTab.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) { tab = item }
                    impact(.light)
                    if item == .library { library = RAFLIStorage.shared.allVideos() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon).font(.system(size: 18, weight: tab == item ? .semibold : .regular))
                        Text(item.title(ar: ar)).font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(tab == item ? VIPBrand.mint : .white.opacity(0.44))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func screenTitle(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: ar ? .trailing : .leading, spacing: 3) {
                Text(title).font(.system(size: 30, weight: .bold))
                Text(subtitle).font(.system(size: 12, weight: .medium)).foregroundStyle(VIPBrand.muted)
            }
            Spacer()
        }
    }

    private func vipAction(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.075), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(VIPBrand.muted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func capsule(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.white.opacity(0.06))
            .clipShape(Capsule())
    }

    private func profileStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .bold))
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(VIPBrand.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func settingsRow<Accessory: View>(_ icon: String, _ title: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundStyle(VIPBrand.mint).frame(width: 28)
            Text(title).font(.system(size: 15, weight: .semibold))
            Spacer()
            accessory()
        }
        .padding(17)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private func presetName(_ p: RAFLIPreset) -> String {
        switch p {
        case .preserve: return t("الحفاظ على الأصل", "Preserve Original")
        case .smart: return t("ذكي", "Smart")
        case .tiktokSafe: return t("1080 آمن", "Safe 1080")
        case .highMotion: return t("حركة عالية", "High Motion")
        case .maxQuality: return t("أقصى جودة", "Max Quality")
        case .compact: return t("حجم أخف", "Compact")
        }
    }

    private func unlock() {
        guard code.trimmingCharacters(in: .whitespacesAndNewlines) == "1v" else {
            wrongCode = true
            impactError()
            return
        }
        wrongCode = false
        code = ""
        impactSuccess()
        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) { unlocked = true }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let dst = RAFLIStorage.shared.importURL(ext: "mov")
                try data.write(to: dst, options: .atomic)
                await MainActor.run { setSource(dst) }
            } catch { await MainActor.run { alertText = error.localizedDescription } }
        }
    }

    private func importFile(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
            let dst = RAFLIStorage.shared.importURL(ext: ext)
            try? FileManager.default.removeItem(at: dst)
            try FileManager.default.copyItem(at: url, to: dst)
            setSource(dst)
        } catch { alertText = error.localizedDescription }
    }

    private func setSource(_ url: URL) {
        sourceURL = url
        outputURL = nil
        outputReport = VideoReport()
        RAFLIStorage.shared.rememberSource(url)
        library = RAFLIStorage.shared.allVideos()
        analyzeSource(url)
        impact(.medium)
    }

    private func analyzeSource(_ url: URL) {
        Task {
            if let r = try? await VideoAnalyzer.analyze(url) {
                await MainActor.run { sourceReport = r }
            }
        }
    }

    private func analyzeOutput(_ url: URL) {
        Task {
            if let r = try? await VideoAnalyzer.analyze(url) {
                await MainActor.run { outputReport = r }
            }
        }
    }

    private func process() {
        guard let sourceURL else { return }
        processing = true
        progress = 0
        phase = t("تحليل الإطارات والترميز…", "Analyzing frames and encoding…")
        impact(.medium)

        Task {
            do {
                let temp = try await VideoProcessor.export(source: sourceURL, preset: preset, report: sourceReport) { value in
                    Task { @MainActor in
                        progress = value
                        if value > 0.82 { phase = t("اللمسات الأخيرة…", "Finishing output…") }
                    }
                }
                let dst = RAFLIStorage.shared.outputURL(ext: "mp4")
                try? FileManager.default.removeItem(at: dst)
                try FileManager.default.copyItem(at: temp, to: dst)
                let report = try await VideoAnalyzer.analyze(dst)
                await MainActor.run {
                    outputURL = dst
                    outputReport = report
                    RAFLIStorage.shared.rememberOutput(dst)
                    library = RAFLIStorage.shared.allVideos()
                    progress = 1
                    processing = false
                    impactSuccess()
                }
            } catch {
                await MainActor.run {
                    processing = false
                    alertText = error.localizedDescription
                    impactError()
                }
            }
        }
    }

    private func save(_ url: URL) {
        Task {
            do {
                try await RAFLIUploadEngine().saveToPhotos(file: url)
                await MainActor.run { impactSuccess() }
            } catch { await MainActor.run { alertText = error.localizedDescription } }
        }
    }

    private func resetStudio() {
        sourceURL = nil
        outputURL = nil
        sourceReport = VideoReport()
        outputReport = VideoReport()
        photoItem = nil
    }

    private func openTelegram() {
        guard let url = URL(string: "https://t.me/ucorc") else { return }
        UIApplication.shared.open(url)
    }

    private func t(_ arText: String, _ enText: String) -> String { ar ? arText : enText }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func impactSuccess() {
        guard haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func impactError() {
        guard haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

private enum VIPTab: CaseIterable, Identifiable {
    case studio, library, profile, settings
    var id: String { String(describing: self) }
    var icon: String {
        switch self {
        case .studio: return "sparkles.rectangle.stack"
        case .library: return "play.square.stack"
        case .profile: return "person.crop.circle"
        case .settings: return "slider.horizontal.3"
        }
    }
    func title(ar: Bool) -> String {
        switch self {
        case .studio: return ar ? "الاستوديو" : "Studio"
        case .library: return ar ? "الفيديوهات" : "Videos"
        case .profile: return ar ? "حسابي" : "Profile"
        case .settings: return ar ? "الإعدادات" : "Settings"
        }
    }
}

private enum VIPBrand {
    static let mint = Color(red: 0.46, green: 0.88, blue: 0.74)
    static let muted = Color.white.opacity(0.52)
    static let deep = Color(red: 0.012, green: 0.048, blue: 0.043)
}

private struct VIPBackdrop: View {
    let oled: Bool
    let aura: Bool
    var body: some View {
        ZStack {
            (oled ? Color.black : VIPBrand.deep).ignoresSafeArea()
            Circle()
                .fill(VIPBrand.mint.opacity(aura ? 0.10 : 0.04))
                .frame(width: 360, height: 360)
                .blur(radius: 85)
                .offset(x: 160, y: -330)
            Circle()
                .fill(Color.white.opacity(0.025))
                .frame(width: 260, height: 260)
                .blur(radius: 75)
                .offset(x: -170, y: 360)
        }
    }
}

private struct VIPPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.015, green: 0.12, blue: 0.09))
            .background(VIPBrand.mint.opacity(configuration.isPressed ? 0.76 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct VIPVideo: Identifiable {
    let id = UUID()
    let url: URL
}

private struct VIPThumbnail: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.035))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView().tint(VIPBrand.mint)
            }
        }
        .clipped()
        .task(id: url.path) {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 900, height: 1400)
            if let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.15, preferredTimescale: 600), actualTime: nil) {
                image = UIImage(cgImage: cg)
            }
        }
    }
}

private struct VIPShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
