import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import AVKit
import UIKit

struct RAFLIEliteView: View {
    @AppStorage("rafli_elite_language") private var language = "ar"
    @AppStorage("rafli_elite_theme") private var theme = "obsidian"
    @AppStorage("rafli_elite_motion") private var motionEnabled = true
    @AppStorage("rafli_elite_haptics") private var hapticsEnabled = true

    @State private var unlocked = false
    @State private var code = ""
    @State private var codeError = false
    @State private var tab: EliteTab = .studio
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
    @State private var selectedVideo: EliteVideoItem?
    @State private var shareItem: EliteShareItem?
    @State private var libraryItems: [URL] = []
    @State private var entrance = false
    @State private var glow = false
    @StateObject private var uploader = RAFLIUploadEngine()

    private var ar: Bool { language == "ar" }

    var body: some View {
        ZStack {
            EliteBackdrop(theme: theme, animated: motionEnabled)
            if unlocked { shell } else { login }
            if busy { processingOverlay }
        }
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, ar ? .rightToLeft : .leftToRight)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            importFile(url)
        }
        .onChange(of: photoItem) { item in if let item { importPhoto(item) } }
        .fullScreenCover(item: $selectedVideo) { item in ElitePlayer(url: item.url) }
        .sheet(item: $shareItem) { item in EliteActivity(items: [item.url]) }
        .onAppear {
            status = t("اختر الفيديو الأصلي", "Choose the original video")
            sourceURL = RAFLIStorage.shared.restoredSource()
            outputURL = RAFLIStorage.shared.restoredOutput()
            refreshLibrary()
            if let sourceURL { analyzeSource(sourceURL) }
            if let outputURL { analyzeOutput(outputURL) }
            withAnimation(.spring(response: 0.85, dampingFraction: 0.84).delay(0.06)) { entrance = true }
            if motionEnabled { withAnimation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true)) { glow = true } }
        }
    }

    private var login: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(themeAccent.opacity(glow ? 0.23 : 0.08)).frame(width: 176, height: 176).blur(radius: 38)
                Circle().stroke(themeAccent.opacity(0.24), lineWidth: 1).frame(width: 138, height: 138)
                Image("RAFLILogo")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(width: 108, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.22), lineWidth: 0.7))
                    .shadow(color: themeAccent.opacity(0.26), radius: 30)
            }
            .scaleEffect(entrance ? 1 : 0.82).opacity(entrance ? 1 : 0)

            Text("RAFLI")
                .font(.system(size: 32, weight: .black, design: .rounded)).tracking(2.2)
                .padding(.top, 24)
            Text("PRIVATE VIDEO ENGINE")
                .font(.system(size: 9, weight: .bold)).tracking(2.0).foregroundStyle(themeAccent)
                .padding(.top, 5)

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: ar ? .trailing : .leading, spacing: 3) {
                        Text(t("دخول RAFLI", "Enter RAFLI")).font(.headline.weight(.bold))
                        Text(t("مساحتك الخاصة لمعالجة الفيديو", "Your private video processing space")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "lock.shield.fill").font(.title3).foregroundStyle(themeAccent)
                }
                SecureField(t("رمز الدخول", "Access code"), text: $code)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 16).frame(height: 54)
                    .background(Color.white.opacity(0.055))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(codeError ? Color.red.opacity(0.75) : Color.white.opacity(0.09)))
                    .onSubmit(authenticate)
                if codeError { Text(t("الرمز غير صحيح", "Incorrect code")).font(.caption.weight(.bold)).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading) }
                Button(action: authenticate) {
                    HStack { Text(t("دخول", "Enter")); Spacer(); Image(systemName: ar ? "arrow.left" : "arrow.right") }
                }.buttonStyle(ElitePrimaryStyle(accent: themeAccent))
            }
            .elitePanel(radius: 30)
            .padding(.horizontal, 22).padding(.top, 30)
            .offset(y: entrance ? 0 : 30).opacity(entrance ? 1 : 0)
            Spacer()
            Text("@ucorc  •  RAFLI ELITE").font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundStyle(.secondary).padding(.bottom, 18)
        }
    }

    private var shell: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .studio: studio
                case .videos: videos
                case .profile: profile
                case .settings: settings
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            eliteNav
        }
    }

    private var studio: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                eliteHeader(title: "RAFLI", subtitle: t("محرك الفيديو الخاص", "Private video engine"))

                VStack(alignment: ar ? .trailing : .leading, spacing: 7) {
                    Text(t("ارفع بأفضل نسخة ممكنة.", "Upload the strongest version possible."))
                        .font(.system(size: 29, weight: .black, design: .rounded))
                    Text(t("تحليل حقيقي للملف، معالجة محلية، ونتيجة يمكن التحقق منها.", "Real file analysis, local processing, and a verifiable result."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)

                if sourceURL == nil { uploadPortal }
                if let url = sourceURL { sourceExperience(url) }
                if let url = outputURL { resultExperience(url) }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 30)
        }
    }

    private var uploadPortal: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(LinearGradient(colors: [themeAccent.opacity(0.18), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 260)
                    .overlay(RoundedRectangle(cornerRadius: 36).stroke(Color.white.opacity(0.09), lineWidth: 1))
                VStack(spacing: 15) {
                    ZStack {
                        Circle().fill(themeAccent.opacity(glow ? 0.22 : 0.10)).frame(width: 104, height: 104).blur(radius: 20)
                        Circle().fill(Color.white.opacity(0.07)).frame(width: 78, height: 78)
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 42, weight: .medium)).foregroundStyle(themeAccent)
                    }
                    Text(t("اختر الفيديو الأصلي", "Choose original video")).font(.title3.weight(.bold))
                    Text(t("Photos أو Files — نقرأ خصائصه أولًا قبل أي معالجة", "Photos or Files — we inspect it before processing"))
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.horizontal, 24)
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .videos) { portalButton(t("الصور", "Photos"), "photo.on.rectangle.angled") }.buttonStyle(.plain)
                Button { showFiles = true } label: { portalButton(t("الملفات", "Files"), "folder.fill") }.buttonStyle(.plain)
            }
        }
    }

    private func portalButton(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).frame(height: 50)
            .background(Color.white.opacity(0.055)).clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.08)))
    }

    private func sourceExperience(_ url: URL) -> some View {
        VStack(spacing: 14) {
            Button { selectedVideo = EliteVideoItem(url: url) } label: {
                ZStack(alignment: .bottom) {
                    EliteThumbnail(url: url).frame(height: 320)
                    LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                    HStack {
                        Label(t("تشغيل", "Play"), systemImage: "play.fill").font(.caption.weight(.bold))
                        Spacer()
                        Text("SOURCE").font(.system(size: 9, weight: .black)).tracking(1.2).foregroundStyle(themeAccent)
                    }.padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.10)))
            }.buttonStyle(.plain)

            HStack(spacing: 8) {
                metric("FPS", String(format: "%.0f", sourceReport.fps))
                metric("RES", "\(sourceReport.width)×\(sourceReport.height)")
                metric("Mbps", String(format: "%.1f", sourceReport.bitrateMbps))
                metric("MB", String(format: "%.0f", sourceReport.fileSizeMB))
            }

            VStack(alignment: ar ? .trailing : .leading, spacing: 10) {
                Text(t("نمط المعالجة", "Processing profile")).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Picker("Preset", selection: $preset) {
                    ForEach(RAFLIPreset.allCases) { item in Text(item.rawValue).tag(item) }
                }.pickerStyle(.menu).tint(themeAccent)
                Text(sourceReport.is60 ? t("المصدر 60fps حقيقي — نحافظ عليه.", "True 60fps source — preserved.") : t("المصدر أقل من 60fps — لن نعرض 60 وهمي.", "Source is below 60fps — no fake 60fps claim."))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(14).background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 18))

            Button { process() } label: {
                HStack { Image(systemName: "bolt.fill"); Text(t("تشغيل RAFLI Engine", "Run RAFLI Engine")); Spacer(); Image(systemName: ar ? "chevron.left" : "chevron.right") }
            }.buttonStyle(ElitePrimaryStyle(accent: themeAccent))
        }
    }

    private func resultExperience(_ url: URL) -> some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: ar ? .trailing : .leading, spacing: 2) {
                    Text(t("النسخة الناتجة", "Processed result")).font(.headline.weight(.bold))
                    Text(t("تم تحليل الملف الناتج بعد التصدير", "Output inspected after export")).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(); Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(themeAccent)
            }
            Button { selectedVideo = EliteVideoItem(url: url) } label: {
                EliteThumbnail(url: url).frame(height: 250).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }.buttonStyle(.plain)
            HStack(spacing: 8) {
                metric("FPS", String(format: "%.0f", outputReport.fps))
                metric("RES", "\(outputReport.width)×\(outputReport.height)")
                metric("Mbps", String(format: "%.1f", outputReport.bitrateMbps))
            }
            HStack(spacing: 9) {
                Button { save(url) } label: { Label(t("حفظ", "Save"), systemImage: "square.and.arrow.down") }.buttonStyle(EliteSecondaryStyle())
                Button { shareItem = EliteShareItem(url: url) } label: { Label(t("مشاركة", "Share"), systemImage: "square.and.arrow.up") }.buttonStyle(EliteSecondaryStyle())
                Button { resetStudio() } label: { Image(systemName: "plus") }.buttonStyle(EliteSecondaryStyle())
            }
        }.elitePanel(radius: 28)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.55)
            Text(title).font(.system(size: 8, weight: .black)).tracking(0.8).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).frame(height: 58)
            .background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.065)))
    }

    private var videos: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                eliteHeader(title: t("فيديوهاتي", "My Videos"), subtitle: t("مكتبة RAFLI المحلية", "Local RAFLI library"))
                if libraryItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack.fill").font(.system(size: 38)).foregroundStyle(themeAccent)
                        Text(t("المكتبة فارغة", "Library is empty")).font(.headline.weight(.bold))
                        Text(t("كل فيديو يتم استيراده أو تصديره سيظهر هنا.", "Imported and processed videos appear here.")).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 70).elitePanel(radius: 28)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(libraryItems, id: \.path) { url in
                            Button { selectedVideo = EliteVideoItem(url: url) } label: {
                                ZStack(alignment: .bottomLeading) {
                                    EliteThumbnail(url: url).frame(height: 210)
                                    LinearGradient(colors: [.clear, .black.opacity(0.76)], startPoint: .center, endPoint: .bottom)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(url.lastPathComponent.hasPrefix("RAFLI_OUTPUT") ? "ENHANCED" : "ORIGINAL").font(.system(size: 8, weight: .black)).foregroundStyle(themeAccent)
                                        Text(url.lastPathComponent).font(.system(size: 9, weight: .semibold)).lineLimit(1)
                                    }.padding(10)
                                }.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 28)
        }
    }

    private var profile: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                eliteHeader(title: t("الملف الشخصي", "Profile"), subtitle: "RAFLI OWNER")
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(themeAccent.opacity(0.18)).frame(width: 118, height: 118).blur(radius: 24)
                        Image("RAFLILogo").resizable().interpolation(.high).scaledToFit().frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    Text("@ucorc").font(.title2.weight(.black))
                    Text(t("المطور والمالك", "Developer & Owner")).font(.caption.weight(.bold)).foregroundStyle(themeAccent)
                    HStack(spacing: 8) {
                        profileStat(t("الفيديوهات", "Videos"), "\(libraryItems.count)")
                        profileStat(t("الإصدار", "Version"), "ELITE")
                        profileStat(t("المحرك", "Engine"), "NATIVE")
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 24).elitePanel(radius: 32)

                VStack(spacing: 0) {
                    profileRow("crown.fill", t("حقوق RAFLI", "RAFLI Rights"), "© @ucorc")
                    Divider().opacity(0.12)
                    profileRow("shield.lefthalf.filled", t("الخصوصية", "Privacy"), t("المعالجة محليًا", "Local processing"))
                    Divider().opacity(0.12)
                    profileRow("cpu", t("المحرك", "Engine"), "H.264 High • CABAC")
                }.elitePanel(radius: 24)
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 28)
        }
    }

    private func profileStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(value).font(.headline.weight(.black)); Text(title).font(.caption2).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity).frame(height: 64).background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 17))
    }

    private func profileRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(themeAccent).frame(width: 30)
            VStack(alignment: ar ? .trailing : .leading, spacing: 2) { Text(title).font(.subheadline.weight(.bold)); Text(value).font(.caption2).foregroundStyle(.secondary) }
            Spacer()
        }.padding(.vertical, 11)
    }

    private var settings: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                eliteHeader(title: t("الإعدادات", "Settings"), subtitle: t("خصص RAFLI كما تريد", "Make RAFLI yours"))

                settingSection(t("المظهر", "Appearance")) {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            themeButton("obsidian", "Obsidian", Color.mint)
                            themeButton("midnight", "Midnight", Color.blue)
                            themeButton("titanium", "Titanium", Color.white)
                        }
                        HStack(spacing: 8) {
                            themeButton("violet", "Violet", Color.purple)
                            themeButton("ember", "Ember", Color.orange)
                            themeButton("ocean", "Ocean", Color.cyan)
                        }
                    }
                }

                settingSection(t("اللغة", "Language")) {
                    HStack(spacing: 10) {
                        languageButton("ar", "العربية", "AR")
                        languageButton("en", "English", "EN")
                    }
                }

                settingSection(t("التجربة", "Experience")) {
                    VStack(spacing: 0) {
                        Toggle(isOn: $motionEnabled) { Label(t("الحركات والخلفيات", "Motion & backgrounds"), systemImage: "sparkles") }.tint(themeAccent).padding(.vertical, 8)
                        Divider().opacity(0.12)
                        Toggle(isOn: $hapticsEnabled) { Label(t("اهتزازات اللمس", "Haptics"), systemImage: "iphone.radiowaves.left.and.right") }.tint(themeAccent).padding(.vertical, 8)
                    }
                }

                settingSection(t("عن RAFLI", "About RAFLI")) {
                    VStack(spacing: 10) {
                        aboutRow(t("النسخة", "Build"), "RAFLI ELITE")
                        aboutRow(t("المالك", "Owner"), "@ucorc")
                        aboutRow(t("الترميز", "Encoding"), "H.264 High / AAC")
                        aboutRow(t("الفريمات", "Frame rate"), t("يحافظ على المصدر حتى 60fps", "Preserves source up to 60fps"))
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 28)
        }
    }

    private func settingSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: ar ? .trailing : .leading, spacing: 12) {
            Text(title.uppercased()).font(.system(size: 10, weight: .black)).tracking(1.2).foregroundStyle(.secondary)
            content()
        }.frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading).elitePanel(radius: 24)
    }

    private func themeButton(_ key: String, _ name: String, _ color: Color) -> some View {
        Button {
            theme = key; impact()
        } label: {
            VStack(spacing: 8) {
                Circle().fill(color).frame(width: 24, height: 24).shadow(color: color.opacity(0.35), radius: 10)
                Text(name).font(.system(size: 9, weight: .bold)).lineLimit(1)
            }.frame(maxWidth: .infinity).frame(height: 70)
                .background(theme == key ? color.opacity(0.12) : Color.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(theme == key ? color.opacity(0.55) : Color.white.opacity(0.06)))
        }.buttonStyle(.plain)
    }

    private func languageButton(_ key: String, _ name: String, _ badge: String) -> some View {
        Button { language = key; impact() } label: {
            HStack { Text(name).font(.subheadline.weight(.bold)); Spacer(); Text(badge).font(.caption2.weight(.black)).foregroundStyle(themeAccent) }
                .padding(.horizontal, 14).frame(maxWidth: .infinity).frame(height: 50)
                .background(language == key ? themeAccent.opacity(0.12) : Color.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(language == key ? themeAccent.opacity(0.45) : Color.white.opacity(0.06)))
        }.buttonStyle(.plain)
    }

    private func aboutRow(_ name: String, _ value: String) -> some View {
        HStack { Text(name).font(.caption).foregroundStyle(.secondary); Spacer(); Text(value).font(.caption.weight(.bold)).multilineTextAlignment(.trailing) }
    }

    private func eliteHeader(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: ar ? .trailing : .leading, spacing: 1) {
                Text(title).font(.system(size: 20, weight: .black, design: .rounded))
                Text(subtitle.uppercased()).font(.system(size: 8, weight: .bold)).tracking(1.3).foregroundStyle(themeAccent)
            }
            Spacer()
            Image("RAFLILogo").resizable().interpolation(.high).scaledToFit().frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.frame(height: 50)
    }

    private var eliteNav: some View {
        HStack(spacing: 2) {
            ForEach(EliteTab.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) { tab = item }
                    impact()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon).font(.system(size: 16, weight: .semibold))
                        Text(t(item.ar, item.en)).font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(tab == item ? themeAccent : .secondary)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(tab == item ? themeAccent.opacity(0.095) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(.plain)
            }
        }
        .padding(6).background(.ultraThinMaterial).background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08)))
        .padding(.horizontal, 12).padding(.bottom, 8)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            EliteBackdrop(theme: theme, animated: motionEnabled).opacity(0.52)
            VStack(spacing: 22) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.06), lineWidth: 8).frame(width: 154, height: 154)
                    Circle().trim(from: 0, to: max(0.015, progress)).stroke(AngularGradient(colors: [themeAccent, .white, themeAccent], center: .center), style: StrokeStyle(lineWidth: 8, lineCap: .round)).frame(width: 154, height: 154).rotationEffect(.degrees(-90)).animation(.easeInOut(duration: 0.18), value: progress)
                    VStack(spacing: 2) { Text("\(Int(progress * 100))").font(.system(size: 36, weight: .black, design: .rounded).monospacedDigit()); Text("%").font(.caption.weight(.black)).foregroundStyle(themeAccent) }
                }
                Text("RAFLI ENGINE").font(.system(size: 12, weight: .black)).tracking(2.4).foregroundStyle(themeAccent)
                Text(status).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                HStack(spacing: 7) {
                    engineChip("H.264 HIGH")
                    engineChip("CABAC")
                    engineChip(sourceReport.is60 ? "TRUE 60" : "SOURCE FPS")
                }
            }.padding(.horizontal, 28)
        }.transition(.opacity)
    }

    private func engineChip(_ text: String) -> some View {
        Text(text).font(.system(size: 8, weight: .black)).tracking(0.8).padding(.horizontal, 9).padding(.vertical, 6).background(Color.white.opacity(0.055)).clipShape(Capsule()).overlay(Capsule().stroke(Color.white.opacity(0.07)))
    }

    private var themeAccent: Color {
        switch theme {
        case "midnight": return .blue
        case "titanium": return Color(white: 0.88)
        case "violet": return .purple
        case "ember": return .orange
        case "ocean": return .cyan
        default: return .mint
        }
    }

    private func authenticate() {
        guard code.trimmingCharacters(in: .whitespacesAndNewlines) == "1v" else { codeError = true; impact(.error); return }
        codeError = false; code = ""; impact(.success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { unlocked = true }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let dest = RAFLIStorage.shared.importURL(ext: "mov")
                try data.write(to: dest, options: .atomic)
                await MainActor.run { setSource(dest) }
            } catch { await MainActor.run { status = error.localizedDescription } }
        }
    }

    private func importFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
            let dest = RAFLIStorage.shared.importURL(ext: ext)
            try FileManager.default.copyItem(at: url, to: dest)
            setSource(dest)
        } catch { status = error.localizedDescription }
    }

    private func setSource(_ url: URL) {
        sourceURL = url; outputURL = nil; outputReport = VideoReport(); RAFLIStorage.shared.rememberSource(url); refreshLibrary(); analyzeSource(url); impact(.success)
    }

    private func analyzeSource(_ url: URL) {
        Task { do { let r = try await VideoAnalyzer.analyze(url); await MainActor.run { sourceReport = r; status = t("تم تحليل الفيديو", "Video analyzed") } } catch { await MainActor.run { status = error.localizedDescription } } }
    }

    private func analyzeOutput(_ url: URL) {
        Task { do { let r = try await VideoAnalyzer.analyze(url); await MainActor.run { outputReport = r } } catch {} }
    }

    private func process() {
        guard let sourceURL else { return }
        busy = true; progress = 0; status = t("جاري تجهيز أقوى نسخة…", "Preparing the strongest version…"); impact(.medium)
        Task {
            do {
                let temp = try await VideoProcessor.export(source: sourceURL, preset: preset, report: sourceReport) { value in
                    Task { @MainActor in progress = value }
                }
                let ext = temp.pathExtension.isEmpty ? "mp4" : temp.pathExtension
                let final = RAFLIStorage.shared.outputURL(ext: ext)
                try FileManager.default.copyItem(at: temp, to: final)
                let outReport = try await VideoAnalyzer.analyze(final)
                await MainActor.run {
                    outputURL = final; outputReport = outReport; RAFLIStorage.shared.rememberOutput(final); busy = false; progress = 1; status = t("النتيجة جاهزة", "Result ready"); refreshLibrary(); impact(.success)
                }
            } catch {
                await MainActor.run { busy = false; status = error.localizedDescription; impact(.error) }
            }
        }
    }

    private func save(_ url: URL) {
        Task { do { try await uploader.saveToPhotos(file: url); await MainActor.run { status = t("تم الحفظ في الصور", "Saved to Photos"); impact(.success) } } catch { await MainActor.run { status = error.localizedDescription; impact(.error) } } }
    }

    private func resetStudio() { sourceURL = nil; outputURL = nil; sourceReport = VideoReport(); outputReport = VideoReport(); status = t("اختر الفيديو الأصلي", "Choose the original video"); impact() }

    private func refreshLibrary() { libraryItems = RAFLIStorage.shared.allVideos() }

    private func impact(_ style: UINotificationFeedbackGenerator.FeedbackType? = nil) {
        guard hapticsEnabled else { return }
        if let style { UINotificationFeedbackGenerator().notificationOccurred(style) } else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { guard hapticsEnabled else { return }; UIImpactFeedbackGenerator(style: style).impactOccurred() }
    private func t(_ arText: String, _ enText: String) -> String { ar ? arText : enText }
}

private enum EliteTab: String, CaseIterable, Identifiable {
    case studio, videos, profile, settings
    var id: String { rawValue }
    var icon: String { switch self { case .studio: return "sparkles.rectangle.stack.fill"; case .videos: return "play.square.stack.fill"; case .profile: return "person.crop.circle.fill"; case .settings: return "slider.horizontal.3" } }
    var ar: String { switch self { case .studio: return "الاستوديو"; case .videos: return "الفيديوهات"; case .profile: return "حسابي"; case .settings: return "الإعدادات" } }
    var en: String { switch self { case .studio: return "Studio"; case .videos: return "Videos"; case .profile: return "Profile"; case .settings: return "Settings" } }
}

private struct EliteBackdrop: View {
    let theme: String
    let animated: Bool
    @State private var phase = false
    private var colors: (Color, Color) {
        switch theme {
        case "midnight": return (.blue, .indigo)
        case "titanium": return (Color.white, Color.gray)
        case "violet": return (.purple, .indigo)
        case "ember": return (.orange, .red)
        case "ocean": return (.cyan, .blue)
        default: return (.mint, .green)
        }
    }
    var body: some View {
        ZStack {
            Color(red: 0.007, green: 0.010, blue: 0.012).ignoresSafeArea()
            Circle().fill(colors.0.opacity(0.18)).frame(width: 390, height: 390).blur(radius: 105).offset(x: phase ? 170 : -130, y: phase ? -310 : -240)
            Circle().fill(colors.1.opacity(0.12)).frame(width: 330, height: 330).blur(radius: 120).offset(x: phase ? -170 : 120, y: phase ? 330 : 260)
            LinearGradient(colors: [.clear, .black.opacity(0.42)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        }.onAppear { if animated { withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { phase.toggle() } } }
    }
}

private struct ElitePrimaryStyle: ButtonStyle {
    let accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.black)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(LinearGradient(colors: [Color.white.opacity(0.94), accent], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: accent.opacity(configuration.isPressed ? 0.10 : 0.24), radius: 20, y: 9)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

private struct EliteSecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.bold)).foregroundStyle(.primary).frame(maxWidth: .infinity).frame(height: 46)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.045)).clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07))).scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct ElitePanel: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.padding(15).background(.ultraThinMaterial).background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.035), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.32), radius: 26, y: 14)
    }
}

private extension View { func elitePanel(radius: CGFloat = 24) -> some View { modifier(ElitePanel(radius: radius)) } }

private struct EliteThumbnail: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Color.white.opacity(0.035)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { ProgressView().tint(.white) }
        }.clipped().task { image = await thumbnail(url) }
    }
    private func thumbnail(_ url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url)); generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 900, height: 900)
        return await withCheckedContinuation { cont in DispatchQueue.global(qos: .userInitiated).async { let cg = try? generator.copyCGImage(at: CMTime(seconds: 0.15, preferredTimescale: 600), actualTime: nil); cont.resume(returning: cg.map(UIImage.init(cgImage:))) } }
    }
}

private struct EliteVideoItem: Identifiable { let id = UUID(); let url: URL }
private struct EliteShareItem: Identifiable { let id = UUID(); let url: URL }

private struct ElitePlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea(); VideoPlayer(player: AVPlayer(url: url)).ignoresSafeArea()
            VStack { HStack { Spacer(); Button { dismiss() } label: { Image(systemName: "xmark").font(.headline).foregroundStyle(.white).frame(width: 42, height: 42).background(.ultraThinMaterial).clipShape(Circle()) }.padding() }; Spacer() }
        }
    }
}

private struct EliteActivity: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
