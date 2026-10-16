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
        let checked = try Self.validatedBackup(data)
        var end: Date?
        if let running = checked.segments.first(where: \.isRunning) {
            let backup = try LocalDataCoding.decode(StudyLogBackup.self, data)
            guard let chosen = await approveRunningRestore(start: running.start, suggested: backup.exportedAt) else {
                throw PersonalDataError.invalid("Study restore cancelled: running time was not confirmed.")
            }
            end = chosen
        }
        let confirmedEnd = end
        return HubBackupRestore { [self] in
            defer { message = nil }
            return restoreBackup(data, confirmedRunningEnd: confirmedEnd) ? .restored : .failed(message ?? "unknown error")
        }
    }
}
