import Foundation
import Observation

actor RAFLIStorage {
    static let shared = RAFLIStorage()
    private let fm = FileManager.default
    let root: URL
    private var manifest: URL { root.appendingPathComponent("studio-library.json") }
    private var items: [VideoItem] = []
    private var loaded = false
    init(root: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) { self.root = root }
    func url(for item: VideoItem) -> URL { root.appendingPathComponent(item.relativePath) }
    func thumbnailURL(for item: VideoItem) -> URL? { item.thumbnailPath.map { root.appendingPathComponent($0) } }
    func load() async throws -> [VideoItem] {
        if loaded { return items }
        for folder in ["Originals", "Processed", "Thumbnails"] {
            try fm.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: manifest.path) {
            items = try JSONDecoder().decode([VideoItem].self, from: Data(contentsOf: manifest))
        }
        // Upgrade in place. Existing videos remain at their original paths; no bulk copies.
        let folders = ["RAFLI Videos", "RAFLI Library/Originals", "RAFLI Library/Enhanced", "Originals", "Processed"]
        for folder in folders {
            let urls = (try? fm.contentsOfDirectory(at: root.appendingPathComponent(folder), includingPropertiesForKeys: [.creationDateKey])) ?? []
            for file in urls where ["mp4", "mov", "m4v"].contains(file.pathExtension.lowercased()) {
                let relative = folder + "/" + file.lastPathComponent
                guard !items.contains(where: { $0.relativePath == relative }) else { continue }
                guard let report = try? await VideoAnalyzer.analyze(file) else { continue }
                let id = UUID()
                var thumbnail: String?
                if let temp = try? await MediaFiles.thumbnail(file) {
                    thumbnail = "Thumbnails/\(id).jpg"
                    try fm.moveItem(at: temp, to: root.appendingPathComponent(thumbnail!))
                }
                let original = folder.contains("Originals") || file.lastPathComponent.hasPrefix("ORIGINAL_")
                items.append(VideoItem(id: id, kind: original ? .original : .processed, relativePath: relative, thumbnailPath: thumbnail, displayName: file.lastPathComponent, created: (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date(), sourceID: nil, report: report))
            }
        }
        items = items.filter { fm.fileExists(atPath: url(for: $0).path) }.sorted { $0.created > $1.created }
        try persist(items)
        loaded = true
        return items
    }
    func insert(_ video: StudioVideo, kind: VideoItem.Kind, sourceID: UUID?) throws -> VideoItem {
        guard loaded else { throw AppFailure.storageFailed }
        let id = UUID()
        let relative = "\(kind == .original ? "Originals" : "Processed")/\(id).\(video.url.pathExtension)"
        let destination = root.appendingPathComponent(relative)
        let thumbPath = video.thumbnail.map { _ in "Thumbnails/\(id).jpg" }
        do {
            try fm.copyItem(at: video.url, to: destination)
            if let thumb = video.thumbnail, let thumbPath { try fm.copyItem(at: thumb, to: root.appendingPathComponent(thumbPath)) }
            let item = VideoItem(id: id, kind: kind, relativePath: relative, thumbnailPath: thumbPath, displayName: video.name, created: Date(), sourceID: sourceID, report: video.report)
            let updated = [item] + items
            try persist(updated)
            items = updated
            return item
        } catch {
            try? fm.removeItem(at: destination)
            if let thumbPath { try? fm.removeItem(at: root.appendingPathComponent(thumbPath)) }
            throw error
        }
    }
    func delete(_ targets: [VideoItem]) throws {
        let trash = root.appendingPathComponent(".RAFLITrash-\(UUID())")
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        var moved: [(URL, URL)] = []
        do {
            for item in targets {
                for path in [Optional(item.relativePath), item.thumbnailPath].compactMap({ $0 }) {
                    let original = root.appendingPathComponent(path)
                    guard fm.fileExists(atPath: original.path) else { continue }
                    let temporary = trash.appendingPathComponent(UUID().uuidString)
                    try fm.moveItem(at: original, to: temporary)
                    moved.append((temporary, original))
                }
            }
            let ids = Set(targets.map(\.id))
            let updated = items.filter { !ids.contains($0.id) }
            try persist(updated)
            items = updated
        } catch {
            for (temporary, original) in moved { try? fm.moveItem(at: temporary, to: original) }
            throw error
        }
        try fm.removeItem(at: trash)
    }
    func storageBytes() -> Int64 {
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        var bytes: Int64 = 0
        for case let file as URL in enumerator {
            if let v = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), v.isRegularFile == true { bytes += Int64(v.fileSize ?? 0) }
        }
        return bytes
    }
    func clearCache() throws {
        if fm.fileExists(atPath: MediaFiles.cache.path) { try fm.removeItem(at: MediaFiles.cache) }
    }
    private func persist(_ value: [VideoItem]) throws {
        try JSONEncoder().encode(value).write(to: manifest, options: .atomic)
    }
}

@MainActor @Observable
final class LibraryModel {
    private(set) var items: [VideoItem] = []
    private(set) var bytes: Int64 = 0
    private(set) var loading = false
    var failure: AppFailure?
    let storage = RAFLIStorage.shared
    func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do { items = try await storage.load(); bytes = await storage.storageBytes() }
        catch { failure = .storage(error) }
    }
    func insert(_ video: StudioVideo, kind: VideoItem.Kind, sourceID: UUID?) async throws -> StudioVideo {
        let item = try await storage.insert(video, kind: kind, sourceID: sourceID)
        await refresh()
        return await studioVideo(item)
    }
    func studioVideo(_ item: VideoItem) async -> StudioVideo {
        StudioVideo(id: item.id, url: await storage.url(for: item), thumbnail: await storage.thumbnailURL(for: item), name: item.displayName, report: item.report, libraryID: item.id)
    }
    func delete(_ targets: [VideoItem]) async {
        do { try await storage.delete(targets); await refresh() }
        catch { failure = .storage(error) }
    }
}
