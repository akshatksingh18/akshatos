import CryptoKit
import Foundation

/// Copy-on-import file storage. A video is streamed in fixed-size chunks, so a large one never
/// becomes a single in-memory value, and it is hashed as it is copied. The copies are the library:
/// moving or deleting the original in Photos or Files afterwards changes nothing here. Like
/// PageVault's PDFs, they are left in the phone's own device backup.
struct ReelVaultStorage: Sendable {
    static let chunkBytes = 1 << 20

    struct Staged: Sendable {
        var url: URL
        var fingerprint: String
        var byteCount: Int64
    }

    let root: URL
    private var media: URL { root.appendingPathComponent("Media", isDirectory: true) }
    private var scratch: URL { root.appendingPathComponent("Incoming", isDirectory: true) }
    private var outgoing: URL { root.appendingPathComponent("Outgoing", isDirectory: true) }

    init(root: URL? = nil) throws {
        if let root {
            self.root = root
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true)
            self.root = support.appendingPathComponent("ReelVault", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    func mediaURL(for fileName: String) -> URL { media.appendingPathComponent(fileName) }

    func hasMedia(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: mediaURL(for: fileName).path)
    }

    /// Coordinates a read of a possibly cloud-backed source and streams it into a scratch file.
    /// The caller checks the staged file plays before it is promoted into the library.
    func stage(from source: URL, fileExtension: String) throws -> Staged {
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let destination = scratch.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
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
            throw ReelVaultError.storage(coordinationFailure.localizedDescription)
        }
        if let streamFailure {
            discard(destination)
            throw streamFailure
        }
        guard let staged else {
            discard(destination)
            throw ReelVaultError.storage("the file could not be read")
        }
        return staged
    }

    private func streamCopy(from source: URL, to destination: URL) throws -> Staged {
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw ReelVaultError.storage("no writable space in the app")
        }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        guard let output = FileHandle(forWritingAtPath: destination.path) else {
            throw ReelVaultError.storage("the copy could not be opened for writing")
        }
        defer { try? output.close() }
        var digest = SHA256()
        var total: Int64 = 0
        while let chunk = try input.read(upToCount: Self.chunkBytes), !chunk.isEmpty {
            digest.update(data: chunk)
            try output.write(contentsOf: chunk)
            total += Int64(chunk.count)
        }
        guard total > 0 else { throw ReelVaultError.notAVideo }
        let fingerprint = digest.finalize().map { String(format: "%02x", $0) }.joined()
        return Staged(url: destination, fingerprint: fingerprint, byteCount: total)
    }

    /// Moves a checked staged file into the library under its permanent name.
    func promote(_ staged: URL, as fileName: String) throws {
        let destination = mediaURL(for: fileName)
        do {
            try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: staged, to: destination)
        } catch {
            discard(staged)
            throw ReelVaultError.storage(error.localizedDescription)
        }
    }

    func discard(_ staged: URL) {
        try? FileManager.default.removeItem(at: staged)
    }

    /// Removes only the app's copy. The original in Photos or Files is never touched.
    func remove(fileName: String) throws {
        let url = mediaURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// Copies left behind by an import that was cut off, such as the app being closed mid-copy.
    func clearAbandonedStaging() {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - Backup staging

    /// Builds a backup in a disposable folder for the system file mover: every video beside the
    /// manifest, which is written last so a folder with a manifest is complete. `copyItem` can be
    /// satisfied with a clone, so videos are not read into memory.
    func stageExport(manifest: Data, name: String, fileNames: [String]) throws -> URL {
        clearOutgoing()
        let folder = outgoing.appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        let videos = folder.appendingPathComponent(ReelVaultBackup.mediaFolder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: videos, withIntermediateDirectories: true)
            var excluded = URLResourceValues()
            excluded.isExcludedFromBackup = true
            var staging = outgoing
            try? staging.setResourceValues(excluded)
            for fileName in fileNames {
                try FileManager.default.copyItem(at: mediaURL(for: fileName),
                                                 to: videos.appendingPathComponent(fileName))
            }
            try manifest.write(to: folder.appendingPathComponent(ReelVaultBackup.manifestName), options: .atomic)
            return folder
        } catch {
            clearOutgoing()
            throw ReelVaultError.storage(error.localizedDescription)
        }
    }

    func clearOutgoing() {
        try? FileManager.default.removeItem(at: outgoing)
    }
}
