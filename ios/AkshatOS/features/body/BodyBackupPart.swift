import Foundation

/// Body in the hub's full backup: the same folder its own export writes, photos included.
extension BodyLogStore: HubBackupPart {
    var backupID: String { "body" }
    var backupTitle: String { "Body" }

    func writeBackup(into folder: URL) async throws -> String? {
        load()
        guard storageAvailable else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "Body could not be read"])
        }
        let name = "body"
        let staged = try stageBackup()
        defer { try? FileManager.default.removeItem(at: staged.deletingLastPathComponent()) }
        try FileManager.default.moveItem(at: staged, to: folder.appendingPathComponent(name))
        return name
    }

    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        try checkBackup(at: item)
        return HubBackupRestore { [self] in
            defer { message = nil }
            return restore(from: item) ? .restored : .failed(message ?? "unknown error")
        }
    }
}
