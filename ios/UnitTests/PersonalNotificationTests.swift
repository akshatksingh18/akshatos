import XCTest
import SwiftData
import UserNotifications
@testable import AkshatOS

@MainActor private final class PersonalCenterFake: PersonalNotificationCenter {
    var allowed: UNAuthorizationStatus = .authorized
    var requests: [UNNotificationRequest] = []
    var removed: [String] = []
    var deliveredRemoved: [String] = []
    var added: [String] = []
    var failAdds = false
    var badgeCount = -1
    func authorization() async -> UNAuthorizationStatus { allowed }
    func pending() async -> [UNNotificationRequest] { requests }
    func authorize() async throws -> Bool { allowed == .authorized }
    func add(_ request: UNNotificationRequest) async throws {
        if failAdds { throw CocoaError(.fileWriteUnknown) }
        added.append(request.identifier); requests.removeAll { $0.identifier == request.identifier }; requests.append(request)
    }
    func remove(_ identifiers: [String]) { removed += identifiers; requests.removeAll { identifiers.contains($0.identifier) } }
    func removeDelivered(_ identifiers: [String]) { deliveredRemoved += identifiers }
    func badge(_ count: Int) async throws { badgeCount = count }
}

@MainActor final class PersonalNotificationTests: XCTestCase {
    func testForegroundStudyNotificationsNeverRequestBannersOrSound() {
        XCTAssertEqual(AppNotificationCoordinator.presentationOptions(studying: true), [.list])
        XCTAssertEqual(AppNotificationCoordinator.presentationOptions(studying: false), [.banner, .list, .sound])
    }
    func testTasksBecomePassiveDuringStudyAndRecoverAfterPause() async throws {
        try await withServices { study, todo, preferences, center in
            todo.save(TodoItem(title: "Synthetic timed task", due: Date().addingTimeInterval(3600), hasTime: true))
            XCTAssertEqual(todo.visible.count, 1)
            study.start()
            let scheduler = PersonalNotifications(study: study, todo: todo, preferences: preferences, center: center)
            scheduler.reconcile(); await scheduler.waitUntilSettled()
            XCTAssertEqual(center.requests.count, 1)
            XCTAssertTrue(center.requests.allSatisfy { $0.content.sound == nil && $0.content.interruptionLevel == .passive })
            XCTAssertTrue(study.isRunning)
            study.pause(); scheduler.reconcile(); await scheduler.waitUntilSettled()
            XCTAssertTrue(center.requests.allSatisfy { $0.content.sound != nil && $0.content.interruptionLevel == .active })
        }
    }
    private func memory(_ version: any VersionedSchema.Type) throws -> ModelContainer {
        let schema = Schema(versionedSchema: version)
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }
    private func withServices(_ body: (StudyLogStore, TodoStore, PersonalPreferences, PersonalCenterFake) async throws -> Void) async throws {
        let suite = "notification-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let study = StudyLogStore(repository: SwiftDataStudyLogRepository(container: try memory(StudyLogSchemaV1.self)), defaults: defaults); study.load()
        let todo = TodoStore(container: try memory(TodoSchemaV1.self)); todo.load()
        try await body(study, todo, PersonalPreferences(defaults: defaults), PersonalCenterFake())
    }
    private func unrelated(_ count: Int) -> [UNNotificationRequest] {
        (0..<count).map { UNNotificationRequest(identifier: "another-feature.\($0)", content: UNMutableNotificationContent(), trigger: nil) }
    }
    func testActualSharedCapacityPreservesUnrelatedRequestsAndReserve() async throws {
        try await withServices { study, todo, preferences, center in
            center.requests = unrelated(60)
            for index in 0..<8 { todo.save(TodoItem(title: "Synthetic \(index)", due: Date().addingTimeInterval(Double(index + 1) * 3600), hasTime: true)) }
            let scheduler = PersonalNotifications(study: study, todo: todo, preferences: preferences, center: center)
            scheduler.reconcile(); await scheduler.waitUntilSettled()
            XCTAssertEqual(center.added.count, 2, "Only the two remaining non-reserved slots are used")
            XCTAssertTrue(center.added.allSatisfy { $0.contains(".todo.") }, "Timed tasks retain priority")
            XCTAssertEqual(center.requests.filter { $0.identifier.hasPrefix("another-feature.") }.count, 60)
            XCTAssertTrue(center.removed.isEmpty)
        }
    }
    func testDeniedPermissionDoesNotReportScheduledSuccess() async throws {
        try await withServices { study, todo, preferences, center in
            center.allowed = .denied; center.requests = unrelated(2)
            let scheduler = PersonalNotifications(study: study, todo: todo, preferences: preferences, center: center)
            scheduler.reconcile(); await scheduler.waitUntilSettled()
            XCTAssertTrue(scheduler.status.contains("off"))
            XCTAssertTrue(center.added.isEmpty); XCTAssertEqual(center.requests.count, 2)
        }
    }
    func testProviderFailureIsVisibleAndDoesNotCancelOtherFeatures() async throws {
        try await withServices { study, todo, preferences, center in
            center.requests = unrelated(3); center.failAdds = true
            todo.save(TodoItem(title: "Synthetic timed task", due: Date().addingTimeInterval(3600), hasTime: true))
            let scheduler = PersonalNotifications(study: study, todo: todo, preferences: preferences, center: center)
            scheduler.reconcile(); await scheduler.waitUntilSettled()
            XCTAssertTrue(scheduler.status.contains("could not"))
            XCTAssertEqual(center.requests.count, 3); XCTAssertTrue(center.removed.isEmpty)
        }
    }
    func testRetiredJournalReminderIsRemovedEvenWithDeniedPermissionOrUnavailableData() async throws {
        for allowed in [UNAuthorizationStatus.authorized, .denied] {
            try await withServices { study, todo, preferences, center in
                let retiredID = PersonalNotifications.namespace + "journal"
                center.allowed = allowed
                center.requests = unrelated(2) + [UNNotificationRequest(identifier: retiredID, content: UNMutableNotificationContent(), trigger: nil)]
                preferences.journalReminder = true // An old preference must never recreate the request.
                let unopened = TodoStore(container: try memory(TodoSchemaV1.self))
                let scheduler = PersonalNotifications(study: study, todo: unopened, preferences: preferences, center: center)
                scheduler.reconcile(); await scheduler.waitUntilSettled()
                XCTAssertEqual(center.removed, [retiredID])
                XCTAssertEqual(center.deliveredRemoved, [retiredID])
                XCTAssertEqual(center.requests.count, 2)
                XCTAssertTrue(center.added.isEmpty)
                XCTAssertNil(AppNotificationCoordinator.route(forNotification: retiredID))
            }
        }
    }
}
