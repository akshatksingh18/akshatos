import UserNotifications

@MainActor protocol PersonalNotificationCenter {
    func authorization() async -> UNAuthorizationStatus
    func pending() async -> [UNNotificationRequest]
    func authorize() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func remove(_ identifiers: [String])
    func badge(_ count: Int) async throws
}

@MainActor struct SystemPersonalNotificationCenter: PersonalNotificationCenter {
    private let center = UNUserNotificationCenter.current()
    func authorization() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func authorize() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func remove(_ identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    func badge(_ count: Int) async throws { try await center.setBadgeCount(count) }
}
