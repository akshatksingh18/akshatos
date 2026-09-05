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
    @Published private(set) var notificationAuthorization: NotificationAuthorization = .notDetermined
    @Published private(set) var notificationEverAuthorized: Bool
    @Published var message: String?
    @Published var messageRoute: SettingsRoute?
    @Published var notice: String?
    @Published var summary: SquatDaySummary?
    @Published private(set) var homeState: HomeAutomationState?
    @Published private(set) var homeDraft: HomeBoundary?
    @Published private(set) var homeHealth = "Off"
    @Published private(set) var homeAuthorization: HomeAuthorization = .notDetermined
    @Published private(set) var homeEverAuthorized: Bool
    @Published var interval: Int { didSet { defaults.set(interval, forKey: "squats.interval") } }
    @Published var goal: Int { didSet { defaults.set(goal, forKey: "squats.goal") } }
    private let defaults: UserDefaults
    private let repository: any SquatRepository
    private let reminders: any SquatReminders
    private let inbox: any SquatActionInbox
    private let homePersistence: any HomeAutomationPersistence
    private let homeInbox: any HomeEventInbox
    private let homeMonitor: any HomeRegionMonitoring
    private let now: () -> Date
    private let calendar: Calendar
    private var actionRevision = 0
    private var homeDataAvailable = true
    var active: SquatSession? { sessions.first { $0.isActive } }
    var today: [SquatSession] { sessions.filter { $0.day == SquatSession.dayKey(now(), calendar: calendar) } }
    var todayCount: Int { today.reduce(0) { $0 + $1.count } }
    var todayGoal: Int? {
        if let first = today.sorted(by: { $0.started < $1.started }).first { return first.goal }
        return goal > 0 ? goal : nil
    }
    var staleDay: Bool { active.map { $0.day != SquatSession.dayKey(now(), calendar: calendar) } ?? false }
    var homeEnabled: Bool { homeState?.enabled == true }
    var homePresence: HomePresence { homeState?.presence ?? .unknown }
    var shouldOfferOutsideStart: Bool { homeEnabled && homePresence == .outside }
    var streaks: (current: Int, best: Int) { SquatSession.streaks(sessions, now: now(), calendar: calendar) }
    var daySummaries: [SquatDaySummary] {
        Set(sessions.map(\.day)).compactMap { day in
            SquatDaySummary.make(day: day, sessions: sessions, now: now(), calendar: calendar)
        }.sorted { $0.day > $1.day }
    }

    init(defaults: UserDefaults = .standard, repository: (any SquatRepository)? = nil,
         reminders: (any SquatReminders)? = nil, inbox: (any SquatActionInbox)? = nil,
         homePersistence: (any HomeAutomationPersistence)? = nil,
         homeInbox: (any HomeEventInbox)? = nil,
         homeMonitor: (any HomeRegionMonitoring)? = nil,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.defaults = defaults
        self.repository = repository ?? SwiftDataSquatRepository()
        self.reminders = reminders ?? ReminderService()
        self.inbox = inbox ?? FileSquatActionInbox()
        self.homePersistence = homePersistence ?? FileHomeAutomationPersistence()
        self.homeInbox = homeInbox ?? FileHomeEventInbox()
        self.homeMonitor = homeMonitor ?? InactiveHomeRegionMonitor()
        self.now = now
        self.calendar = calendar
        interval = max(1, min(180, defaults.object(forKey: "squats.interval") as? Int ?? 45))
        goal = max(0, min(100, defaults.integer(forKey: "squats.goal")))
        // Canonicalize old/corrupt idle preferences so every subsequent launch sees the repaired values.
        defaults.set(interval, forKey: "squats.interval")
        defaults.set(goal, forKey: "squats.goal")
        notificationEverAuthorized = defaults.bool(forKey: "squats.notificationEverAuthorized")
        homeEverAuthorized = defaults.bool(forKey: "squats.homeEverAuthorized")
        load()
        loadHome()
        self.homeMonitor.eventHandler = { [weak self] event in
            Task { @MainActor in await self?.receive(event) }
        }
        self.homeMonitor.failureHandler = { [weak self] detail in
            self?.homeHealth = "Region monitoring failed"
            self?.message = "Home auto-pause is degraded: \(detail). Manual reminder controls still work."
            self?.messageRoute = nil
        }
    }

    /// Distinguishes denied (user can fix in Settings) from restricted (parental controls/
    /// management profile; Settings cannot help) and, once granted at least once, phrases a later
    /// denial as a revocation rather than reusing first-request wording.
    private func homeAccessHealth(_ authorization: HomeAuthorization) -> String {
        switch authorization {
        case .denied: return homeEverAuthorized ? "Location access turned off" : "Location access denied"
        case .restricted: return "Location access restricted"
        case .notDetermined: return "Location access needed"
        case .whenInUse: return "Always access needed"
        case .always: return "Location access ready"
        }
    }

    private func markNotificationAuthorized() {
        guard !notificationEverAuthorized else { return }
        notificationEverAuthorized = true
        defaults.set(true, forKey: "squats.notificationEverAuthorized")
    }

    private func markHomeAuthorized() {
        guard !homeEverAuthorized else { return }
        homeEverAuthorized = true
        defaults.set(true, forKey: "squats.homeEverAuthorized")
    }

    private func rememberNotificationAuthorization(_ authorization: NotificationAuthorization) {
        if authorization == .authorized || authorization == .provisional || authorization == .ephemeral {
            markNotificationAuthorized()
        }
    }

    private func rememberHomeAuthorization(_ authorization: HomeAuthorization) {
        if authorization == .whenInUse || authorization == .always { markHomeAuthorized() }
    }

    private func load() {
        do {
            sessions = try repository.load()
            storageAvailable = true
        } catch {
            storageAvailable = false
            operational = "Storage unavailable"
            message = "Your local data could not be opened. Nothing was erased. Unlock your phone and return to retry; keep the app installed."
            messageRoute = nil
        }
    }

    private func loadHome() {
        do {
            homeState = try homePersistence.load()
            homeDataAvailable = true
        }
        catch {
            homeState = nil
            homeDataAvailable = false
            homeHealth = "Home data unavailable"
            message = "Home auto-pause data could not be opened. Unlock your phone and return to retry."
            messageRoute = nil
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
            messageRoute = nil
            return
        }
        await refresh()
    }

    /// Region callbacks are persisted before session data is touched so protected-data launches replay safely.
    func receive(_ event: HomeBoundaryEvent) async {
        do {
            try homeInbox.enqueue(event)
            actionRevision += 1
        } catch {
            message = "A Home boundary event could not be saved. Open Squats after unlocking to reconcile it."
            messageRoute = nil
            if event.presence == .outside { reminders.cancel() }
            return
        }
        await refresh()
    }

    func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if !storageAvailable { load() }
        if !homeDataAvailable { loadHome() }
        await settle()
    }

    private func settle() async {
        // A response can arrive during the final settings/request await, not just scheduling.
        // Repeat only for newly received work; a persistent storage error never spins a retry loop.
        var observed: Int
        repeat {
            observed = actionRevision
            do { try await drainInbox() } catch { actionFailure(error) }
            do { try await drainHomeInbox() } catch { homeFailure(error) }
            await reconcile()
            await reconcileHomeMonitoring()
        } while observed != actionRevision
    }

    private func drainHomeInbox() async throws {
        while let event = try homeInbox.pending().first {
            guard storageAvailable, homeDataAvailable else { return }
            guard var state = homeState else {
                // A callback racing with Disable must not become a permanent pending event.
                try homeInbox.remove(event.id)
                continue
            }
            let currentDay = SquatSession.dayKey(now(), calendar: calendar)
            let decision = state.accept(event, activeDay: active?.day, activeState: active?.state,
                                        pauseReason: active?.pauseReason, currentDay: currentDay)
            switch decision {
            case .none: break
            case .pause:
                guard let session = active else { break }
                reminders.cancel()
                let action = SquatAction(id: event.id, sessionID: session.id, kind: .pause,
                    date: event.date, day: currentDay, source: "homeAwayAutomation")
                try save(action.applying(to: session))
                notice = "Reminders paused because you left Home."
            case .resume:
                try await resumeFromHome(event)
            }
            // Commit observed Home state only after the matching session transition succeeds.
            // If either write fails, the durable event safely replays against its action receipt/state.
            try homePersistence.save(state)
            homeState = state
            try homeInbox.remove(event.id)
        }
    }

    private func resumeFromHome(_ event: HomeBoundaryEvent) async throws {
        guard var session = active, session.day == SquatSession.dayKey(now(), calendar: calendar),
              session.state == .paused, session.pauseReason == "homeAwayAutomation" else { return }
        let snapshot = await reminders.snapshot()
        guard snapshot.allowed else {
            homeHealth = "Needs notification access"
            return
        }
        reminders.cancel()
        try await reminders.schedule(session, snoozeUntil: nil)
        session.state = .running
        session.pauseReason = nil
        session.log(SquatEvent(date: event.date, kind: .resume, source: "homeAwayAutomation"))
        do { try save(session) } catch { reminders.cancel(); throw error }
        notice = "You arrived Home, so reminders resumed."
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
                messageRoute = nil
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
        notificationAuthorization = snapshot.authorization
        rememberNotificationAuthorization(snapshot.authorization)
        guard let session = active else {
            reminders.cancel()
            operational = today.isEmpty ? "Ready" : "Day complete"
            return
        }
        guard session.state == .running else { reminders.cancel(); operational = "Paused"; return }
        guard snapshot.allowed else {
            if snapshot.hasSnooze { reminders.cancelSnooze() }
            operational = "Notifications blocked"
            return
        }
        guard snapshot.sessionID == session.id,
              snapshot.interval == TimeInterval(session.interval * 60), snapshot.actionable,
              snapshot.next != nil else {
            if snapshot.hasSnooze { reminders.cancelSnooze() }
            operational = "Reminder needs repair"
            return
        }
        nextReminder = snapshot.next
        if snapshot.hasSnooze {
            if snapshot.snoozeSessionID == session.id, snapshot.snoozeActionable,
               let snooze = snapshot.snooze, snooze > now() {
                snoozeReminder = snooze
            } else {
                reminders.cancelSnooze()
            }
        }
        operational = "Running"
    }

    private func actionFailure(_ error: Error) {
        message = "Could not complete that action: \(error.localizedDescription). Saved history and queued notification actions were kept. Unlock and return to retry."
        messageRoute = nil
    }

    private func homeFailure(_ error: Error) {
        homeHealth = "Needs attention"
        message = "Home auto-pause needs attention: \(error.localizedDescription). Manual reminder controls still work."
        messageRoute = nil
    }

    private func reconcileHomeMonitoring() async {
        guard var state = homeState, state.enabled else {
            homeHealth = "Off"
            return
        }
        let snapshot = homeMonitor.snapshot()
        homeAuthorization = snapshot.authorization
        rememberHomeAuthorization(snapshot.authorization)
        guard snapshot.authorization == .always else {
            homeMonitor.stopMonitoring()
            homeHealth = homeAccessHealth(snapshot.authorization)
            return
        }
        guard snapshot.monitoringAvailable else {
            homeHealth = "Region monitoring unavailable"
            return
        }
        guard snapshot.backgroundAccess == .available else {
            homeHealth = "Background refresh restricted"
            return
        }
        do {
            if snapshot.monitoredBoundary.map({ state.boundary.matches($0) }) != true {
                // A missing or changed system registration invalidates the last observed presence.
                // Persist Unknown before re-registering so a failed repair never looks healthy.
                state.presence = .unknown
                state.lastEventDate = nil
                try homePersistence.save(state)
                homeState = state
                try homeMonitor.startMonitoring(state.boundary)
                homeHealth = "Checking Home boundary"
                return
            }
            homeHealth = state.presence == .unknown ? "Checking Home boundary" :
                (state.presence == .inside ? "At Home" : "Away from Home")
            if state.presence == .inside, active?.state == .paused,
               active?.pauseReason == "homeAwayAutomation",
               active?.day == SquatSession.dayKey(now(), calendar: calendar) {
                try? await resumeFromHome(HomeBoundaryEvent(kind: .stateInside, date: now(),
                    regionIdentifier: HomeAutomationState.regionIdentifier))
            }
        } catch { homeHealth = "Needs attention" }
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if !storageAvailable { load() }
        if !homeDataAvailable { loadHome() }
        do {
            try await drainInbox()
            try await drainHomeInbox()
            guard storageAvailable else { return }
            try await operation()
        } catch { actionFailure(error) }
        await settle()
    }

    func start(pausedForHome: Bool = false) async {
        await perform {
            guard active == nil, (1...180).contains(interval) else { return }
            guard try await reminders.authorize() else {
                message = notificationEverAuthorized
                    ? "Notifications were turned off. Allow them again in iOS Settings before starting your day."
                    : "Allow notifications in iOS Settings before starting your day."
                messageRoute = .notifications
                return
            }
            let first = today.sorted { $0.started < $1.started }.first
            let snapshot = first != nil ? first!.goal : (goal > 0 ? goal : nil)
            var session = SquatSession(day: SquatSession.dayKey(now(), calendar: calendar), started: now(),
                                       interval: interval, goal: snapshot)
            if shouldOfferOutsideStart {
                if pausedForHome {
                    session.pauseReason = "homeAwayAutomation"
                    session.log(SquatEvent(date: now(), kind: .pause, source: "homeAwayAutomation"))
                } else if var state = homeState {
                    state.suppressExitUntilEntry = true
                    try homePersistence.save(state)
                    homeState = state
                }
            }
            try save(session)
            reminders.cancel()
            if pausedForHome { return }
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
                message = notificationEverAuthorized
                    ? "Notifications were turned off while paused. Allow them again in iOS Settings to resume."
                    : "Notifications are disabled. Enable them in iOS Settings."
                messageRoute = .notifications
                return
            }
            if var state = homeState, state.enabled, state.presence == .outside {
                state.suppressExitUntilEntry = true
                try homePersistence.save(state)
                homeState = state
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
            if var state = homeState, state.suppressExitUntilEntry {
                state.suppressExitUntilEntry = false
                try homePersistence.save(state)
                homeState = state
            }
            summary = daySummary(for: session.day)
        }
    }

    func chooseCurrentLocationAsHome() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let authorization = await homeMonitor.requestWhenInUse()
        homeAuthorization = authorization
        rememberHomeAuthorization(authorization)
        guard authorization == .whenInUse || authorization == .always else {
            homeHealth = homeAccessHealth(authorization)
            message = "Allow location access while using AkshatOS so you can choose and confirm Home."
            messageRoute = .location
            return
        }
        do {
            let location = try await homeMonitor.currentLocation()
            homeDraft = try HomeBoundary(latitude: location.latitude, longitude: location.longitude,
                radius: homeState?.boundary.radius ?? HomeBoundary.defaultRadius).validated()
            homeHealth = "Confirm Home boundary"
        } catch { homeFailure(error) }
    }

    func updateHomeDraftRadius(_ radius: Double) {
        guard var draft = homeDraft else { return }
        draft.radius = min(max(radius, HomeBoundary.allowedRadius.lowerBound), HomeBoundary.allowedRadius.upperBound)
        homeDraft = draft
    }

    func cancelHomeDraft() { homeDraft = nil }

    func confirmHome() async {
        guard !busy, let boundary = homeDraft else { return }
        busy = true
        defer { busy = false }
        do {
            let state = HomeAutomationState(boundary: try boundary.validated())
            try homePersistence.save(state)
            homeState = state
            homeDraft = nil
            let authorization = await homeMonitor.requestAlways()
            homeAuthorization = authorization
            rememberHomeAuthorization(authorization)
            guard authorization == .always else {
                homeHealth = homeAccessHealth(authorization)
                message = "Home is saved, but Always location access is required for automatic boundary events. You can enable it in iOS Settings."
                messageRoute = .location
                return
            }
            try homeMonitor.startMonitoring(state.boundary)
            await reconcileHomeMonitoring()
            notice = "Home auto-pause is on. AkshatOS stores only this boundary, never a movement trail."
        } catch { homeFailure(error) }
    }

    func editHome() async { await chooseCurrentLocationAsHome() }

    func disableHome() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        homeMonitor.stopMonitoring()
        do {
            try homePersistence.delete()
            homeState = nil
            homeDraft = nil
            homeHealth = "Off"
            if var session = active, session.state == .paused,
               session.pauseReason == "homeAwayAutomation" {
                session.pauseReason = "homeAutomationDisabled"
                try save(session)
            }
            for event in (try? homeInbox.pending()) ?? [] { try? homeInbox.remove(event.id) }
            notice = "Home auto-pause is off and the saved Home boundary was deleted."
        } catch { homeFailure(error) }
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
