import Foundation

final class RAFLIStorage {
    static let shared = RAFLIStorage()
    private init() {}

    private var folder: URL {
        let fm = FileManager.default
        let url = fm.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("RAFLI Videos", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func importURL(ext: String) -> URL {
        folder.appendingPathComponent("ORIGINAL_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).\(ext)")
    }

    func outputURL(ext: String) -> URL {
        folder.appendingPathComponent("RAFLI_OUTPUT_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).\(ext)")
    }

    func rememberSource(_ url: URL) { UserDefaults.standard.set(url.path, forKey: "rafli_last_source") }
    func rememberOutput(_ url: URL) { UserDefaults.standard.set(url.path, forKey: "rafli_last_output") }

    func restoredSource() -> URL? { restored("rafli_last_source") }
    func restoredOutput() -> URL? { restored("rafli_last_output") }

    func allVideos() -> [URL] {
        let allowed = Set(["mp4", "mov", "m4v"])
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { allowed.contains($0.pathExtension.lowercased()) }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a > b
            }
    }

    private func restored(_ key: String) -> URL? {
        guard let path = UserDefaults.standard.string(forKey: key), FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}
