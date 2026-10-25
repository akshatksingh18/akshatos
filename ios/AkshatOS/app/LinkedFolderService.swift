import Foundation
import CryptoKit

@MainActor final class LinkedFolderService: ObservableObject {
    enum ExportFile: String { case study = "study-sessions.json", watched = "watchlist-watched.json" }
    @Published private(set) var linked = false
    @Published private(set) var status = "No folder linked. Manual import/export still works."
    @Published private(set) var lastRead: Date?
    @Published private(set) var lastWrite: Date?
    @Published private(set) var newWatchlistAvailable = false
    @Published private(set) var busy = false
    @Published private(set) var studyFiles: [Data] = []
    @Published private(set) var studyStatus = "No laptop sessions checked yet."
    private var watchlistData: Data?
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults; linked = defaults.data(forKey: "handoff.folder") != nil }
    func link(_ folder: URL) {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        do {
            guard try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw PersonalDataError.invalid("Choose a folder in Files.") }
            defaults.set(try folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil), forKey: "handoff.folder")
            linked = true; status = "Folder linked. Provider speed and re-signing still need a device test."
        } catch { status = "The folder was not linked: \(error.localizedDescription)" }
    }
    func unlink() {
        defaults.removeObject(forKey: "handoff.folder"); linked = false; watchlistData = nil
        studyFiles = []; studyStatus = "Folder unlinked. Local study records are unchanged."
        newWatchlistAvailable = false; status = "Folder unlinked. Local records are unchanged."
    }
    private func resolve() throws -> URL {
        guard let data = defaults.data(forKey: "handoff.folder") else { throw PersonalDataError.invalid("Choose a folder first.") }
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            defaults.set(try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil), forKey: "handoff.folder")
        }
        return url
    }
    func checkWatchlist(after revision: Int) async {
        guard linked, !busy else { return }; busy = true; defer { busy = false }
        do {
            let folder = try resolve(), scoped = folder.startAccessingSecurityScopedResource()
            defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
            let data = try await Task.detached(priority: .utility) { try Self.read(folder.appendingPathComponent("watchlist.json")) }.value
            let transfer = try LocalDataCoding.decode(WatchlistTransfer.self, data).validated()
            lastRead = Date(); newWatchlistAvailable = transfer.revision > revision
            watchlistData = newWatchlistAvailable ? data : nil
            status = newWatchlistAvailable ? "A newer Watchlist is ready to preview." : "No newer Watchlist revision. Local records are unchanged."
        } catch {
            status = "The linked Watchlist is unavailable. Local records are unchanged; retry or re-link in Files."
        }
    }
    func previewWatchlist(in store: WatchlistStore) { if let data = watchlistData { store.preview(data) } }
    func checkStudy() async {
        guard linked, !busy else { return }; busy = true; defer { busy = false }
        do {
            let folder = try resolve(), scoped = folder.startAccessingSecurityScopedResource()
            defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
            let files = try await Task.detached(priority: .utility) {
                let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                    .filter { $0.lastPathComponent.hasPrefix("study-laptop-") && $0.pathExtension == "json" }
                guard urls.count <= 8 else { throw PersonalDataError.invalid("Select the intended laptop file manually; this folder has more than eight.") }
                return try urls.sorted { $0.lastPathComponent < $1.lastPathComponent }.map(Self.read)
            }.value
            studyFiles = files
            studyStatus = files.isEmpty ? "No laptop session file has arrived. Phone records are unchanged."
                : "\(files.count) laptop file(s) available to preview. Nothing is imported automatically."
        } catch {
            studyFiles = []
            studyStatus = "Laptop files are unavailable or incomplete. Retry, use manual import or re-link; phone records are unchanged."
        }
    }
    nonisolated static func readStudyDocument(_ url: URL) throws -> Data { try read(url) }
    func write(_ data: Data, file: ExportFile) async { await writeNamed(data, name: file.rawValue) }
    func writePhoneStudy(_ data: Data, source: UUID) async {
        await writeNamed(data, name: "study-iphone-\(source.uuidString.lowercased()).json")
    }
    private func writeNamed(_ data: Data, name: String) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            guard data.count <= 25_000_000 else { throw PersonalDataError.invalid("Export is too large for this hand-off.") }
            let folder = try resolve(), scoped = folder.startAccessingSecurityScopedResource()
            defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
            try await Task.detached(priority: .utility) { try Self.write(data, folder: folder, name: name) }.value
            lastWrite = Date(); status = "\(name) exported. Provider delivery to the laptop is not yet confirmed."
        } catch { status = "Export was not confirmed: \(error.localizedDescription). Keep the local data and retry." }
    }
    nonisolated private static func read(_ url: URL) throws -> Data {
        var coordinationError: NSError?, result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { coordinated in
            result = Result {
                let attributes = try coordinated.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard attributes.isRegularFile == true, attributes.isSymbolicLink != true,
                      (attributes.fileSize ?? Int.max) <= 25_000_000 else { throw PersonalDataError.invalid("The linked file is not a bounded JSON document.") }
                let data = try Data(contentsOf: coordinated)
                let digest = coordinated.appendingPathExtension("sha256")
                if FileManager.default.fileExists(atPath: digest.path) {
                    let info = try digest.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
                    guard info.isSymbolicLink != true, info.isRegularFile == true, (info.fileSize ?? Int.max) <= 128 else { throw PersonalDataError.invalid("Invalid checksum file.") }
                    let expected = try String(contentsOf: digest, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard expected == SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() else {
                        throw PersonalDataError.invalid("The file and checksum disagree. Wait for the provider to finish.")
                    }
                }
                return data
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }; return try result.get()
    }
    nonisolated private static func write(_ data: Data, folder: URL, name: String) throws {
        var coordinationError: NSError?, result: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: folder, options: .forMerging, error: &coordinationError) { coordinated in
            result = Result {
                let url = coordinated.appendingPathComponent(name)
                try data.write(to: url, options: .atomic)
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                try Data(digest.utf8).write(to: url.appendingPathExtension("sha256"), options: .atomic)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileWriteUnknown) }; try result.get()
    }
}
