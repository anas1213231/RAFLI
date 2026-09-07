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

    private func restored(_ key: String) -> URL? {
        guard let path = UserDefaults.standard.string(forKey: key), FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}
