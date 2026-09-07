import SwiftUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation
import AVKit

struct ContentView: View {
    @AppStorage("rafli_language") private var language = "ar"
    @State private var tab = 0
    @State private var showPicker = false
    @State private var sourceURL: URL?
    @State private var outputURL: URL?
    @State private var report = VideoReport()
    @State private var preset: RAFLIPreset = .maxQuality
    @State private var busy = false
    @State private var progress = 0.0
    @State private var status = ""
    @State private var shareURL: ShareItem?
    @State private var pulse = false
    @StateObject private var uploader = RAFLIUploadEngine()

    private var isArabic: Bool { language == "ar" }

    var body: some View {
        ZStack {
            premiumBackground
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
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first { loadVideo(url) }
        }
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
        .onAppear {
            status = text("اختر فيديو أصلي وخلّي ارفعلي يجهزه للنشر", "Choose an original video and let RAFLI prepare it")
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var premiumBackground: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.005, green: 0.075, blue: 0.055), Color(red: 0.0, green: 0.025, blue: 0.035)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(Color.mint.opacity(0.14)).frame(width: 320, height: 320).blur(radius: 90).offset(x: pulse ? 150 : 90, y: pulse ? -320 : -250)
            Circle().fill(Color.green.opacity(0.07)).frame(width: 260, height: 260).blur(radius: 100).offset(x: pulse ? -170 : -100, y: pulse ? 300 : 220)
        }
    }

    private var homePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header
                heroCard
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
                Text("100% FREE · NO WATERMARK · @ucorc").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.45)).padding(.top, 2)
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 28)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                Text(text("ارفعلي", "RAFLI")).font(.system(size: 30, weight: .black, design: .rounded))
                Text("Higher Quality. Always.").font(.caption).foregroundStyle(.mint.opacity(0.85))
            }
            Spacer()
            Text("@ucorc").font(.caption.weight(.bold)).foregroundStyle(.mint).padding(.horizontal, 11).padding(.vertical, 7).background(.ultraThinMaterial).clipShape(Capsule()).overlay(Capsule().stroke(Color.mint.opacity(0.20)))
        }
    }

    private var heroCard: some View {
        Button { showPicker = true } label: {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.mint.opacity(pulse ? 0.24 : 0.11)).frame(width: 116, height: 116).blur(radius: pulse ? 14 : 5)
                    Circle().fill(LinearGradient(colors: [Color.mint.opacity(0.85), Color.green.opacity(0.35)], startPoint: .top, endPoint: .bottom)).frame(width: 88, height: 88).overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                    Image(systemName: "arrow.up").font(.system(size: 35, weight: .black)).foregroundStyle(.white)
                }
                .scaleEffect(pulse ? 1.03 : 0.97)
                VStack(spacing: 5) {
                    Text(text("اختر الفيديو", "Select Video")).font(.title3.weight(.bold))
                    Text(text("اضغط لاختيار فيديو من ملفاتك", "Tap to choose a video from your files")).font(.footnote).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    chip("4K", icon: "4k.tv")
                    chip("60 FPS", icon: "waveform")
                    chip(text("مجاني", "FREE"), icon: "infinity")
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24)
        }
        .buttonStyle(.plain).glassCard(strong: true)
    }

    private func sourcePreview(url: URL) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
            HStack {
                Text(text("الفيديو الأصلي", "Original Video")).font(.headline.weight(.bold))
                Spacer()
                Label(text("تم التحليل", "Analyzed"), systemImage: "checkmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(.mint)
            }
            VideoThumbnailView(url: url).frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    Label("\(report.width)×\(report.height)", systemImage: "rectangle.inset.filled")
                    Label(String(format: "%.0f FPS", report.fps), systemImage: "speedometer")
                }
                .font(.caption.weight(.semibold)).padding(10).background(.black.opacity(0.58)).clipShape(Capsule()).padding(10)
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
            HStack { Text(text("وضع الجودة", "Quality Mode")).font(.headline.bold()); Spacer(); Image(systemName: "slider.horizontal.3").foregroundStyle(.mint) }
            Picker("Preset", selection: $preset) { ForEach(RAFLIPreset.allCases) { item in Text(displayName(item)).tag(item) } }.pickerStyle(.menu).tint(.mint)
            Text(presetDescription).font(.footnote).foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var encodeCard: some View {
        VStack(spacing: 13) {
            if busy {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.09), lineWidth: 10)
                    Circle().trim(from: 0, to: progress).stroke(Color.mint, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90)).animation(.easeInOut(duration: 0.25), value: progress)
                    Text("\(Int(progress * 100))%").font(.title2.bold().monospacedDigit())
                }.frame(width: 112, height: 112)
                Text(text("جاري تجهيز الفيديو…", "Preparing your video…")).font(.headline)
            }
            Text(status).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { processVideo() } label: {
                Label(busy ? text("جاري المعالجة", "Processing") : text("شغّل RAFLI ULTRA", "Run RAFLI ULTRA"), systemImage: busy ? "hourglass" : "bolt.fill")
            }.buttonStyle(RAFLIPrimaryButton()).disabled(busy)
        }
        .glassCard()
    }

    private func comparisonCard(original: URL, enhanced: URL) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
            HStack { Text(text("قبل / بعد", "Before / After")).font(.headline.bold()); Spacer(); Text(text("النتيجة", "RESULT")).font(.caption2.bold()).foregroundStyle(.mint) }
            HStack(spacing: 10) {
                videoMiniCard(title: text("الأصلي", "Original"), url: original, accent: .white)
                videoMiniCard(title: text("بعد التعديل", "Enhanced"), url: enhanced, accent: .mint)
            }
        }
        .glassCard(strong: true)
    }

    private func videoMiniCard(title: String, url: URL, accent: Color) -> some View {
        VStack(spacing: 8) {
            VideoThumbnailView(url: url).frame(height: 145).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(title).font(.caption.bold()).foregroundStyle(accent)
        }.frame(maxWidth: .infinity)
    }

    private func publishCard(url: URL) -> some View {
        VStack(spacing: 10) {
            HStack { Text(text("الفيديو جاهز", "Video Ready")).font(.headline.bold()); Spacer(); Image(systemName: "checkmark.seal.fill").foregroundStyle(.mint) }
            Button {
                Task { do { try await uploader.saveToPhotos(file: url) } catch { status = error.localizedDescription } }
            } label: { Label(text("حفظ في الصور", "Save to Photos"), systemImage: "square.and.arrow.down.fill") }.buttonStyle(RAFLIPrimaryButton())
            HStack(spacing: 10) {
                Button { shareURL = ShareItem(url: url) } label: { Label(text("مشاركة", "Share"), systemImage: "square.and.arrow.up") }.buttonStyle(RAFLISecondaryButton())
                Button {
                    sourceURL = nil; outputURL = nil; report = VideoReport(); status = text("اختر فيديو جديد", "Choose a new video"); showPicker = true
                } label: { Label(text("فيديو جديد", "New Video"), systemImage: "plus") }.buttonStyle(RAFLISecondaryButton())
            }
        }.glassCard()
    }

    private var videosPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 16) {
                pageTitle(text("فيديوهاتي", "My Videos"), subtitle: text("الأصلي والنسخة بعد التعديل", "Original and enhanced versions"))
                if sourceURL == nil && outputURL == nil { emptyVideos } else {
                    if let sourceURL { libraryCard(title: text("الفيديو الأصلي", "Original Video"), badge: text("أصلي", "ORIGINAL"), url: sourceURL, accent: .white) }
                    if let outputURL { libraryCard(title: text("الفيديو بعد التعديل", "Enhanced Video"), badge: text("محسن", "ENHANCED"), url: outputURL, accent: .mint) }
                }
            }.padding(16).padding(.bottom, 24)
        }
    }

    private var emptyVideos: some View {
        VStack(spacing: 14) {
            Image(systemName: "film.stack").font(.system(size: 42, weight: .light)).foregroundStyle(.mint)
            Text(text("ما عندك فيديوهات بعد", "No videos yet")).font(.headline)
            Text(text("اختر فيديو من الرئيسية وستظهر هنا النسخة الأصلية والنسخة الجاهزة.", "Choose a video on Home and both versions will appear here.")).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 42).glassCard()
    }

    private func libraryCard(title: String, badge: String, url: URL, accent: Color) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 11) {
            VideoThumbnailView(url: url).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            HStack {
                VStack(alignment: isArabic ? .trailing : .leading, spacing: 3) { Text(title).font(.headline.bold()); Text(badge).font(.caption2.bold()).foregroundStyle(accent) }
                Spacer()
                Button { shareURL = ShareItem(url: url) } label: { Image(systemName: "square.and.arrow.up").font(.headline).foregroundStyle(.mint).frame(width: 42, height: 42).background(.ultraThinMaterial).clipShape(Circle()) }
            }
        }.glassCard()
    }

    private var profilePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                pageTitle(text("الملف الشخصي", "Profile"), subtitle: "@ucorc")
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 72)).foregroundStyle(.mint)
                    Text("RAFLI").font(.title2.weight(.black))
                    Text("100% FREE").font(.caption.bold()).foregroundStyle(.mint)
                }.frame(maxWidth: .infinity).glassCard(strong: true)
                VStack(spacing: 10) {
                    HStack { Label(text("اللغة", "Language"), systemImage: "globe"); Spacer(); Picker("Language", selection: $language) { Text("العربية").tag("ar"); Text("English").tag("en") }.pickerStyle(.menu).tint(.mint) }
                    Divider().overlay(Color.white.opacity(0.08))
                    HStack { Label(text("المظهر", "Appearance"), systemImage: "moon.stars.fill"); Spacer(); Text(text("داكن زجاجي", "Dark Glass")).foregroundStyle(.secondary) }
                    Divider().overlay(Color.white.opacity(0.08))
                    HStack { Label(text("الإصدار", "Version"), systemImage: "info.circle.fill"); Spacer(); Text("5.1").foregroundStyle(.secondary) }
                }.glassCard()
            }.padding(16).padding(.bottom, 24)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            navButton(0, icon: "house.fill", title: text("الرئيسية", "Home"))
            navButton(1, icon: "folder.fill", title: text("فيديوهاتي", "My Videos"))
            navButton(2, icon: "person.fill", title: text("الملف", "Profile"))
        }
        .padding(.horizontal, 10).padding(.vertical, 8).background(.ultraThinMaterial).overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
    }

    private func navButton(_ index: Int, icon: String, title: String) -> some View {
        Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { tab = index } } label: {
            VStack(spacing: 4) { Image(systemName: icon); Text(title).font(.caption2.weight(.semibold)) }
                .foregroundStyle(tab == index ? Color.mint : Color.white.opacity(0.52)).frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(tab == index ? Color.mint.opacity(0.09) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func pageTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 4) { Text(title).font(.system(size: 28, weight: .black, design: .rounded)); Text(subtitle).font(.footnote).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
    }

    private func chip(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.caption2.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 7).background(Color.white.opacity(0.055)).clipShape(Capsule()).overlay(Capsule().stroke(Color.white.opacity(0.08)))
    }

    private func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.mint); Text(title).font(.caption2).foregroundStyle(.secondary); Text(value).font(.headline.monospacedDigit())
        }.frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading).padding(13).glassCard()
    }

    private var presetDescription: String {
        switch preset {
        case .preserve: return text("يحافظ على المصدر بدون إعادة ترميز.", "Keeps the source without re-encoding.")
        case .smart: return text("يضبط الجودة تلقائيًا حسب المصدر.", "Automatically adapts quality to the source.")
        case .tiktokSafe: return "1080p · 14 Mbps · H.264 High"
        case .highMotion: return "1080p · 22 Mbps · 1s GOP"
        case .maxQuality: return "1080p · 30 Mbps · High/CABAC · AAC 256k"
        case .compact: return "1080p · 8 Mbps"
        }
    }

    private func displayName(_ item: RAFLIPreset) -> String {
        switch item {
        case .preserve: return text("الحفاظ على الأصل", "Preserve Original")
        case .smart: return "RAFLI Smart"
        case .tiktokSafe: return "TikTok Safe 1080"
        case .highMotion: return text("حركة عالية", "High Motion")
        case .maxQuality: return "ULTRA MAX"
        case .compact: return text("حجم أقل", "Compact")
        }
    }

    private func text(_ ar: String, _ en: String) -> String { isArabic ? ar : en }

    private func loadVideo(_ url: URL) {
        Task { @MainActor in
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_SOURCE." + ext)
                try? FileManager.default.removeItem(at: tmp)
                try FileManager.default.copyItem(at: url, to: tmp)
                sourceURL = tmp
                outputURL = nil
                report = try await VideoAnalyzer.analyze(tmp)
                status = text("تم تحليل الفيديو ✅", "Video analyzed ✅")
                tab = 0
            } catch { status = error.localizedDescription }
        }
    }

    private func processVideo() {
        guard let sourceURL else { return }
        busy = true; progress = 0; status = text("جاري تجهيز الفيديو…", "Preparing video…")
        Task {
            do {
                let out = try await VideoProcessor.export(source: sourceURL, preset: preset, report: report) { p in Task { @MainActor in progress = p } }
                await MainActor.run { outputURL = out; busy = false; progress = 1; status = text("الفيديو جاهز ✅", "Video ready ✅") }
            } catch { await MainActor.run { busy = false; status = error.localizedDescription } }
        }
    }
}

struct ShareItem: Identifiable { let id = UUID(); let url: URL }

struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFill() } else { Rectangle().fill(Color.white.opacity(0.035)); ProgressView().tint(.mint) }
            Image(systemName: "play.circle.fill").font(.system(size: 44)).foregroundStyle(.white.opacity(0.9)).shadow(radius: 10)
        }
        .clipped()
        .task(id: url) { image = await thumbnail(url) }
    }
    private func thumbnail(_ url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 900, height: 900)
        return await withCheckedContinuation { cont in
            gen.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: 0.2, preferredTimescale: 600))]) { _, cg, _, _, _ in cont.resume(returning: cg.map(UIImage.init(cgImage:))) }
        }
    }
}

struct RAFLIPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14).background(LinearGradient(colors: [Color.mint.opacity(configuration.isPressed ? 0.62 : 0.95), Color.green.opacity(configuration.isPressed ? 0.40 : 0.72)], startPoint: .leading, endPoint: .trailing)).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).shadow(color: Color.mint.opacity(0.20), radius: 18, y: 7)
    }
}

struct RAFLISecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 13).background(.ultraThinMaterial.opacity(configuration.isPressed ? 0.6 : 0.95)).foregroundStyle(.mint).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mint.opacity(0.17))).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func glassCard(strong: Bool = false) -> some View {
        self.padding(16).frame(maxWidth: .infinity).background(.ultraThinMaterial.opacity(strong ? 0.82 : 0.58)).background(Color.white.opacity(strong ? 0.045 : 0.025)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(LinearGradient(colors: [Color.white.opacity(0.18), Color.mint.opacity(0.10), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).shadow(color: Color.black.opacity(0.22), radius: 18, y: 9)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
