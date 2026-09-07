import Foundation
import UIKit
import Photos

enum RAFLIUploadError: LocalizedError {
    case invalidBackend, invalidResponse, notLinked, photosDenied
    case server(String)
    var errorDescription: String? {
        switch self {
        case .invalidBackend: return "رابط الخادم غير صحيح. يجب أن يبدأ بـ https://"
        case .invalidResponse: return "رد الخادم غير مفهوم."
        case .notLinked: return "TikTok غير مربوط بعد."
        case .server(let s): return s
        case .photosDenied: return "لم يتم السماح بحفظ الفيديو في الصور."
        }
    }
}

struct LinkStartResponse: Decodable { let link_id:String; let auth_url:String }
struct LinkStatusResponse: Decodable { let linked:Bool; let username:String? }
struct UploadDraftResponse: Decodable { let ok:Bool?; let publish_id:String?; let message:String? }
struct PublishStatusResponse: Decodable { let ok:Bool?; let status:String?; let fail_reason:String?; let uploaded_bytes:Int64?; let post_ids:[String]?; let message:String? }

@MainActor
final class RAFLIUploadEngine: ObservableObject {
    @Published var backendURL = UserDefaults.standard.string(forKey:"rafli_backend_url") ?? ""
    @Published var linkID = UserDefaults.standard.string(forKey:"rafli_link_id") ?? ""
    @Published var linked=false
    @Published var linkedName=""
    @Published var uploadProgress=0.0
    @Published var status="اختر طريقة النشر بعد تجهيز الفيديو."
    @Published var lastPublishID = UserDefaults.standard.string(forKey:"rafli_last_publish_id") ?? ""
    @Published var publishState=""
    @Published var uploadedBytes:Int64=0

    func saveBackend() throws {
        let t=backendURL.trimmingCharacters(in:.whitespacesAndNewlines)
        guard let u=URL(string:t),u.scheme=="https",u.host != nil else { throw RAFLIUploadError.invalidBackend }
        backendURL=t.trimmingCharacters(in:CharacterSet(charactersIn:"/")); UserDefaults.standard.set(backendURL,forKey:"rafli_backend_url"); status="تم حفظ الخادم ✅"
    }
    func startTikTokLink() async throws {
        try saveBackend(); var req=URLRequest(url:URL(string:backendURL+"/api/link/start")!); req.httpMethod="POST"; req.setValue("application/json",forHTTPHeaderField:"Accept")
        let (data,resp)=try await URLSession.shared.data(for:req); try Self.check(resp,data)
        let d=try JSONDecoder().decode(LinkStartResponse.self,from:data); linkID=d.link_id; UserDefaults.standard.set(linkID,forKey:"rafli_link_id")
        guard let auth=URL(string:d.auth_url) else { throw RAFLIUploadError.invalidResponse }; status="تم فتح TikTok للربط. وافق ثم ارجع إلى RAFLI."; await UIApplication.shared.open(auth)
    }
    func checkLink() async throws {
        try saveBackend(); guard !linkID.isEmpty else { throw RAFLIUploadError.notLinked }
        var c=URLComponents(string:backendURL+"/api/link/status")!; c.queryItems=[URLQueryItem(name:"link_id",value:linkID)]
        let (data,resp)=try await URLSession.shared.data(from:c.url!); try Self.check(resp,data); let d=try JSONDecoder().decode(LinkStatusResponse.self,from:data)
        linked=d.linked; linkedName=d.username ?? ""; status=linked ? "TikTok مربوط ✅" : "الربط لم يكتمل بعد."
    }
    func uploadDraft(file:URL) async throws -> String {
        try saveBackend(); guard !linkID.isEmpty else { throw RAFLIUploadError.notLinked }; uploadProgress=0; status="جاري تجهيز ملف الرفع الرسمي…"
        let boundary="RAFLI-\(UUID().uuidString)"; let bodyURL=FileManager.default.temporaryDirectory.appendingPathComponent("RAFLI_UPLOAD_\(UUID().uuidString).body")
        FileManager.default.createFile(atPath:bodyURL.path,contents:nil); let handle=try FileHandle(forWritingTo:bodyURL)
        defer { try? handle.close(); try? FileManager.default.removeItem(at:bodyURL) }
        func write(_ s:String)throws{try handle.write(contentsOf:Data(s.utf8))}
        try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"link_id\"\r\n\r\n\(linkID)\r\n")
        try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"video\"; filename=\"RAFLI_ULTRA_READY.mp4\"\r\nContent-Type: video/mp4\r\n\r\n")
        let source=try FileHandle(forReadingFrom:file); let total=(try FileManager.default.attributesOfItem(atPath:file.path)[.size] as? NSNumber)?.int64Value ?? 1; var sent:Int64=0
        while true { let chunk=try source.read(upToCount:1024*1024) ?? Data(); if chunk.isEmpty{break}; try handle.write(contentsOf:chunk); sent += Int64(chunk.count); uploadProgress=min(0.45,Double(sent)/Double(max(1,total))*0.45) }
        try source.close(); try write("\r\n--\(boundary)--\r\n"); try handle.synchronize()
        var req=URLRequest(url:URL(string:backendURL+"/api/tiktok/upload-draft")!); req.httpMethod="POST"; req.setValue("multipart/form-data; boundary=\(boundary)",forHTTPHeaderField:"Content-Type"); req.setValue("application/json",forHTTPHeaderField:"Accept")
        status="يرفع RAFLI الملف إلى TikTok عبر الخادم الرسمي…"; let (data,resp)=try await URLSession.shared.upload(for:req,fromFile:bodyURL); uploadProgress=0.98; try Self.check(resp,data)
        let d=try JSONDecoder().decode(UploadDraftResponse.self,from:data); guard d.ok != false else { throw RAFLIUploadError.server(d.message ?? "فشل رفع المسودة.") }
        uploadProgress=1; let pid=d.publish_id ?? ""; lastPublishID=pid; UserDefaults.standard.set(pid,forKey:"rafli_last_publish_id"); publishState="PROCESSING_UPLOAD"; status="تم إرسال الفيديو إلى TikTok ✅ الآن RAFLI يستطيع فحص حالة المعالجة."; return pid
    }
    func checkPublishStatus() async throws {
        try saveBackend(); guard !linkID.isEmpty else {throw RAFLIUploadError.notLinked}; guard !lastPublishID.isEmpty else {throw RAFLIUploadError.server("لا يوجد publish_id بعد. ارفع فيديو أولًا.")}
        var c=URLComponents(string:backendURL+"/api/tiktok/status")!; c.queryItems=[URLQueryItem(name:"link_id",value:linkID),URLQueryItem(name:"publish_id",value:lastPublishID)]
        let (data,resp)=try await URLSession.shared.data(from:c.url!); try Self.check(resp,data); let d=try JSONDecoder().decode(PublishStatusResponse.self,from:data); if d.ok==false {throw RAFLIUploadError.server(d.message ?? "تعذر جلب حالة TikTok")}
        publishState=d.status ?? "UNKNOWN"; uploadedBytes=d.uploaded_bytes ?? 0
        switch publishState { case "PROCESSING_UPLOAD":status="TikTok يستقبل/يعالج الملف الآن…"; case "SEND_TO_USER_INBOX":status="وصلت المسودة إلى TikTok ✅ افتح التطبيق وأكمل النشر."; case "PUBLISH_COMPLETE":status="تم النشر من TikTok ✅"; case "FAILED":status="TikTok رفض المعالجة: \(d.fail_reason ?? "سبب غير معروف")"; default:status="حالة TikTok: \(publishState)" }
    }
    func saveToPhotos(file:URL) async throws {
        let r=await PHPhotoLibrary.requestAuthorization(for:.addOnly); guard r == .authorized || r == .limited else {throw RAFLIUploadError.photosDenied}
        try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL:file) }; status="تم حفظ RAFLI ULTRA READY في الصور ✅"
    }
    func openTikTok() async { let app=URL(string:"tiktok://")!; if UIApplication.shared.canOpenURL(app){await UIApplication.shared.open(app)} else if let web=URL(string:"https://www.tiktok.com/"){await UIApplication.shared.open(web)} }
    private static func check(_ response:URLResponse,_ data:Data)throws { guard let h=response as? HTTPURLResponse else {throw RAFLIUploadError.invalidResponse}; guard 200..<300 ~= h.statusCode else {throw RAFLIUploadError.server(String(data:data,encoding:.utf8) ?? "HTTP \(h.statusCode)")} }
}
