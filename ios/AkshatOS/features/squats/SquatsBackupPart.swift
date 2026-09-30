import Foundation

/// Pushups in the hub's full backup: the same JSON file the dashboard's own export writes.
extension SquatStore: HubBackupPart {
    var backupID: String { "pushups" }
    var backupTitle: String { "Pushups" }

    func writeBackup(into folder: URL) async throws -> String? {
        await refresh()
        guard storageAvailable else {
            throw CocoaError(.fileReadNoPermission, userInfo: [
                NSLocalizedDescriptionKey: "Pushups could not be read; unlock the phone and try again"])
        }
        let name = "pushups.json"
        try makeBackupData().write(to: folder.appendingPathComponent(name), options: .atomic)
        return name
    }

    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        let backup = try prepareRestore(Data(contentsOf: item)).validated()
        return HubBackupRestore(note: "Open Pushups and resume any open day to turn reminders back on.") { [self] in
            guard await restore(backup) else { return .failed(message ?? "it is busy, try again") }
            // The note above says this in the full-backup summary; no second alert.
            notice = nil
            return .restored
        }
    }
}
