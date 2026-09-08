import SwiftUI
import PhotosUI
import AVFoundation
import OSLog

@MainActor @Observable
final class StudioModel {
    var state: StudioState = .empty
    var preset: RAFLIPreset = .smart
    var failure: AppFailure?
    var saved = false
    var saving = false
    private var source: StudioVideo?
    private var generation = UUID()
    private let log = Logger(subsystem: "com.ucorc.rafli.power", category: "Studio")
    func importPhoto(_ item: PhotosPickerItem, settings: AppSettings, library: LibraryModel) async {
        guard !state.busy else { return }
        reset()
        state = .importing
        do {
            guard let movie = try await item.loadTransferable(type: ImportedMovie.self) else { throw AppFailure.importFailed }
            await inspect(movie.url, name: settings.text("فيديو من الصور", "Video from Photos"), settings: settings, library: library)
        } catch { fail(error, fallback: .importFailed, settings: settings) }
    }
    func importFile(_ url: URL, settings: AppSettings, library: LibraryModel) async {
        guard !state.busy else { return }
        reset(); state = .importing
        do {
            let copy = try await Task.detached(priority: .userInitiated) {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let bytes = Int64((try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0)
                try MediaFiles.checkSpace(for: bytes)
                return try MediaFiles.importCopy(url)
            }.value
            await inspect(copy, name: url.lastPathComponent, settings: settings, library: library)
        } catch { fail(error, fallback: .importFailed, settings: settings) }
    }
    private func inspect(_ url: URL, name: String, settings: AppSettings, library: LibraryModel) async {
        state = .analyzing
        var thumbnail: URL?
        do {
            let report = try await VideoAnalyzer.analyze(url)
            thumbnail = try await MediaFiles.thumbnail(url)
            var video = StudioVideo(id: UUID(), url: url, thumbnail: thumbnail, name: name, report: report, libraryID: nil)
            if settings.keepOriginal {
                video = try await library.insert(video, kind: .original, sourceID: nil)
                MediaFiles.removeCacheFile(url); MediaFiles.removeCacheFile(thumbnail)
            }
            source = video; preset = settings.preset; state = .ready(video)
            settings.feedback()
        } catch {
            MediaFiles.removeCacheFile(url); MediaFiles.removeCacheFile(thumbnail)
            fail(error, fallback: .importFailed, settings: settings)
        }
    }
    func reprocess(_ video: StudioVideo, settings: AppSettings) {
        guard !state.busy else { return }
        reset(); source = video; preset = settings.preset; state = .ready(video)
    }
    func prepare(settings: AppSettings, library: LibraryModel) async {
        guard case .ready(let video) = state else { return }
        saved = false; settings.feedback(); state = .processing(video, preset == .preserve ? nil : 0)
        let run = generation
        let chosen = preset
        var output: URL?
        var thumb: URL?
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            UIApplication.shared.isIdleTimerDisabled = false
            if let output { try? FileManager.default.removeItem(at: output) }
            MediaFiles.removeCacheFile(thumb)
        }
        do {
            let expected = chosen == .preserve ? video.report.fileSizeMB * 1_048_576 : video.report.duration * Double(chosen == .smart ? 24_000_000 : chosen.targetBitrate) / 8
            try MediaFiles.checkSpace(for: Int64(expected * 2))
            output = try await VideoProcessor.export(source: video.url, preset: chosen, report: video.report) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == run, case .processing = self.state else { return }
                    self.state = .processing(video, progress)
                }
            }
            guard let output else { throw AppFailure.processFailed }
            state = .verifying(video)
            let actual = try await ExportVerifier.verify(output, source: video.report, preset: chosen)
            thumb = try await MediaFiles.thumbnail(output)
            let result = StudioVideo(id: UUID(), url: output, thumbnail: thumb, name: "RAFLI_" + video.name, report: actual, libraryID: nil)
            let persisted = try await library.insert(result, kind: .processed, sourceID: video.libraryID)
            state = .result(persisted); settings.feedback(.success)
            if settings.autoSave { await save(persisted.url, settings: settings) }
        } catch { fail(error, fallback: .processFailed, settings: settings) }
    }
    func save(_ url: URL, settings: AppSettings) async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do {
            try await RAFLIUploadEngine().saveToPhotos(file: url)
            saved = true; settings.feedback(.success)
        } catch {
            failure = (error as? RAFLIUploadError) == .photosDenied ? .photosDenied : .saveFailed
            settings.feedback(.error)
        }
    }
    func retry() { if let source { state = .ready(source) } else { state = .empty } }
    func reset() {
        guard !state.busy else { return }
        generation = UUID()
        if let source { MediaFiles.removeCacheFile(source.url); MediaFiles.removeCacheFile(source.thumbnail) }
        source = nil; state = .empty; saved = false
    }
    private func fail(_ error: Error, fallback: AppFailure, settings: AppSettings) {
        log.error("Operation failed: \(String(describing: error), privacy: .private)")
        let mapped = error as? AppFailure ?? (AppFailure.storage(error) == .lowStorage ? .lowStorage : fallback)
        state = .failed(mapped); settings.feedback(.error)
    }
}
