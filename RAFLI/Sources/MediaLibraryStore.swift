import Foundation
import SwiftUI

struct RAFLIMediaItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case original
        case enhanced
    }

    let id: UUID
    let kind: Kind
    let fileName: String
    let createdAt: Date
    let sourceID: UUID?

    init(id: UUID = UUID(), kind: Kind, fileName: String, createdAt: Date = Date(), sourceID: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.fileName = fileName
        self.createdAt = createdAt
        self.sourceID = sourceID
    }
}

@MainActor
final class RAFLIMediaStore: ObservableObject {
    @Published private(set) var items: [RAFLIMediaItem] = []

    private let fm = FileManager.default
    private let root: URL
    private let originals: URL
    private let enhanced: URL
    private let manifest: URL

    init() {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        root = docs.appendingPathComponent("RAFLI Library", isDirectory: true)
        originals = root.appendingPathComponent("Originals", isDirectory: true)
        enhanced = root.appendingPathComponent("Enhanced", isDirectory: true)
        manifest = root.appendingPathComponent("library.json")
        try? fm.createDirectory(at: originals, withIntermediateDirectories: true)
        try? fm.createDirectory(at: enhanced, withIntermediateDirectories: true)
        load()
        removeBrokenEntries()
    }

    var originalsOnly: [RAFLIMediaItem] {
        items.filter { $0.kind == .original }
    }

    var enhancedOnly: [RAFLIMediaItem] {
        items.filter { $0.kind == .enhanced }
    }

    func url(for item: RAFLIMediaItem) -> URL {
        let folder = item.kind == .original ? originals : enhanced
        return folder.appendingPathComponent(item.fileName)
    }

    func importOriginal(from source: URL) throws -> RAFLIMediaItem {
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension.lowercased()
        let fileName = "ORIGINAL_\(UUID().uuidString).\(ext)"
        let destination = originals.appendingPathComponent(fileName)
        try copyReplacing(source, to: destination)
        let item = RAFLIMediaItem(kind: .original, fileName: fileName)
        items.insert(item, at: 0)
        save()
        return item
    }

    func saveEnhanced(from source: URL, sourceID: UUID?) throws -> RAFLIMediaItem {
        let ext = source.pathExtension.isEmpty ? "mp4" : source.pathExtension.lowercased()
        let fileName = "ENHANCED_\(UUID().uuidString).\(ext)"
        let destination = enhanced.appendingPathComponent(fileName)
        try copyReplacing(source, to: destination)
        let item = RAFLIMediaItem(kind: .enhanced, fileName: fileName, sourceID: sourceID)
        items.insert(item, at: 0)
        save()
        return item
    }

    func delete(_ item: RAFLIMediaItem) {
        try? fm.removeItem(at: url(for: item))
        items.removeAll { $0.id == item.id }
        save()
    }

    private func copyReplacing(_ source: URL, to destination: URL) throws {
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        var writable = destination
        try? writable.setResourceValues(values)
    }

    private func load() {
        guard let data = try? Data(contentsOf: manifest),
              let decoded = try? JSONDecoder().decode([RAFLIMediaItem].self, from: data) else {
            items = []
            return
        }
        items = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: manifest, options: .atomic)
    }

    private func removeBrokenEntries() {
        let filtered = items.filter { fm.fileExists(atPath: url(for: $0).path) }
        if filtered.count != items.count {
            items = filtered
            save()
        }
    }
}
