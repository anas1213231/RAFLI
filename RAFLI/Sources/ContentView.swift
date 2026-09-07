import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @AppStorage("telegramOpened") private var telegramOpened=false
    @AppStorage("accessGranted") private var accessGranted=false
    @State private var showPicker=false
    @State private var fileURL:URL?
    @State private var report=VideoReport()
    @State private var preset:RAFLIPreset = .maxQuality
    @State private var busy=false
    @State private var progress=0.0
    @State private var status="اختر الفيديو الأصلي، وليس نسخة محمّلة من TikTok."
    @State private var outputURL:URL?
    @State private var share=false
    @StateObject private var uploader=RAFLIUploadEngine()
    @State private var showDirectSettings=false

    var body: some View {
        ZStack {
            LinearGradient(colors:[.black,Color(red:0,green:0.09,blue:0.065),Color(red:0,green:0.03,blue:0.04)],startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea()
            Circle().fill(Color.mint.opacity(.10)).frame(width:320).blur(radius:80).offset(x:150,y:-300)
            ScrollView { VStack(spacing:14) {
                HStack { VStack(alignment:.leading,spacing:2){Text("RAFLI").font(.title.bold());Text("ULTRA ENGINE V5").font(.caption2.bold()).foregroundStyle(.mint)}; Spacer(); Text("@ucorc").font(.caption.bold()).foregroundStyle(.mint).padding(.horizontal,10).padding(.vertical,6).background(Color.mint.opacity(.08)).clipShape(Capsule()) }.padding(.top,6)
                hero
                if fileURL != nil { reportCard; presetCard; controls }
                if outputURL != nil { publishCard }
                Text("100% FREE · Native iOS · @ucorc").font(.caption2).foregroundStyle(.secondary).padding(.vertical,8)
            }.padding() }
            if !accessGranted { gate }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented:$showPicker,allowedContentTypes:[.movie],allowsMultipleSelection:false){ result in if case let .success(urls)=result,let u=urls.first { load(u) } }
        .sheet(isPresented:$share){ if let u=outputURL { ShareSheet(items:[u]) } }
    }

    private var hero: some View { VStack(alignment:.trailing,spacing:11){ Text("NATIVE VIDEO PIPELINE").font(.caption.bold()).foregroundStyle(.mint); Text("ترميز قوي فعليًا على الآيفون").font(.system(size:29,weight:.heavy)); Text("H.264 High/CABAC • 1080p • حتى 30 Mbps • Scale/Crop حقيقي • AAC 256k • Fast Start").font(.footnote).foregroundStyle(.secondary); Button("✦ اختر الفيديو الأصلي"){showPicker=true}.buttonStyle(RAFLIButton()) }.rafliCard() }

    private var reportCard: some View { VStack(spacing:12){ HStack{stat("RESOLUTION","\(report.width)×\(report.height)");stat("FPS",String(format:"%.2f",report.fps))}; HStack{stat("CODEC",report.codec.uppercased());stat("BITRATE",String(format:"%.2f Mbps",report.bitrateMbps))}; HStack{stat("AUDIO",report.hasAudio ? "YES":"NO");stat("SCORE","\(report.score)/100")}; Text(report.is1080 && report.is60 ? "🔥 مصدر 1080p60 قوي — استخدم ULTRA MAX" : "⚠️ لا يمكن للترميز إعادة تفاصيل غير موجودة في المصدر").font(.footnote.bold()).foregroundStyle(report.is1080 && report.is60 ? Color.mint:Color.orange) }.rafliCard() }

    private var presetCard: some View { VStack(alignment:.trailing,spacing:9){ Text("RAFLI PRESET").font(.caption.bold()).foregroundStyle(.mint); Picker("Preset",selection:$preset){ForEach(RAFLIPreset.allCases){Text($0.rawValue).tag($0)}}.pickerStyle(.menu).tint(.mint); Text(presetText).font(.footnote).foregroundStyle(.secondary) }.rafliCard() }
    private var presetText:String { switch preset { case .preserve:return "يحافظ على المصدر بدون إعادة ترميز."; case .smart:return "يضبط bitrate تلقائيًا حتى 22 Mbps."; case .tiktokSafe:return "1080p · 14 Mbps · H.264 High."; case .highMotion:return "1080p · 22 Mbps · Keyframe كل ثانية."; case .maxQuality:return "1080p · 30 Mbps · High/CABAC · AAC 256k."; case .compact:return "1080p · 8 Mbps لحجم أقل." } }

    private var controls: some View { VStack(spacing:10){ Text(status).font(.footnote).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.trailing); if busy {ProgressView(value:progress).tint(.mint);Text("\(Int(progress*100))%").font(.caption.monospacedDigit()).foregroundStyle(.mint)}; Button(busy ? "جاري الترميز…":"✦ شغّل RAFLI ULTRA ENCODE"){process()}.buttonStyle(RAFLIButton()).disabled(busy); if outputURL != nil {Button("مشاركة الملف الجاهز"){share=true}.buttonStyle(RAFLISecondaryButton())} }.rafliCard() }

    private var publishCard: some View { VStack(alignment:.trailing,spacing:11){ HStack{Text("RAFLI PUBLISH GUARD").font(.caption.bold()).foregroundStyle(.mint);Spacer();Text("V5").font(.caption.bold()).foregroundStyle(.mint)}; Text(uploader.status).font(.footnote).foregroundStyle(.secondary); if uploader.uploadProgress>0 && uploader.uploadProgress<1 {ProgressView(value:uploader.uploadProgress).tint(.mint)}
        Button("① حفظ في الصور بجودة RAFLI"){guard let out=outputURL else{return};Task{do{try await uploader.saveToPhotos(file:out)}catch{uploader.status="خطأ: \(error.localizedDescription)"}}}.buttonStyle(RAFLIButton())
        Button("② حفظ ثم فتح TikTok"){guard let out=outputURL else{return};Task{do{try await uploader.saveToPhotos(file:out);await uploader.openTikTok()}catch{uploader.status="خطأ: \(error.localizedDescription)"}}}.buttonStyle(RAFLISecondaryButton())
        Divider().overlay(Color.mint.opacity(.15)); DisclosureGroup("الإعداد الرسمي الاختياري",isExpanded:$showDirectSettings){ VStack(spacing:9){TextField("https://your-backend.example",text:$uploader.backendURL).textInputAutocapitalization(.never).keyboardType(.URL).padding(10).background(.white.opacity(.05)).clipShape(RoundedRectangle(cornerRadius:12)); Button("ربط TikTok رسميًا"){Task{do{try await uploader.startTikTokLink()}catch{uploader.status="خطأ: \(error.localizedDescription)"}}}.buttonStyle(RAFLISecondaryButton()); Button("فحص الربط"){Task{do{try await uploader.checkLink()}catch{uploader.status="خطأ: \(error.localizedDescription)"}}}.buttonStyle(RAFLISecondaryButton()); if uploader.linked,let out=outputURL {Button("رفع Draft عبر TikTok API"){Task{do{_ = try await uploader.uploadDraft(file:out)}catch{uploader.status="خطأ: \(error.localizedDescription)"}}}.buttonStyle(RAFLIButton())}; if !uploader.lastPublishID.isEmpty {Text("PUBLISH ID: \(uploader.lastPublishID)").font(.caption2.monospaced()).foregroundStyle(.secondary);Button("فحص حالة TikTok"){Task{do{try await uploader.checkPublishStatus()}catch{uploader.status="خطأ: \(error.localizedDescription)"}}}.buttonStyle(RAFLISecondaryButton())} }.padding(.top,8) }
    }.rafliCard() }

    private var gate: some View { ZStack{Color.black.opacity(.96).ignoresSafeArea();VStack(spacing:16){Text("RAFLI").font(.largeTitle.bold());Text("FREE ACCESS · @ucorc").font(.caption.bold()).foregroundStyle(.mint);Text("افتح قناة الحقوق مرة واحدة ثم ارجع واضغط دخول.").foregroundStyle(.secondary).multilineTextAlignment(.center);Button("فتح Telegram @ucorc"){telegramOpened=true;if let u=URL(string:"https://t.me/ucorc"){UIApplication.shared.open(u)}}.buttonStyle(RAFLIButton());Button("دخول RAFLI"){if telegramOpened{accessGranted=true}}.buttonStyle(RAFLISecondaryButton()).disabled(!telegramOpened)}.padding(28)} }

    private func stat(_ title:String,_ value:String)->some View { VStack(alignment:.trailing){Text(title).font(.caption2).foregroundStyle(.secondary);Text(value).font(.headline.monospacedDigit())}.frame(maxWidth:.infinity,alignment:.trailing).padding(10).background(.white.opacity(.035)).clipShape(RoundedRectangle(cornerRadius:12)) }
    private func load(_ url:URL){ Task{@MainActor in let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};do{let tmp=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+"_SOURCE.mp4");try? FileManager.default.removeItem(at:tmp);try FileManager.default.copyItem(at:url,to:tmp);fileURL=tmp;report=try await VideoAnalyzer.analyze(tmp);status="تم تحليل المصدر الحقيقي ✅";outputURL=nil}catch{status="خطأ: \(error.localizedDescription)"}} }
    private func process(){guard let source=fileURL else{return};busy=true;progress=0;status="RAFLI يعمل…";Task{do{let out=try await VideoProcessor.export(source:source,preset:preset,report:report){p in Task{@MainActor in progress=p}};await MainActor.run{outputURL=out;busy=false;progress=1;status="تم تجهيز RAFLI ULTRA READY ✅"}}catch{await MainActor.run{busy=false;status="خطأ: \(error.localizedDescription)"}}}} 
}

struct RAFLIButton:ButtonStyle{func makeBody(configuration:Configuration)->some View{configuration.label.font(.headline.bold()).frame(maxWidth:.infinity).padding(.vertical,14).background(Color.mint.opacity(configuration.isPressed ? 0.55:0.85)).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius:15))}}
struct RAFLISecondaryButton:ButtonStyle{func makeBody(configuration:Configuration)->some View{configuration.label.font(.subheadline.bold()).frame(maxWidth:.infinity).padding(.vertical,13).background(.white.opacity(configuration.isPressed ? 0.04:0.08)).foregroundStyle(.mint).overlay(RoundedRectangle(cornerRadius:15).stroke(Color.mint.opacity(.22))).clipShape(RoundedRectangle(cornerRadius:15))}}
extension View{func rafliCard()->some View{self.padding(16).frame(maxWidth:.infinity).background(.ultraThinMaterial.opacity(0.55)).overlay(RoundedRectangle(cornerRadius:22).stroke(Color.mint.opacity(.12))).clipShape(RoundedRectangle(cornerRadius:22))}}
struct ShareSheet:UIViewControllerRepresentable{let items:[Any];func makeUIViewController(context:Context)->UIActivityViewController{UIActivityViewController(activityItems:items,applicationActivities:nil)};func updateUIViewController(_ uiViewController:UIActivityViewController,context:Context){}}
