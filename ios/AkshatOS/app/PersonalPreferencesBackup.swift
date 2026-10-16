import Foundation

private struct PersonalPreferencesArchive: Codable {
    var version = 1
    var fullDayChallenge: Bool
    var fullDayStart: String
    var seenMilestone: Int
    var checkMinutes: Int
    var breakMinutes: Int
    var journalHour: Int
    var morningHour: Int?
    func validated() throws -> Self {
        guard version == 1, fullDayStart.isEmpty || ActivityDayClock().date(fullDayStart) != nil,
              (5...120).contains(checkMinutes), (5...180).contains(breakMinutes), (0...23).contains(journalHour), morningHour == nil || (0...23).contains(morningHour!),
              seenMilestone >= 0, !fullDayChallenge || !fullDayStart.isEmpty else {
            throw PersonalDataError.invalid("Personal settings backup contains invalid values.")
        }
        return self
    }
}

extension PersonalPreferences: HubBackupPart {
    var backupID: String { "personal-settings" }
    var backupTitle: String { "Personal settings" }
    func writeBackup(into folder: URL) async throws -> String? {
        let archive = PersonalPreferencesArchive(fullDayChallenge: fullDayChallenge, fullDayStart: fullDayStart,
            seenMilestone: seenMilestone, checkMinutes: checkMinutes, breakMinutes: breakMinutes, journalHour: journalHour, morningHour: morningHour)
        try LocalDataCoding.encode(archive.validated()).write(to: folder.appendingPathComponent("personal-settings.json"), options: .atomic)
        return "personal-settings.json"
    }
    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        let archive = try LocalDataCoding.decode(PersonalPreferencesArchive.self, Data(contentsOf: item)).validated()
        return HubBackupRestore(note: "Personal reminder opt-ins were switched off. Enable them deliberately in Settings. Re-link any Files folder yourself. Existing fitness handover and Journal lock choices were preserved.") { [self] in
            fullDayStart = archive.fullDayStart; fullDayChallenge = archive.fullDayChallenge
            seenMilestone = archive.seenMilestone; checkMinutes = archive.checkMinutes
            breakMinutes = archive.breakMinutes; journalHour = archive.journalHour; morningHour = archive.morningHour ?? 9
            stillStudying = false; breakReminder = false; morningPlan = false; journalReminder = false; badge = false
            challengeAccepted = false; challengeStartedAt = nil; lastStudyConfirmation = nil
            return .restored
        }
    }
}
