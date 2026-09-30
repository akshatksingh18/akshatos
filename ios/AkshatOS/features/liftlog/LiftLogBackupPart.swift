import Foundation

/// Lift Log in the hub's full backup: the same JSON file its own export writes.
extension LiftLogStore: HubBackupPart {
    var backupID: String { "liftLog" }
    var backupTitle: String { "Lift Log" }

    func writeBackup(into folder: URL) async throws -> String? {
        load()
        guard storageAvailable else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "Lift Log could not be read"])
        }
        let name = "lift-log.json"
        try backupData().write(to: folder.appendingPathComponent(name), options: .atomic)
        return name
    }

    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        let data = try Data(contentsOf: item)
        _ = try Self.validatedBackup(data)
        return HubBackupRestore { [self] in
            defer { message = nil }
            return restoreBackup(data) ? .restored : .failed(message ?? "unknown error")
        }
    }
}
