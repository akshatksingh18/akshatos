import CryptoKit
import Foundation

/// Copy-on-import file storage. Documents are streamed in fixed-size chunks, so a
/// multi-hundred-megabyte PDF never becomes a single in-memory `Data` value. Per the accepted
/// backup policy these copies are *not* marked excluded from device backup.
struct PageVaultStorage: Sendable {
    static let chunkBytes = 1 << 20

    struct Staged {
        var url: URL
        var fingerprint: String
        var byteCount: Int64
    }

    /// One PDF to place in a full export: the app's copy, and its path inside the export folder.
    struct PageVaultExportItem: Sendable {
        var source: URL
        var path: String
    }

    struct PageVaultManifestRead: Sendable {
        var data: Data
        /// The export folder, when a folder rather than a lone JSON file was picked.
        var folder: URL?
    }

    let root: URL
    private var scratch: URL { root.appendingPathComponent("Incoming", isDirectory: true) }
    private var covers: URL { root.appendingPathComponent("Covers", isDirectory: true) }
    private var outgoing: URL { root.appendingPathComponent("Outgoing", isDirectory: true) }

    init(root: URL? = nil) throws {
        if let root {
            self.root = root
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil, create: true)
            self.root = support.appendingPathComponent("PageVault", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    func documentURL(for id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
            .appendingPathComponent("document.pdf")
    }

    /// Covers are a disposable cache: always regenerable from page one, so they are kept out of
    /// device backup rather than inflating it.
    func coverURL(for id: UUID) -> URL {
        covers.appendingPathComponent("\(id.uuidString).png")
    }

    func hasCover(for id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: coverURL(for: id).path)
    }

    func writeCover(_ data: Data, for id: UUID) throws {
        try FileManager.default.createDirectory(at: covers, withIntermediateDirectories: true)
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var directory = covers
        try? directory.setResourceValues(excluded)
        try data.write(to: coverURL(for: id), options: .atomic)
    }

    /// Coordinates a read of a possibly cloud-backed source and streams it into a scratch file.
    /// The caller validates the staged file before it is promoted into the library.
    func stage(from source: URL) throws -> Staged {
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let destination = scratch.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        var staged: Staged?
        var streamFailure: Error?
        var coordinationFailure: NSError?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [],
                                       error: &coordinationFailure) { readable in
            do {
                staged = try streamCopy(from: readable, to: destination)
            } catch {
                streamFailure = error
            }
        }
        if let coordinationFailure {
            discard(destination)
            throw PageVaultImportFailure.storage(coordinationFailure.localizedDescription)
        }
        if let streamFailure {
            discard(destination)
            throw streamFailure
        }
        guard let staged else {
            discard(destination)
            throw PageVaultImportFailure.storage("the file could not be read")
        }
        return staged
    }

    private func streamCopy(from source: URL, to destination: URL) throws -> Staged {
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw PageVaultImportFailure.storage("no writable space in the app container")
        }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        guard let output = FileHandle(forWritingAtPath: destination.path) else {
            throw PageVaultImportFailure.storage("the copy could not be opened for writing")
        }
        defer { try? output.close() }
        var digest = SHA256()
        var total: Int64 = 0
        while let chunk = try input.read(upToCount: Self.chunkBytes), !chunk.isEmpty {
            digest.update(data: chunk)
            try output.write(contentsOf: chunk)
            total += Int64(chunk.count)
        }
        guard total > 0 else { throw PageVaultImportFailure.unreadable }
        let fingerprint = digest.finalize().map { String(format: "%02x", $0) }.joined()
        return Staged(url: destination, fingerprint: fingerprint, byteCount: total)
    }

    /// Moves a validated staged file into its permanent per-book directory.
    func promote(_ staged: URL, to id: UUID) throws {
        let destination = documentURL(for: id)
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: staged, to: destination)
        } catch {
            discard(staged)
            try? FileManager.default.removeItem(at: destination.deletingLastPathComponent())
            throw PageVaultImportFailure.storage(error.localizedDescription)
        }
    }

    func discard(_ staged: URL) {
        try? FileManager.default.removeItem(at: staged)
    }

    // MARK: - Export staging

    /// Builds an export in a disposable folder that the system file mover then moves out of the
    /// app. PDFs are duplicated with `copyItem`, which APFS can satisfy with a clone, and are never
    /// read into memory. The manifest is written last, so a staged folder with a manifest is
    /// complete. Returns the folder for a full export, or the JSON file when `documents` is nil.
    func stageExport(manifest: Data, name: String, documents: [PageVaultExportItem]?) throws -> URL {
        clearOutgoing()
        let container = outgoing.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
            excludeFromBackup(outgoing)
            guard let documents else {
                let file = container.appendingPathComponent(name).appendingPathExtension("json")
                try manifest.write(to: file, options: .atomic)
                return file
            }
            let folder = container.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent(PageVaultBackup.documentsFolder, isDirectory: true),
                withIntermediateDirectories: true)
            for item in documents {
                try FileManager.default.copyItem(at: item.source,
                                                 to: folder.appendingPathComponent(item.path))
            }
            try manifest.write(to: folder.appendingPathComponent(PageVaultBackup.manifestName),
                               options: .atomic)
            return folder
        } catch {
            try? FileManager.default.removeItem(at: container)
            throw PageVaultBackupError.storage(error.localizedDescription)
        }
    }

    /// Whatever is left here belongs to an export that was saved, cancelled or interrupted.
    func clearOutgoing() {
        try? FileManager.default.removeItem(at: outgoing)
    }

    /// Reads the manifest from what the user picked: an export folder, or a lone JSON file of
    /// reading data. A folder without a readable manifest is simply not an export.
    func readManifest(at source: URL) throws -> PageVaultManifestRead {
        let isFolder = (try? source.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        let file = isFolder ? source.appendingPathComponent(PageVaultBackup.manifestName) : source
        var data: Data?
        var failure: Error?
        var coordinationFailure: NSError?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [],
                                       error: &coordinationFailure) { readable in
            do {
                let size = try readable.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= PageVaultBackup.maximumManifestBytes else {
                    throw PageVaultBackupError.tooLarge
                }
                data = try Data(contentsOf: readable)
            } catch {
                failure = error
            }
        }
        if let failure = failure as? PageVaultBackupError { throw failure }
        guard coordinationFailure == nil, failure == nil, let data else {
            throw PageVaultBackupError.invalidFile
        }
        return PageVaultManifestRead(data: data, folder: isFolder ? source : nil)
    }

    private func excludeFromBackup(_ url: URL) {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var target = url
        try? target.setResourceValues(values)
    }

    /// Removes only PageVault's own copy and cover. The user's original source file is never touched.
    func remove(id: UUID) throws {
        try? FileManager.default.removeItem(at: coverURL(for: id))
        let directory = documentURL(for: id).deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    /// Clears scratch files left behind by an import that was interrupted mid-copy.
    func clearAbandonedStaging() {
        guard let entries = try? FileManager.default.contentsOfDirectory(at: scratch,
                                                                        includingPropertiesForKeys: nil)
        else { return }
        for entry in entries { try? FileManager.default.removeItem(at: entry) }
    }
}
