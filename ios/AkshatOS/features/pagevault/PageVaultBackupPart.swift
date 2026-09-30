import Foundation

/// PageVault in the hub's full backup: the same folder its own full export writes, every PDF
/// included. An empty library has nothing to back up and is left out.
extension PageVaultStore: HubBackupPart {
    var backupID: String { "pageVault" }
    var backupTitle: String { "PageVault" }

    func writeBackup(into folder: URL) async throws -> String? {
        await ensureLoaded()
        guard !books.isEmpty else { return nil }
        let name = "pagevault"
        let staged = try await prepareExport(includeDocuments: true)
        defer { finishExport() }
        try FileManager.default.moveItem(at: staged, to: folder.appendingPathComponent(name))
        return name
    }

    /// Restoring adds missing books and gives books already here the backup's place and status.
    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        await ensureLoaded()
        let prepared: PageVaultPreparedRestore
        do {
            prepared = try await prepareRestore(from: item)
        } catch PageVaultBackupError.nothingToRestore(let missing) where missing == 0 {
            return .alreadyCurrent
        }
        return HubBackupRestore { [self] in
            do {
                _ = try await restore(prepared, mode: .replaceMatching)
                return .restored
            } catch {
                return .failed(error.localizedDescription)
            }
        }
    }
}
