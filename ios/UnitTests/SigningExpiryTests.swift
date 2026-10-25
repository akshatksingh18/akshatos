import XCTest
import UserNotifications
@testable import AkshatOS

@MainActor private final class SigningCenterFake: PersonalNotificationCenter {
    var allowed: UNAuthorizationStatus = .authorized
    var requests: [UNNotificationRequest] = []
    var removed: [String] = []
    var added: [UNNotificationRequest] = []
    var failAdds = false
    func authorization() async -> UNAuthorizationStatus { allowed }
    func pending() async -> [UNNotificationRequest] { requests }
    func authorize() async throws -> Bool { allowed == .authorized }
    func add(_ request: UNNotificationRequest) async throws {
        if failAdds { throw CocoaError(.fileWriteUnknown) }
        added.append(request); requests.removeAll { $0.identifier == request.identifier }; requests.append(request)
    }
    func remove(_ identifiers: [String]) { removed += identifiers; requests.removeAll { identifiers.contains($0.identifier) } }
    func removeDelivered(_ identifiers: [String]) {}
    func badge(_ count: Int) async throws {}
}

/// Builds a synthetic provisioning profile: a plain plist wrapped in the kind of surrounding bytes a
/// CMS container has, so the parser is exercised on something shaped like the real file rather than
/// on a bare plist it would never meet.
private func syntheticProfile(expiry: Date?, junkBefore: Int = 64, junkAfter: Int = 48) -> Data {
    var fields: [String: Any] = ["AppIDName": "AkshatOS", "TeamIdentifier": ["5564K8D4SV"]]
    if let expiry { fields["ExpirationDate"] = expiry }
    let plist = try! PropertyListSerialization.data(fromPropertyList: fields, format: .xml, options: 0)
    var data = Data((0..<junkBefore).map { UInt8($0 % 251) })
    data.append(plist)
    data.append(Data((0..<junkAfter).map { _ in UInt8.random(in: 0...255) }))
    return data
}

/// Signing is refreshed by something outside the app, and the Windows health check can only see
/// Sideloadly's own database. These cover the monitor that works whoever signed the build: it reads
/// the profile in its own bundle, reports an unknown expiry as unknown rather than healthy, and
/// never claims a watch it did not arm.
final class SigningExpiryDomainTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testReadsExpiryOutOfAProfileShapedContainer() {
        let expiry = now.addingTimeInterval(5 * 86_400)
        let read = SigningExpiry.expiryDate(inProfile: syntheticProfile(expiry: expiry))
        XCTAssertEqual(read?.timeIntervalSince1970 ?? 0, expiry.timeIntervalSince1970, accuracy: 1)
    }

    func testRubbishAndTruncatedProfilesYieldNoDateRatherThanAGuess() {
        XCTAssertNil(SigningExpiry.expiryDate(inProfile: Data("not a profile at all".utf8)))
        XCTAssertNil(SigningExpiry.expiryDate(inProfile: Data()))
        let truncated = syntheticProfile(expiry: now).prefix(70)
        XCTAssertNil(SigningExpiry.expiryDate(inProfile: Data(truncated)))
    }

    func testProfileWithoutAnExpirationDateIsUnknown() {
        let data = syntheticProfile(expiry: nil)
        XCTAssertNil(SigningExpiry.expiryDate(inProfile: data))
        XCTAssertEqual(SigningExpiry.state(expiry: nil, now: now), .unknown)
    }

    /// An absent profile must never read as healthy. It is the normal simulator case, so the
    /// temptation is to treat it as fine; an unknown expiry is not a safe one.
    func testUnknownIsNotTreatedAsHealthyAndDoesNotRaiseAnAlarm() {
        let state = SigningExpiry.state(expiry: nil, now: now)
        XCTAssertEqual(state, .unknown)
        XCTAssertFalse(state.needsAttention)
    }

    func testThresholdsMatchTheWindowsCheck() {
        func state(afterDays days: Double) -> SigningExpiry.State {
            SigningExpiry.state(expiry: now.addingTimeInterval(days * 86_400), now: now)
        }
        XCTAssertEqual(state(afterDays: 7), .valid(daysLeft: 7))
        XCTAssertEqual(state(afterDays: 4), .valid(daysLeft: 4))
        XCTAssertEqual(state(afterDays: 3.5), .warning(daysLeft: 3))
        XCTAssertEqual(state(afterDays: 3), .warning(daysLeft: 3))
        XCTAssertEqual(state(afterDays: 2), .critical(daysLeft: 2))
        XCTAssertEqual(state(afterDays: 0.5), .critical(daysLeft: 0))
        XCTAssertTrue(state(afterDays: 3).needsAttention)
        XCTAssertFalse(state(afterDays: 4).needsAttention)
    }

    /// Rounding down is deliberate: 2.9 days left is critical, not comfortable.
    func testDaysRoundDownSoTheAlarmIsNeverLate() {
        XCTAssertEqual(SigningExpiry.state(expiry: now.addingTimeInterval(2.9 * 86_400), now: now),
                       .critical(daysLeft: 2))
    }

    func testExpiredReportsHowLongAgoAndNeedsAttention() {
        let state = SigningExpiry.state(expiry: now.addingTimeInterval(-3.2 * 86_400), now: now)
        XCTAssertEqual(state, .expired(daysAgo: 3))
        XCTAssertTrue(state.needsAttention)
        XCTAssertEqual(SigningExpiry.state(expiry: now.addingTimeInterval(-60), now: now), .expired(daysAgo: 0))
    }

    func testWarningDatesSitBeforeExpiryAndDropAnyAlreadyPassed() {
        let expiry = now.addingTimeInterval(7 * 86_400)
        let dates = SigningExpiry.warningDates(expiry: expiry, now: now)
        XCTAssertEqual(dates.count, 2)
        XCTAssertTrue(dates.allSatisfy { $0 > now && $0 < expiry })
        // Inside the last day there is nothing useful left to schedule.
        XCTAssertTrue(SigningExpiry.warningDates(expiry: now.addingTimeInterval(3600), now: now).isEmpty)
        // Partway through, only the final call survives.
        XCTAssertEqual(SigningExpiry.warningDates(expiry: now.addingTimeInterval(2 * 86_400), now: now).count, 1)
    }
}

@MainActor final class SigningExpiryServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func service(_ center: SigningCenterFake, expiry: Date?) -> SigningExpiryService {
        SigningExpiryService(center: center, profileData: { expiry.map { syntheticProfile(expiry: $0) } })
    }

    func testArmsTwoWarningsAndNoMore() async {
        let center = SigningCenterFake()
        let subject = service(center, expiry: now.addingTimeInterval(7 * 86_400))
        await subject.refresh(now: now)
        XCTAssertEqual(center.added.count, 2)
        XCTAssertTrue(center.added.allSatisfy { $0.identifier.hasPrefix(SigningExpiryService.namespace) })
        XCTAssertEqual(subject.state, .valid(daysLeft: 7))
        XCTAssertFalse(subject.scheduleFailed)
    }

    /// Called on every foreground pass, so it must replace its own requests rather than pile up.
    func testRepeatedRefreshesReplaceRatherThanAccumulate() async {
        let center = SigningCenterFake()
        let subject = service(center, expiry: now.addingTimeInterval(7 * 86_400))
        for _ in 0..<4 { await subject.refresh(now: now) }
        XCTAssertEqual(center.requests.count, 2)
    }

    /// It must only ever touch its own namespace; other features' requests are not its business.
    func testLeavesOtherFeaturesRequestsAlone() async {
        let center = SigningCenterFake()
        let other = UNNotificationRequest(identifier: "akshatos.personal.study",
                                          content: UNMutableNotificationContent(), trigger: nil)
        center.requests = [other]
        let subject = service(center, expiry: now.addingTimeInterval(7 * 86_400))
        await subject.refresh(now: now)
        XCTAssertTrue(center.requests.contains { $0.identifier == other.identifier })
        XCTAssertFalse(center.removed.contains(other.identifier))
    }

    /// The warning must not be the thing that demands notification access.
    func testDeniedPermissionSchedulesNothingAndStillReportsTheState() async {
        let center = SigningCenterFake()
        center.allowed = .denied
        let subject = service(center, expiry: now.addingTimeInterval(2 * 86_400))
        await subject.refresh(now: now)
        XCTAssertTrue(center.added.isEmpty)
        XCTAssertEqual(subject.state, .critical(daysLeft: 2))
    }

    func testSchedulingFailureIsSurfacedRatherThanSwallowed() async {
        let center = SigningCenterFake()
        center.failAdds = true
        let subject = service(center, expiry: now.addingTimeInterval(7 * 86_400))
        await subject.refresh(now: now)
        XCTAssertTrue(subject.scheduleFailed, "a watch that could not be armed must not look armed")
    }

    func testNoProfileReportsUnknownAndArmsNothing() async {
        let center = SigningCenterFake()
        let subject = service(center, expiry: nil)
        await subject.refresh(now: now)
        XCTAssertEqual(subject.state, .unknown)
        XCTAssertTrue(center.added.isEmpty)
        XCTAssertEqual(subject.summary, "Not known on this install")
    }

    func testAlreadyExpiredArmsNothingButSaysSo() async {
        let center = SigningCenterFake()
        let subject = service(center, expiry: now.addingTimeInterval(-86_400))
        await subject.refresh(now: now)
        XCTAssertTrue(center.added.isEmpty)
        XCTAssertEqual(subject.state, .expired(daysAgo: 1))
        XCTAssertTrue(subject.state.needsAttention)
    }

    /// Warnings are informational; they must never interrupt a study block.
    func testWarningsArePassive() async {
        let center = SigningCenterFake()
        let subject = service(center, expiry: now.addingTimeInterval(7 * 86_400))
        await subject.refresh(now: now)
        XCTAssertTrue(center.added.allSatisfy { $0.content.interruptionLevel == .passive })
        XCTAssertTrue(center.added.allSatisfy { $0.content.sound == nil })
    }

    /// A tapped warning has to reach the backup screen, or the alert gives no way to act on it.
    func testNamespaceRoutesToTheBackupScreen() {
        let route = AppNotificationCoordinator.route(forNotification: SigningExpiryService.namespace + "warning")
        XCTAssertEqual(route, .backup)
    }
}
