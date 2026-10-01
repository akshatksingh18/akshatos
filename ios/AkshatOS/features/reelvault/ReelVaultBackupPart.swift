import Foundation

/// ReelVault in the hub's full backup: the same folder its own backup writes, every video
/// included. An empty library has nothing to back up and is left out.
extension ReelVaultStore: HubBackupPart {
    var backupID: String { "reelVault" }
    var backupTitle: String { "ReelVault" }

    func writeBackup(into folder: URL) async throws -> String? {
        if !storageAvailable { load() }
        guard storageAvailable else { throw ReelVaultError.storage("the app's storage is unavailable") }
        guard !videos.isEmpty else { return nil }
        let name = "reelvault"
        let staged = try await stageBackup()
        defer { finishExport() }
        try FileManager.default.moveItem(at: staged, to: folder.appendingPathComponent(name))
        return name
    }

    /// Restoring adds missing videos and gives videos already here the backup's headline.
    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        if !storageAvailable { load() }
        let prepared: PreparedRestore
        do {
            prepared = try prepareRestore(from: item)
        } catch ReelVaultError.nothingToRestore {
            return .alreadyCurrent
        }
        return HubBackupRestore { [self] in
            do {
                _ = try await restore(prepared)
                return .restored
            } catch {
                return .failed(error.localizedDescription)
            }
        }
    }
}
