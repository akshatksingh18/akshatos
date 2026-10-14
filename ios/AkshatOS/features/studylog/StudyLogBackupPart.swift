import Foundation

/// Study Log in the hub's full backup: the same JSON file its own export writes.
extension StudyLogStore: HubBackupPart {
    var backupID: String { "studyLog" }
    var backupTitle: String { "Study Log" }

    func writeBackup(into folder: URL) async throws -> String? {
        load()
        guard storageAvailable else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "Study Log could not be read"])
        }
        let name = "study-log.json"
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
