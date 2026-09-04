import Foundation
import SwiftUI

@MainActor final class SquatStore: ObservableObject {
    @Published private(set) var sessions: [SquatSession] = []
    @Published private(set) var busy = false
    @Published private(set) var operational = "Ready"
    @Published private(set) var nextReminder: Date?
    @Published private(set) var snoozeReminder: Date?
    @Published private(set) var pendingActionCount = 0
    @Published private(set) var storageAvailable = false
    @Published var message: String?
    @Published var notice: String?
    @Published var summary: SquatDaySummary?
    @Published var interval: Int { didSet { defaults.set(interval, forKey: "squats.interval") } }
    @Published var goal: Int { didSet { defaults.set(goal, forKey: "squats.goal") } }
    private let defaults: UserDefaults
    private let repository: any SquatRepository
    private let reminders: any SquatReminders
    private let inbox: any SquatActionInbox
    private let now: () -> Date
    private let calendar: Calendar
    private var actionRevision = 0
    var active: SquatSession? { sessions.first { $0.isActive } }
    var today: [SquatSession] { sessions.filter { $0.day == SquatSession.dayKey(now(), calendar: calendar) } }
    var todayCount: Int { today.reduce(0) { $0 + $1.count } }
    var todayGoal: Int? {
        if let first = today.sorted(by: { $0.started < $1.started }).first { return first.goal }
        return goal > 0 ? goal : nil
    }
    var staleDay: Bool { active.map { $0.day != SquatSession.dayKey(now(), calendar: calendar) } ?? false }
    var streaks: (current: Int, best: Int) { SquatSession.streaks(sessions, now: now(), calendar: calendar) }
    var daySummaries: [SquatDaySummary] {
        Set(sessions.map(\.day)).compactMap { day in
            SquatDaySummary.make(day: day, sessions: sessions, now: now(), calendar: calendar)
        }.sorted { $0.day > $1.day }
    }

    init(defaults: UserDefaults = .standard, repository: (any SquatRepository)? = nil,
         reminders: (any SquatReminders)? = nil, inbox: (any SquatActionInbox)? = nil,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.defaults = defaults
        self.repository = repository ?? SwiftDataSquatRepository()
        self.reminders = reminders ?? ReminderService()
        self.inbox = inbox ?? FileSquatActionInbox()
        self.now = now
        self.calendar = calendar
        interval = max(1, min(180, defaults.object(forKey: "squats.interval") as? Int ?? 45))
        goal = max(0, min(100, defaults.integer(forKey: "squats.goal")))
        load()
    }

    private func load() {
        do {
            sessions = try repository.load()
            storageAvailable = true
        } catch {
            storageAvailable = false
            operational = "Storage unavailable"
            message = "Your local data could not be opened. Nothing was erased. Unlock your phone and return to retry; keep the app installed."
        }
    }

    private func save(_ session: SquatSession) throws {
        try repository.save(session)
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        sessions.sort { $0.started > $1.started }
    }

    func daySummary(for day: String) -> SquatDaySummary? {
        SquatDaySummary.make(day: day, sessions: sessions, now: now(), calendar: calendar)
    }

    func makeBackupData() throws -> Data {
        try SquatsBackup(sessions: sessions, interval: interval, goal: goal).encoded()
    }

    func prepareRestore(_ data: Data) throws -> SquatsBackup {
        try SquatsBackup.decode(data)
    }

    /// Called even while another command is suspended. Never discard a background response as busy.
    func receive(_ action: SquatAction) async {
        do {
            try inbox.enqueue(action)
            actionRevision += 1
            pendingActionCount = try inbox.pending().count
        } catch {
            message = "The notification action could not be saved. Unlock and open Squats to check your count before trying again."
            return
        }
        await refresh()
    }

    func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if !storageAvailable { load() }
        await settle()
    }

    private func settle() async {
        // A response can arrive during the final settings/request await, not just scheduling.
        // Repeat only for newly received work; a persistent storage error never spins a retry loop.
        var observed: Int
        repeat {
            observed = actionRevision
            do { try await drainInbox() } catch { actionFailure(error) }
            await reconcile()
        } while observed != actionRevision
    }

    private func drainInbox() async throws {
        let pending = try inbox.pending()
        pendingActionCount = pending.count
        if let session = active, pending.contains(where: { $0.kind == .pause && $0.canApply(to: session) }) {
            // A failed earlier Done save must not prevent a later Pause from stopping reminders.
            reminders.cancel()
        }
        guard storageAvailable else {
            // Pause can still cancel a matching OS schedule while the session store is protected.
            let snapshot = await reminders.snapshot()
            if try inbox.pending().contains(where: { $0.kind == .pause && $0.sessionID == snapshot.sessionID }) {
                reminders.cancel()
            }
            return
        }
        while let action = try inbox.pending().first {
            try await apply(action)
            // Receipt and event were saved together. A crash before removal safely replays as a no-op.
            try inbox.remove(action.id)
            pendingActionCount = try inbox.pending().count
        }
    }

    private func apply(_ action: SquatAction) async throws {
        guard let session = sessions.first(where: { $0.id == action.sessionID }),
              !(session.actionReceipts ?? []).contains(action.id) else { return }
        guard action.canApply(to: session) else {
            try acknowledge(action, session: session)
            return
        }
        if action.kind == .pause { reminders.cancel() }
        if action.kind == .snooze {
            let snapshot = await reminders.snapshot()
            let deadline = action.date.addingTimeInterval(600)
            // Do not resurrect expired snoozes or create a snooze without a usable regular cadence.
            guard deadline > now(), session.day == SquatSession.dayKey(now(), calendar: calendar),
                  snapshot.allowed, snapshot.sessionID == session.id,
                  snapshot.interval == TimeInterval(session.interval * 60) else {
                try acknowledge(action, session: session)
                message = "That snooze is no longer available. Open Squats to check your reminder status."
                return
            }
            try await reminders.schedule(session, snoozeUntil: deadline)
        }
        do { try save(action.applying(to: session)) }
        catch {
            if action.kind == .snooze { reminders.cancelSnooze() }
            throw error
        }
    }

    private func acknowledge(_ action: SquatAction, session: SquatSession) throws {
        var updated = session
        updated.actionReceipts = (updated.actionReceipts ?? []) + [action.id]
        try save(updated)
    }

    private func reconcile() async {
        nextReminder = nil
        snoozeReminder = nil
        guard storageAvailable else { operational = "Storage unavailable"; return }
        if var session = active, staleDay {
            reminders.cancel()
            session.state = .ended
            let boundary = SquatSession.endOfDay(session.day, calendar: calendar) ?? now()
            session.ended = max(session.started, min(now(), boundary))
            do {
                try save(session)
                notice = "Your previous Squats day was closed at the local day boundary."
            } catch {
                actionFailure(error)
                operational = "Storage unavailable"
                return
            }
        }
        let snapshot = await reminders.snapshot()
        guard let session = active else {
            reminders.cancel()
            operational = today.isEmpty ? "Ready" : "Day complete"
            return
        }
        guard session.state == .running else { reminders.cancel(); operational = "Paused"; return }
        guard snapshot.allowed else { operational = "Notifications blocked"; return }
        guard snapshot.sessionID == session.id,
              snapshot.interval == TimeInterval(session.interval * 60), snapshot.actionable else {
            operational = "Reminder needs repair"
            return
        }
        nextReminder = snapshot.next
        snoozeReminder = snapshot.snooze
        operational = "Running"
    }

    private func actionFailure(_ error: Error) {
        message = "Could not complete that action: \(error.localizedDescription). Saved history and queued notification actions were kept. Unlock and return to retry."
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if !storageAvailable { load() }
        do {
            try await drainInbox()
            guard storageAvailable else { return }
            try await operation()
        } catch { actionFailure(error) }
        await settle()
    }

    func start() async {
        await perform {
            guard active == nil, (1...180).contains(interval) else { return }
            guard try await reminders.authorize() else {
                message = "Allow notifications in iOS Settings before starting your day."
                return
            }
            let first = today.sorted { $0.started < $1.started }.first
            let snapshot = first != nil ? first!.goal : (goal > 0 ? goal : nil)
            var session = SquatSession(day: SquatSession.dayKey(now(), calendar: calendar), started: now(),
                                       interval: interval, goal: snapshot)
            try save(session)
            reminders.cancel()
            try await reminders.schedule(session, snoozeUntil: nil)
            session.state = .running
            do { try save(session) } catch { reminders.cancel(); throw error }
        }
    }

    private func dashboard(_ kind: SquatAction.Kind) async {
        await perform {
            guard let session = active, kind == .pause || !staleDay else { return }
            let action = SquatAction(id: UUID().uuidString, sessionID: session.id, kind: kind,
                date: now(), day: SquatSession.dayKey(now(), calendar: calendar), source: "dashboard")
            try await apply(action)
        }
    }

    func pause() async { await dashboard(.pause) }
    func done() async { await dashboard(.done) }
    func snooze() async { await dashboard(.snooze) }

    func resume() async {
        await perform {
            guard var session = active, !staleDay else { return }
            let snapshot = await reminders.snapshot()
            if session.state == .running && snapshot.allowed && snapshot.sessionID == session.id &&
                snapshot.interval == TimeInterval(session.interval * 60) && snapshot.actionable { return }
            guard try await reminders.authorize() else {
                message = "Notifications are disabled. Enable them in iOS Settings."
                return
            }
            reminders.cancel()
            try await reminders.schedule(session, snoozeUntil: nil)
            session.state = .running
            session.pauseReason = nil
            session.log(SquatEvent(date: now(), kind: .resume, source: "dashboard"))
            do { try save(session) } catch { reminders.cancel(); throw error }
        }
    }

    func undo() async {
        await perform {
            guard var session = active, !staleDay else { return }
            session.undo()
            try save(session)
        }
    }

    func end() async {
        await perform {
            guard var session = active else { return }
            reminders.cancel()
            session.state = .ended
            session.ended = now()
            try save(session)
            summary = daySummary(for: session.day)
        }
    }

    func restore(_ candidate: SquatsBackup) async {
        await perform {
            var backup = try candidate.validated()
            reminders.cancel()
            let pending = try inbox.pending()
            for index in backup.sessions.indices {
                let sessionID = backup.sessions[index].id
                let ignored = pending.filter { $0.sessionID == sessionID }.map(\.id)
                backup.sessions[index].actionReceipts = Array(Set(
                    (backup.sessions[index].actionReceipts ?? []) + ignored)).sorted()
            }
            try repository.replaceAll(with: backup.sessions)
            sessions = backup.sessions.sorted { $0.started > $1.started }
            interval = backup.settings.interval
            goal = backup.settings.goal
            summary = nil
            for action in pending { try? inbox.remove(action.id) }
            pendingActionCount = (try? inbox.pending().count) ?? 0
            notice = "Squats history and settings were restored. Resume any open day to re-arm reminders."
        }
    }

    func deleteHistory() async {
        await perform {
            let ids = Set(sessions.filter { !$0.isActive }.map(\.id))
            try repository.delete(ids: ids)
            sessions.removeAll { ids.contains($0.id) }
            summary = nil
            notice = ids.isEmpty ? "There is no completed history to delete." : "Completed Squats history was deleted."
        }
    }
}
