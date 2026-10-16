import ActivityKit
import Combine
import UIKit

struct StudyActivityHandle: Equatable {
    let id: String
    let sessionID: UUID
    let createdAt: Date
}

@MainActor protocol StudyActivityClient {
    var allowed: Bool { get }
    var activities: [StudyActivityHandle] { get }
    func start(sessionID: UUID, state: StudyActivityAttributes.ContentState) throws
    func update(_ handle: StudyActivityHandle, state: StudyActivityAttributes.ContentState) async
    func end(_ handle: StudyActivityHandle) async
}

@MainActor final class SystemStudyActivityClient: StudyActivityClient {
    var allowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    var activities: [StudyActivityHandle] {
        Activity<StudyActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
            .map { StudyActivityHandle(id: $0.id, sessionID: $0.attributes.sessionID, createdAt: $0.attributes.createdAt) }
    }
    func start(sessionID: UUID, state: StudyActivityAttributes.ContentState) throws {
        _ = try Activity.request(attributes: StudyActivityAttributes(sessionID: sessionID, createdAt: state.anchor),
            content: ActivityContent(state: state, staleDate: state.validUntil), pushType: nil)
    }
    func update(_ handle: StudyActivityHandle, state: StudyActivityAttributes.ContentState) async {
        guard let activity = Activity<StudyActivityAttributes>.activities.first(where: { $0.id == handle.id }) else { return }
        // No alert configuration, remote pushes, sound or attempt to break through Do Not Disturb.
        await activity.update(ActivityContent(state: state, staleDate: state.validUntil))
    }
    func end(_ handle: StudyActivityHandle) async {
        guard let activity = Activity<StudyActivityAttributes>.activities.first(where: { $0.id == handle.id }) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}

/// A failed, hidden or dismissed Live Activity must never change the authoritative study record.
@MainActor final class StudyLiveActivityCoordinator: ObservableObject {
    @Published private(set) var status = ""
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Self.preferenceKey); reconcile() }
    }
    let configured: Bool
    private static let preferenceKey = "study.live-activity-enabled"
    private static let lastShownKey = "study.live-activity-last-shown-session"
    private let study: StudyLogStore
    private let defaults: UserDefaults
    private let client: any StudyActivityClient
    private let isForeground: () -> Bool
    private var revision = 0
    private var worker: Task<Void, Never>?
    private var suppressedSession: UUID?
    private var lastShownSession: UUID?

    init(study: StudyLogStore, defaults: UserDefaults = .standard,
         configured: Bool = Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool == true,
         client: (any StudyActivityClient)? = nil,
         isForeground: @escaping () -> Bool = { UIApplication.shared.applicationState == .active }) {
        self.study = study; self.defaults = defaults; self.configured = configured
        self.client = client ?? SystemStudyActivityClient(); self.isForeground = isForeground
        enabled = defaults.bool(forKey: Self.preferenceKey)
        lastShownSession = defaults.string(forKey: Self.lastShownKey).flatMap(UUID.init(uuidString:))
    }

    func reconcile() {
        revision += 1
        guard worker == nil else { return }
        worker = Task { @MainActor in
            var processed: Int
            repeat {
                processed = revision
                await synchronize()
            } while processed != revision
            worker = nil
        }
    }

    func waitForPendingUpdates() async { await worker?.value }

    /// An explicit tap may restore a dismissed card; normal foreground reconciliation must not.
    func showAgain() { suppressedSession = nil; remember(nil); reconcile() }

    private func remember(_ session: UUID?) {
        lastShownSession = session
        defaults.set(session?.uuidString, forKey: Self.lastShownKey)
    }

    private func synchronize() async {
        guard configured else { status = "Available in the Live Activity build."; return }
        let running = study.storageAvailable && enabled ? study.log.running : nil
        var matching: StudyActivityHandle?
        for handle in client.activities {
            if let running, handle.sessionID == running.id, matching == nil {
                matching = handle
            } else { await client.end(handle) }
        }
        guard let running else {
            status = enabled ? "Starts with your next study block." : "Off"
            remember(nil); suppressedSession = nil
            return
        }
        guard client.allowed else {
            status = "Live Activities are unavailable or disabled in iPhone Settings. Study recording continues."
            return
        }
        let now = study.currentDate()
        let day = study.clock.key(for: now)
        guard let next = study.clock.next(day), let boundary = study.clock.start(of: next) else {
            status = "Could not determine the study day. Study recording continues."
            return
        }
        let createdAt = matching?.createdAt ?? now
        let deadline = min(boundary, createdAt.addingTimeInterval(8 * 3600))
        if matching != nil && deadline <= now {
            if let matching { await client.end(matching) }
            status = "The lock-screen timer reached its time limit. Tap Show again to renew it."
            suppressedSession = running.id
            return
        }
        let state = StudyActivityAttributes.ContentState(anchor: now,
            studiedAtAnchor: study.studiedToday(at: now), target: study.targetToday(at: now), validUntil: deadline)
        if let matching {
            await client.update(matching, state: state)
            remember(running.id)
            status = "Requested on the Lock Screen. iOS controls visibility."
        } else {
            if lastShownSession == running.id { suppressedSession = running.id }
            guard suppressedSession != running.id else {
                status = "Hidden or ended by iOS. Tap Show again to request it."
                return
            }
            guard isForeground() else {
                status = "Open AkshatOS to show the lock-screen timer. Study recording continues."
                return
            }
            do {
                try client.start(sessionID: running.id, state: state)
                remember(running.id)
                status = "Requested on the Lock Screen. iOS controls visibility."
            } catch {
                status = "The lock-screen timer could not start. Study recording continues. Try Show again."
                suppressedSession = running.id
            }
        }
    }
}
