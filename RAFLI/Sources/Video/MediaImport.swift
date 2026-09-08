import CoreTransferable
import UniformTypeIdentifiers
import AVFoundation
import UIKit

struct ImportedMovie: Transferable, Sendable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in SentTransferredFile(movie.url) } importing: { received in
            let target = try MediaFiles.importCopy(received.file)
            return ImportedMovie(url: target)
        }
    }
}
enum MediaFiles {
    static var cache: URL { FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("RAFLI", isDirectory: true) }
    static func importCopy(_ source: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: cache, withIntermediateDirectories: true)
        let bytes = Int64((try source.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0)
        try checkSpace(for: bytes * 2)
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let url = cache.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try fm.copyItem(at: source, to: url)
        return url
    }
    static func thumbnail(_ video: URL) async throws -> URL {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
        let (cgImage, _) = try await generator.image(at: .zero)
        guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85) else { throw AppFailure.importFailed }
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let path = cache.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        try data.write(to: path, options: .atomic)
        return path
    }
    static func checkSpace(for bytes: Int64) throws {
        let values = try cache.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let available = values.volumeAvailableCapacityForImportantUsage, available < bytes + 100_000_000 { throw AppFailure.lowStorage }
    }
    static func removeCacheFile(_ url: URL?) {
        guard let url, url.standardizedFileURL.path.hasPrefix(cache.standardizedFileURL.path + "/") else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
