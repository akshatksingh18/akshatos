import XCTest
import SwiftData
import UserNotifications
@testable import AkshatOS

@MainActor private final class PersonalCenterFake: PersonalNotificationCenter {
    var allowed: UNAuthorizationStatus = .authorized
    var requests: [UNNotificationRequest] = []
    var removed: [String] = []
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
    func badge(_ count: Int) async throws { badgeCount = count }
}

@MainActor final class PersonalNotificationTests: XCTestCase {
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
            preferences.journalReminder = true
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
            center.requests = unrelated(3); center.failAdds = true; preferences.journalReminder = true
            let scheduler = PersonalNotifications(study: study, todo: todo, preferences: preferences, center: center)
            scheduler.reconcile(); await scheduler.waitUntilSettled()
            XCTAssertTrue(scheduler.status.contains("could not"))
            XCTAssertEqual(center.requests.count, 3); XCTAssertTrue(center.removed.isEmpty)
        }
    }
}
