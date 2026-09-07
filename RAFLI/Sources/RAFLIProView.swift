import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import AVFoundation

struct RAFLIProView: View {
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
    @State private var busy = false
    @State private var progress = 0.0
    @State private var status = "اختر فيديو"
    @State private var playerItem: PlayItem?
    @StateObject private var uploader = RAFLIUploadEngine()

    var body: some View {
        ZStack {
            background
            if unlocked { shell } else { login }
        }
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, .rightToLeft)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            importFile(url)
        }
        .onChange(of: photoItem) { item in if let item { importPhoto(item) } }
        .sheet(item: $playerItem) { item in
            VideoPlayer(player: AVPlayer(url: item.url)).ignoresSafeArea()
        }
        .onAppear { restoreLibrary() }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.0, green: 0.055, blue: 0.045), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(Color.mint.opacity(0.08)).frame(width: 300, height: 300).blur(radius: 100).offset(x: 170, y: -300)
            Circle().fill(Color.green.opacity(0.05)).frame(width: 260, height: 260).blur(radius: 110).offset(x: -160, y: 330)
        }
    }

    private var login: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("RAFLILogo").resizable().scaledToFit().frame(width: 92, height: 92).clipShape(RoundedRectangle(cornerRadius: 22))
            Text("RAFLI").font(.system(size: 31, weight: .bold, design: .rounded))

            VStack(spacing: 13) {
                HStack { Image(systemName: "lock.fill").foregroundStyle(.mint); Text("رمز الدخول").font(.headline); Spacer() }
                SecureField("اكتب الكود", text: $code)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 15).frame(height: 50)
                    .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(codeError ? Color.red : Color.mint.opacity(0.22)))
                    .onSubmit { unlock() }
                if codeError { Text("الكود غير صحيح").font(.caption.bold()).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .trailing) }
                Button("دخول") { unlock() }.buttonStyle(ProPrimary())
            }
            .padding(17).proCard()
            .padding(.horizontal, 22)
            Spacer()
        }
    }

    private var shell: some View {
        VStack(spacing: 0) {
            Group {
                if tab == 1 { libraryPage }
                else if tab == 2 { profilePage }
                else { homePage }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            navBar
        }
    }

    private var homePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                HStack {
                    Image("RAFLILogo").resizable().scaledToFit().frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("RAFLI").font(.title3.bold())
                    Spacer()
                    Text("ENGINE 1.3").font(.caption2.bold()).foregroundStyle(.mint).padding(.horizontal, 9).padding(.vertical, 5).background(Color.mint.opacity(0.11)).clipShape(Capsule())
                }
                .frame(height: 50)

                importCard

                if let sourceURL {
                    mediaCard(title: "الفيديو الأصلي", url: sourceURL, report: sourceReport, tag: "SOURCE")
                    engineCard
                }

                if let outputURL {
                    mediaCard(title: "RAFLI Output", url: outputURL, report: outputReport, tag: "VERIFIED OUTPUT")
                    proofCard
                    Button { Task { try? await uploader.saveToPhotos(file: outputURL) } } label: { Label("حفظ النسخة في الصور", systemImage: "square.and.arrow.down.fill") }.buttonStyle(ProPrimary())
                }
            }
            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 20)
        }
    }

    private var importCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.mint, .green.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 58, height: 58)
                Image(systemName: "plus").font(.system(size: 25, weight: .bold)).foregroundStyle(.black)
            }
            Text("اختر فيديو").font(.headline.bold())
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .videos) { sourceButton("الصور", "photo.fill", .pink) }.buttonStyle(.plain)
                Button { showFiles = true } label: { sourceButton("الملفات", "folder.fill", .mint) }.buttonStyle(.plain)
            }
        }
        .padding(15).proCard()
    }

    private func sourceButton(_ title: String, _ icon: String, _ color: Color) -> some View {
        Label(title, systemImage: icon).font(.subheadline.bold()).foregroundStyle(.primary).frame(maxWidth: .infinity).frame(height: 46).background(Color.white.opacity(0.055)).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.24)))
    }

    private func mediaCard(title: String, url: URL, report: VideoReport, tag: String) -> some View {
        VStack(spacing: 10) {
            HStack { VStack(alignment: .trailing, spacing: 2) { Text(title).font(.headline.bold()); Text(tag).font(.caption2.bold()).foregroundStyle(.mint) }; Spacer() }
            Button { playerItem = PlayItem(url: url) } label: {
                ZStack {
                    VideoThumb(url: url).frame(height: 176)
                    Circle().fill(.black.opacity(0.52)).frame(width: 48, height: 48)
                    Image(systemName: "play.fill").foregroundStyle(.white)
                }
            }.buttonStyle(.plain).clipShape(RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 7) {
                metric("\(report.width)×\(report.height)", "الدقة")
                metric(String(format: "%.0f", report.fps), "FPS")
                metric(String(format: "%.1fM", report.bitrateMbps), "Bitrate")
            }
        }
        .padding(13).proCard()
    }

    private func metric(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) { Text(value).font(.subheadline.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7); Text(title).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 9).background(Color.white.opacity(0.045)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var engineCard: some View {
        VStack(spacing: 11) {
            HStack { Text("RAFLI Native Engine").font(.headline.bold()); Spacer(); Text(sourceReport.is60 ? "TRUE 60 SOURCE" : "SOURCE FPS \(Int(sourceReport.fps.rounded()))").font(.caption2.bold()).foregroundStyle(sourceReport.is60 ? .green : .orange) }
            HStack(spacing: 7) {
                engineBadge("1080p", "rectangle.expand.vertical")
                engineBadge(sourceReport.is60 ? "60 FPS" : "FPS محفوظ", "waveform")
                engineBadge("H.264 High", "film.fill")
                engineBadge("40 Mbps MAX", "gauge.with.dots.needle.67percent")
            }
            Text("المعالجة هنا حقيقية: إعادة ترميز H.264 High + CABAC، تحويل فعلي إلى 1080p، وBitrate قوي. لا يتم ادعاء 60fps إذا المصدر ليس 60fps.")
                .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            if busy {
                ProgressView(value: progress).tint(.mint)
                Text("\(Int(progress * 100))%").font(.caption.bold().monospacedDigit())
            }
            Button { process() } label: { Label(busy ? "جاري المعالجة" : "ابدأ المعالجة الفعلية", systemImage: "bolt.fill") }.buttonStyle(ProPrimary()).disabled(busy)
            Text(status).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14).proCard()
    }

    private func engineBadge(_ text: String, _ icon: String) -> some View {
        VStack(spacing: 4) { Image(systemName: icon).font(.caption).foregroundStyle(.mint); Text(text).font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.7) }.frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.white.opacity(0.045)).clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private var proofCard: some View {
        VStack(spacing: 9) {
            HStack { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green); Text("Export Proof").font(.headline.bold()); Spacer() }
            comparison("الدقة", "\(sourceReport.width)×\(sourceReport.height)", "\(outputReport.width)×\(outputReport.height)")
            comparison("FPS", String(format: "%.2f", sourceReport.fps), String(format: "%.2f", outputReport.fps))
            comparison("Bitrate", String(format: "%.1f Mbps", sourceReport.bitrateMbps), String(format: "%.1f Mbps", outputReport.bitrateMbps))
            comparison("الحجم", String(format: "%.1f MB", sourceReport.fileSizeMB), String(format: "%.1f MB", outputReport.fileSizeMB))
            Text("هذه القيم مقروءة من ملف الإخراج نفسه بعد انتهاء الترميز، وليست أرقام واجهة.").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14).proCard()
    }

    private func comparison(_ title: String, _ before: String, _ after: String) -> some View {
        HStack { Text(title).font(.caption).foregroundStyle(.secondary); Spacer(); Text(before).font(.caption.monospacedDigit()).foregroundStyle(.secondary); Image(systemName: "arrow.left").font(.caption2).foregroundStyle(.mint); Text(after).font(.caption.bold().monospacedDigit()) }
    }

    private var libraryPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                HStack { VStack(alignment: .trailing) { Text("فيديوهاتي").font(.title2.bold()); Text("ملفات محفوظة داخل RAFLI").font(.caption).foregroundStyle(.secondary) }; Spacer() }
                if sourceURL == nil && outputURL == nil { Text("لا توجد فيديوهات محفوظة").foregroundStyle(.secondary).padding(40).frame(maxWidth: .infinity).proCard() }
                if let sourceURL { libraryRow("الأصلي", sourceURL, sourceReport) }
                if let outputURL { libraryRow("RAFLI Output", outputURL, outputReport) }
            }.padding(14)
        }
    }

    private func libraryRow(_ title: String, _ url: URL, _ report: VideoReport) -> some View {
        Button { playerItem = PlayItem(url: url) } label: {
            HStack(spacing: 12) {
                VideoThumb(url: url).frame(width: 105, height: 76).clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .trailing, spacing: 4) { Text(title).font(.subheadline.bold()); Text("\(report.width)×\(report.height) • \(Int(report.fps.rounded())) FPS").font(.caption2).foregroundStyle(.secondary); Text(url.lastPathComponent).font(.caption2).foregroundStyle(.mint).lineLimit(1) }
                Spacer(); Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(.mint)
            }.padding(11)
        }.buttonStyle(.plain).proCard()
    }

    private var profilePage: some View {
        VStack(spacing: 14) {
            HStack { Text("الملف").font(.title2.bold()); Spacer() }
            HStack(spacing: 12) { Image("RAFLILogo").resizable().scaledToFit().frame(width: 62, height: 62).clipShape(RoundedRectangle(cornerRadius: 15)); VStack(alignment: .trailing) { Text("RAFLI").font(.headline.bold()); Text("Native Engine 1.3").font(.caption).foregroundStyle(.mint) }; Spacer() }.padding(14).proCard()
            Button { if let u = URL(string: "https://t.me/ucorc") { UIApplication.shared.open(u) } } label: { HStack { Image(systemName: "paperplane.fill").foregroundStyle(.blue); Text("@ucorc").font(.headline); Spacer(); Image(systemName: "arrow.up.right") } }.buttonStyle(.plain).padding(14).proCard()
            Text("RAFLI لا يغيّر رقم FPS شكليًا. إذا المصدر 60fps سيحافظ على 60fps؛ إذا المصدر 30fps لن يدّعي أنها 60fps. TikTok قد يعيد ضغط الملف بعد الرفع.").font(.caption).foregroundStyle(.secondary).padding(14).proCard()
            Spacer()
        }.padding(14)
    }

    private var navBar: some View {
        HStack(spacing: 5) { nav(0,"الرئيسية","house.fill"); nav(1,"فيديوهاتي","folder.fill"); nav(2,"الملف","person.fill") }.padding(.horizontal, 9).padding(.vertical, 7).background(.ultraThinMaterial)
    }
    private func nav(_ i: Int, _ title: String, _ icon: String) -> some View {
        Button { withAnimation(.easeOut(duration: 0.16)) { tab = i } } label: { VStack(spacing: 3) { Image(systemName: icon).font(.system(size: 17, weight: .semibold)); Text(title).font(.caption2.bold()) }.foregroundStyle(tab == i ? .mint : .secondary).frame(maxWidth: .infinity).padding(.vertical, 8).background(tab == i ? Color.mint.opacity(0.11) : .clear).clipShape(RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain)
    }

    private func unlock() { let ok = code.trimmingCharacters(in: .whitespacesAndNewlines) == "1v"; codeError = !ok; if ok { unlocked = true } }

    private func importPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let dst = RAFLIStorage.shared.importURL(ext: "mov")
                try data.write(to: dst, options: .atomic)
                try await useSource(dst)
            } catch { await MainActor.run { status = error.localizedDescription } }
        }
    }

    private func importFile(_ url: URL) {
        Task {
            let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
                let dst = RAFLIStorage.shared.importURL(ext: ext)
                try FileManager.default.copyItem(at: url, to: dst)
                try await useSource(dst)
            } catch { await MainActor.run { status = error.localizedDescription } }
        }
    }

    private func useSource(_ url: URL) async throws {
        let r = try await VideoAnalyzer.analyze(url)
        await MainActor.run { sourceURL = url; sourceReport = r; outputURL = nil; outputReport = VideoReport(); RAFLIStorage.shared.rememberSource(url); status = "تم تحليل المصدر الحقيقي"; tab = 0 }
    }

    private func process() {
        guard let sourceURL else { return }
        busy = true; progress = 0; status = "جاري ترميز الفيديو فعليًا…"
        Task {
            do {
                let temp = try await VideoProcessor.export(source: sourceURL, preset: .maxQuality, report: sourceReport) { v in Task { @MainActor in progress = v } }
                let ext = temp.pathExtension.isEmpty ? "mp4" : temp.pathExtension
                let final = RAFLIStorage.shared.outputURL(ext: ext)
                try? FileManager.default.removeItem(at: final)
                try FileManager.default.copyItem(at: temp, to: final)
                let verified = try await VideoAnalyzer.analyze(final)
                await MainActor.run { outputURL = final; outputReport = verified; RAFLIStorage.shared.rememberOutput(final); busy = false; progress = 1; status = "اكتملت المعالجة وتم فحص ملف الإخراج ✅" }
            } catch { await MainActor.run { busy = false; status = error.localizedDescription } }
        }
    }

    private func restoreLibrary() {
        sourceURL = RAFLIStorage.shared.restoredSource(); outputURL = RAFLIStorage.shared.restoredOutput()
        Task {
            if let u = sourceURL, let r = try? await VideoAnalyzer.analyze(u) { await MainActor.run { sourceReport = r } }
            if let u = outputURL, let r = try? await VideoAnalyzer.analyze(u) { await MainActor.run { outputReport = r } }
        }
    }
}

struct PlayItem: Identifiable { let id = UUID(); let url: URL }

struct VideoThumb: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View { ZStack { Color.black.opacity(0.25); if let image { Image(uiImage: image).resizable().scaledToFill() } else { ProgressView().tint(.mint) } }.clipped().task { image = await make() } }
    private func make() async -> UIImage? { let a = AVURLAsset(url: url); let g = AVAssetImageGenerator(asset: a); g.appliesPreferredTrackTransform = true; g.maximumSize = CGSize(width: 800, height: 800); guard let cg = try? g.copyCGImage(at: CMTime(seconds: 0.2, preferredTimescale: 600), actualTime: nil) else { return nil }; return UIImage(cgImage: cg) }
}

struct ProPrimary: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.subheadline.bold()).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14).background(LinearGradient(colors: [Color.mint.opacity(configuration.isPressed ? 0.7 : 1), Color.green.opacity(0.78)], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 15)) }
}

extension View {
    func proCard() -> some View { self.background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 21).stroke(Color.mint.opacity(0.10))) }
}
