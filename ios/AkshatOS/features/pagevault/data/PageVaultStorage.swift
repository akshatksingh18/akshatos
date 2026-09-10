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

    let root: URL
    private var scratch: URL { root.appendingPathComponent("Incoming", isDirectory: true) }

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

    /// Removes only PageVault's own copy. The user's original source file is never touched.
    func remove(id: UUID) throws {
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
