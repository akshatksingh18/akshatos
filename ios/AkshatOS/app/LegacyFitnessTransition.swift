import Foundation

/// Old stores remain recoverable. Only an explicit on-phone handover disables their schedulers.
@MainActor struct GatedSquatReminders: SquatReminders {
    let preferences: PersonalPreferences
    private let base = ReminderService()
    init(preferences: PersonalPreferences) { self.preferences = preferences }
    func authorize() async throws -> Bool { preferences.fitnessStopped ? false : try await base.authorize() }
    func snapshot() async -> ReminderSnapshot { await base.snapshot() }
    func schedule(_ session: SquatSession, firstReminderAt: Date) async throws {
        guard !preferences.fitnessStopped else { base.cancel(); throw PersonalDataError.invalid("Fitness reminders now belong to WHOOP.") }
        try await base.schedule(session, firstReminderAt: firstReminderAt)
    }
    func ensureDailyStartReminder() async throws {
        if preferences.fitnessStopped { base.cancelDailyStartReminder() } else { try await base.ensureDailyStartReminder() }
    }
    func cancel() { base.cancel() }
    func cancelDailyStartReminder() { base.cancelDailyStartReminder() }
}
@MainActor struct GatedLiftReminders: LiftReminding {
    let preferences: PersonalPreferences
    private let base = LiftReminderService()
    init(preferences: PersonalPreferences) { self.preferences = preferences }
    func schedule(at date: Date, workoutID: UUID, canFinish: Bool) async {
        if preferences.fitnessStopped { base.cancel() }
        else { await base.schedule(at: date, workoutID: workoutID, canFinish: canFinish) }
    }
    func cancel() { base.cancel() }
}
