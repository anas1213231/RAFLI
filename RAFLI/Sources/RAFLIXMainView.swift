import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import AVFoundation
import UIKit

struct RAFLIXMainView: View {
    @State private var unlocked = false
    @State private var code = ""
    @State private var loginError = false
    @State private var tab = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var sourceURL: URL?
    @State private var outputURL: URL?
    @State private var sourceReport = VideoReport()
    @State private var outputReport = VideoReport()
    @State private var busy = false
    @State private var progress = 0.0
    @State private var status = "اختر فيديو للبدء"
    @State private var player: RAFLIXPlayItem?
    @State private var share: RAFLIXShareItem?
    @State private var reveal = false
    @State private var selectionPulse = false
    @StateObject private var uploader = RAFLIUploadEngine()

    var body: some View {
        ZStack {
            RAFLIXBackdrop()
            if unlocked { appShell } else { loginView }
        }
        .preferredColorScheme(.dark)
        .environment(\.layoutDirection, .rightToLeft)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            importFile(url)
        }
        .onChange(of: photoItem) { item in if let item { importPhoto(item) } }
        .fullScreenCover(item: $player) { item in
            ZStack {
                Color.black.ignoresSafeArea()
                VideoPlayer(player: AVPlayer(url: item.url)).ignoresSafeArea()
                VStack { HStack { Spacer(); Button { player = nil } label: { Image(systemName: "xmark").font(.headline).foregroundStyle(.white).frame(width: 42,height:42).background(.ultraThinMaterial).clipShape(Circle()) }.padding() }; Spacer() }
            }
        }
        .sheet(item: $share) { item in RAFLIXActivityView(items: [item.url]) }
        .onAppear {
            restoreLastFiles()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82).delay(0.08)) { reveal = true }
            withAnimation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true)) { selectionPulse = true }
        }
    }

    private var loginView: some View {
        VStack(spacing: 0) {
            Spacer()
            RAFLIXLogoHalo(size: 104)
                .scaleEffect(reveal ? 1 : 0.76)
                .opacity(reveal ? 1 : 0)
            Text("RAFLI")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(1.6)
                .padding(.top, 26)
            Text("X")
                .font(.caption.bold())
                .foregroundStyle(.mint)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.mint.opacity(0.11)).clipShape(Capsule())
                .padding(.top, 7)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("الوصول الخاص").font(.headline)
                        Text("أدخل رمز RAFLI").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "lock.shield.fill").foregroundStyle(.mint).font(.title3)
                }
                SecureField("رمز الدخول", text: $code)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 16).frame(height: 52)
                    .background(Color.white.opacity(0.055))
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(loginError ? Color.red.opacity(0.7) : Color.white.opacity(0.09)))
                    .onSubmit(authenticate)
                if loginError { Text("الرمز غير صحيح").font(.caption.bold()).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .trailing) }
                Button(action: authenticate) {
                    HStack { Text("دخول"); Spacer(); Image(systemName: "arrow.left") }
                }.buttonStyle(RAFLIXPrimaryButtonStyle())
            }
            .rafliXGlass(28)
            .padding(.horizontal, 22)
            .padding(.top, 32)
            .offset(y: reveal ? 0 : 28)
            .opacity(reveal ? 1 : 0)
            Spacer()
            Text("@ucorc").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(.bottom, 18)
        }
    }

    private var appShell: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 1: libraryView
                case 2: profileView
                default: homeView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            floatingNav
        }
    }

    private var homeView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                topBar
                hero
                if sourceURL == nil { pickerStage }
                if let url = sourceURL { sourceStage(url) }
                if busy { processingStage }
                if let url = outputURL, !busy { resultStage(url) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 9) {
                Image("RAFLILogo").resizable().scaledToFit().frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text("RAFLI").font(.system(size: 18, weight: .bold, design: .rounded)).tracking(1)
                    Text("NATIVE ENGINE").font(.system(size: 8, weight: .bold)).foregroundStyle(.mint.opacity(0.85)).tracking(1.4)
                }
            }
            Spacer()
            Text("X")
                .font(.caption.bold()).foregroundStyle(.black)
                .frame(width: 30,height:30)
                .background(.mint).clipShape(Circle())
                .shadow(color: .mint.opacity(0.30), radius: 14)
        }
        .frame(height: 48)
    }

    private var hero: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("ارفع بأقوى نسخة ممكنة")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("تحليل حقيقي • معالجة محلية • إثبات للملف الناتج")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.top, 4)
    }

    private var pickerStage: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.mint.opacity(selectionPulse ? 0.18 : 0.07)).frame(width: 120,height:120).blur(radius: 24)
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).frame(width: 94,height:94)
                Circle().fill(LinearGradient(colors:[.white.opacity(0.14),.mint.opacity(0.18)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:76,height:76)
                Image(systemName: "arrow.up.doc.fill").font(.system(size: 28, weight: .semibold)).foregroundStyle(.mint)
            }
            Text("اختر الفيديو الأصلي").font(.title3.bold())
            Text("سنقرأ الدقة والفريمات والبتريت من الملف نفسه").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .videos) { actionPill("الصور", "photo.fill") }.buttonStyle(.plain)
                Button { showFiles = true } label: { actionPill("الملفات", "folder.fill") }.buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .rafliXGlass(30)
    }

    private func actionPill(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.bold()).foregroundStyle(.primary)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
    }

    private func sourceStage(_ url: URL) -> some View {
        VStack(spacing: 14) {
            Button { player = RAFLIXPlayItem(url: url) } label: {
                ZStack {
                    RAFLIThumbnail(url: url).frame(height: 220)
                    LinearGradient(colors:[.clear,.black.opacity(0.50)],startPoint:.center,endPoint:.bottom)
                    VStack { Spacer(); HStack { Label("تشغيل", systemImage:"play.fill").font(.caption.bold()).foregroundStyle(.white); Spacer(); Text("SOURCE").font(.caption2.bold()).foregroundStyle(.mint) }.padding(14) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }.buttonStyle(.plain)

            HStack(spacing: 8) {
                metricBox("FPS", String(format:"%.0f", sourceReport.fps))
                metricBox("RES", "\(sourceReport.width)×\(sourceReport.height)")
                metricBox("BITRATE", String(format:"%.1fM", sourceReport.bitrateMbps))
            }

            Button { process() } label: {
                HStack { Image(systemName:"bolt.fill"); Text("ابدأ RAFLI Engine"); Spacer(); Image(systemName:"chevron.left") }
            }.buttonStyle(RAFLIXPrimaryButtonStyle())
        }
    }

    private func metricBox(_ title:String,_ value:String)->some View {
        VStack(spacing:4) {
            Text(value).font(.system(size:14,weight:.bold,design:.rounded)).lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.system(size:8,weight:.bold)).foregroundStyle(.secondary).tracking(0.9)
        }
        .frame(maxWidth:.infinity).frame(height:58)
        .background(Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius:16))
        .overlay(RoundedRectangle(cornerRadius:16).stroke(Color.white.opacity(0.07)))
    }

    private var processingStage: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 7).frame(width:126,height:126)
                Circle().trim(from:0,to:max(0.02,progress)).stroke(AngularGradient(colors:[.mint,.cyan,.mint],center:.center),style:StrokeStyle(lineWidth:7,lineCap:.round)).frame(width:126,height:126).rotationEffect(.degrees(-90)).animation(.easeInOut(duration:0.2), value: progress)
                VStack(spacing:1) {
                    Text("\(Int(progress*100))").font(.system(size:29,weight:.bold,design:.rounded).monospacedDigit())
                    Text("%").font(.caption.bold()).foregroundStyle(.mint)
                }
            }
            Text("RAFLI ENGINE").font(.caption.bold()).foregroundStyle(.mint).tracking(1.5)
            Text(status).font(.caption).foregroundStyle(.secondary)
            HStack(spacing:6) { processChip("H.264 HIGH"); processChip("CABAC"); processChip(sourceReport.is60 ? "TRUE 60" : "SOURCE FPS") }
        }
        .frame(maxWidth:.infinity).padding(.vertical,28).rafliXGlass(28)
        .transition(.scale(scale:0.96).combined(with:.opacity))
    }

    private func processChip(_ text:String)->some View {
        Text(text).font(.system(size:8,weight:.bold)).foregroundStyle(.secondary).padding(.horizontal,9).padding(.vertical,6).background(Color.white.opacity(0.045)).clipShape(Capsule())
    }

    private func resultStage(_ url: URL) -> some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment:.trailing,spacing:2) { Text("النسخة الجاهزة").font(.headline.bold()); Text("تم فحص الملف الناتج فعليًا").font(.caption2).foregroundStyle(.secondary) }
                Spacer()
                Image(systemName:"checkmark.seal.fill").font(.title2).foregroundStyle(.mint)
            }
            Button { player = RAFLIXPlayItem(url:url) } label: {
                RAFLIThumbnail(url:url).frame(height:210).clipShape(RoundedRectangle(cornerRadius:22,style:.continuous))
            }.buttonStyle(.plain)
            HStack(spacing:8) {
                metricBox("FPS", String(format:"%.0f",outputReport.fps))
                metricBox("RES", "\(outputReport.width)×\(outputReport.height)")
                metricBox("BITRATE", String(format:"%.1fM",outputReport.bitrateMbps))
            }
            VStack(spacing:7) {
                proofRow("FPS", String(format:"%.0f",sourceReport.fps), String(format:"%.0f",outputReport.fps))
                proofRow("الدقة", "\(sourceReport.width)×\(sourceReport.height)", "\(outputReport.width)×\(outputReport.height)")
                proofRow("Bitrate", String(format:"%.1fM",sourceReport.bitrateMbps), String(format:"%.1fM",outputReport.bitrateMbps))
            }
            .padding(12).background(Color.black.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius:18))
            HStack(spacing:9) {
                Button { save(url) } label: { Label("حفظ",systemImage:"square.and.arrow.down") }.buttonStyle(RAFLIXSecondaryButtonStyle())
                Button { share = RAFLIXShareItem(url:url) } label: { Label("مشاركة",systemImage:"square.and.arrow.up") }.buttonStyle(RAFLIXSecondaryButtonStyle())
                Button { reset() } label: { Image(systemName:"plus") }.buttonStyle(RAFLIXSecondaryButtonStyle())
            }
        }
        .rafliXGlass(28)
        .transition(.move(edge:.bottom).combined(with:.opacity))
    }

    private func proofRow(_ name:String,_ before:String,_ after:String)->some View {
        HStack { Text(name).font(.caption).foregroundStyle(.secondary); Spacer(); Text(before).font(.caption2.monospacedDigit()).foregroundStyle(.secondary); Image(systemName:"arrow.left").font(.caption2).foregroundStyle(.mint); Text(after).font(.caption.bold().monospacedDigit()) }
    }

    private var libraryView: some View {
        ScrollView(showsIndicators:false) {
            VStack(spacing:14) {
                sectionTitle("فيديوهاتي", "آخر ملفات محفوظة داخل RAFLI")
                if sourceURL == nil && outputURL == nil { emptyLibrary }
                if let sourceURL { libraryItem("الفيديو الأصلي", sourceURL, sourceReport) }
                if let outputURL { libraryItem("RAFLI Output", outputURL, outputReport) }
            }.padding(16).padding(.bottom,26)
        }
    }

    private var emptyLibrary: some View {
        VStack(spacing:12) { Image(systemName:"film.stack").font(.system(size:34)).foregroundStyle(.mint); Text("لا توجد ملفات محفوظة").font(.headline); Text("أضف فيديو من الرئيسية").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth:.infinity).padding(.vertical,50).rafliXGlass(28)
    }

    private func libraryItem(_ title:String,_ url:URL,_ report:VideoReport)->some View {
        Button { player = RAFLIXPlayItem(url:url) } label: {
            HStack(spacing:12) {
                RAFLIThumbnail(url:url).frame(width:104,height:76).clipShape(RoundedRectangle(cornerRadius:16))
                VStack(alignment:.trailing,spacing:5) { Text(title).font(.subheadline.bold()); Text("\(report.width)×\(report.height) • \(Int(report.fps.rounded())) FPS").font(.caption2).foregroundStyle(.secondary); Text(url.lastPathComponent).font(.caption2).foregroundStyle(.mint).lineLimit(1) }
                Spacer(); Image(systemName:"play.circle.fill").font(.title2).foregroundStyle(.mint)
            }
        }.buttonStyle(.plain).rafliXGlass(22)
    }

    private var profileView: some View {
        ScrollView(showsIndicators:false) {
            VStack(spacing:16) {
                sectionTitle("RAFLI X", "Native quality engine")
                VStack(spacing:16) {
                    RAFLIXLogoHalo(size:84)
                    Text("@ucorc").font(.headline)
                    Text("لا نغيّر أرقام الجودة شكليًا. القيم المعروضة تُقرأ من الملف نفسه قبل وبعد المعالجة.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth:.infinity).padding(.vertical,24).rafliXGlass(28)
                Button { code=""; withAnimation { unlocked=false } } label: { Label("قفل التطبيق",systemImage:"lock.fill").frame(maxWidth:.infinity) }.buttonStyle(RAFLIXSecondaryButtonStyle())
            }.padding(16)
        }
    }

    private func sectionTitle(_ title:String,_ subtitle:String)->some View {
        HStack { VStack(alignment:.trailing,spacing:3) { Text(title).font(.system(size:27,weight:.bold,design:.rounded)); Text(subtitle).font(.caption).foregroundStyle(.secondary) }; Spacer() }
    }

    private var floatingNav: some View {
        HStack(spacing:8) {
            navButton(0,"الرئيسية","house.fill")
            navButton(1,"فيديوهاتي","rectangle.stack.fill")
            navButton(2,"الملف","person.fill")
        }
        .padding(7)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius:25,style:.continuous))
        .overlay(RoundedRectangle(cornerRadius:25).stroke(Color.white.opacity(0.08)))
        .shadow(color:.black.opacity(0.35),radius:20,y:8)
        .padding(.horizontal,16).padding(.bottom,6)
    }

    private func navButton(_ index:Int,_ title:String,_ icon:String)->some View {
        Button { withAnimation(.spring(response:0.34,dampingFraction:0.82)){tab=index} } label: {
            HStack(spacing:6) { Image(systemName:icon); if tab == index { Text(title).font(.caption.bold()).transition(.opacity.combined(with:.scale(scale:0.9))) } }
                .foregroundStyle(tab == index ? Color.black : Color.secondary)
                .frame(maxWidth:.infinity).frame(height:43)
                .background(tab == index ? Color.mint : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius:18,style:.continuous))
        }.buttonStyle(.plain)
    }

    private func authenticate() {
        if code.trimmingCharacters(in:.whitespacesAndNewlines).lowercased() == "1v" {
            loginError=false; code=""; withAnimation(.spring(response:0.5,dampingFraction:0.84)){unlocked=true}
        } else { loginError=true }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { return }
                let dest = RAFLIStorage.shared.importURL(ext:"mov")
                try data.write(to:dest,options:.atomic)
                RAFLIStorage.shared.rememberSource(dest)
                try await analyze(dest)
            } catch { await MainActor.run { status=error.localizedDescription } }
        }
    }

    private func importFile(_ source: URL) {
        Task {
            let scoped = source.startAccessingSecurityScopedResource(); defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            do {
                let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
                let dest = RAFLIStorage.shared.importURL(ext:ext)
                try FileManager.default.copyItem(at:source,to:dest)
                RAFLIStorage.shared.rememberSource(dest)
                try await analyze(dest)
            } catch { await MainActor.run { status=error.localizedDescription } }
        }
    }

    private func analyze(_ url: URL) async throws {
        let report = try await VideoAnalyzer.analyze(url)
        await MainActor.run { sourceURL=url; sourceReport=report; outputURL=nil; outputReport=VideoReport(); progress=0; busy=false; status="تم تحليل الفيديو"; tab=0 }
    }

    private func process() {
        guard let sourceURL else { return }
        withAnimation { busy=true; progress=0; outputURL=nil; status="جاري بناء النسخة…" }
        Task {
            do {
                let temp = try await VideoProcessor.export(source:sourceURL,preset:.maxQuality,report:sourceReport) { value in Task { @MainActor in progress=value } }
                let ext = temp.pathExtension.isEmpty ? "mp4" : temp.pathExtension
                let dest = RAFLIStorage.shared.outputURL(ext:ext)
                try? FileManager.default.removeItem(at:dest)
                try FileManager.default.copyItem(at:temp,to:dest)
                RAFLIStorage.shared.rememberOutput(dest)
                let verified = try await VideoAnalyzer.analyze(dest)
                await MainActor.run { outputURL=dest; outputReport=verified; progress=1; busy=false; status="تمت المعالجة والتحقق" }
            } catch { await MainActor.run { busy=false; status=error.localizedDescription } }
        }
    }

    private func save(_ url: URL) { Task { do { try await uploader.saveToPhotos(file:url); await MainActor.run { status="تم الحفظ في الصور ✅" } } catch { await MainActor.run { status=error.localizedDescription } } } }

    private func restoreLastFiles() {
        if let source=RAFLIStorage.shared.restoredSource() { sourceURL=source; Task { if let r=try? await VideoAnalyzer.analyze(source) { await MainActor.run { sourceReport=r } } } }
        if let output=RAFLIStorage.shared.restoredOutput() { outputURL=output; Task { if let r=try? await VideoAnalyzer.analyze(output) { await MainActor.run { outputReport=r } } } }
    }

    private func reset() { sourceURL=nil; outputURL=nil; sourceReport=VideoReport(); outputReport=VideoReport(); progress=0; busy=false; photoItem=nil; status="اختر فيديو للبدء" }
}

struct RAFLIXPlayItem: Identifiable { let id = UUID(); let url: URL }
struct RAFLIXShareItem: Identifiable { let id = UUID(); let url: URL }

struct RAFLIXActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems:items,applicationActivities:nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct RAFLIXSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold()).foregroundStyle(.mint)
            .frame(maxWidth:.infinity).frame(height:46)
            .background(Color.white.opacity(configuration.isPressed ? 0.09 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius:15,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:15).stroke(Color.white.opacity(0.08)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response:0.25,dampingFraction:0.75),value:configuration.isPressed)
    }
}
