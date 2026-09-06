import UserNotifications
import CoreLocation
import UIKit

/// Sole owner of the process-wide delegate. Feature schedulers never replace it.
@MainActor final class AppNotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private let squats: SquatStore

    init(squats: SquatStore) {
        self.squats = squats
        super.init()
        UNUserNotificationCenter.current().delegate = self
        // This is the hub's complete category registry; add future feature categories here.
        UNUserNotificationCenter.current().setNotificationCategories([ReminderService.category()])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completion: @escaping () -> Void) {
        Task { @MainActor in
            defer { completion() }
            let notification = response.notification
            if let action = Self.action(request: notification.request, delivered: notification.date,
                                        identifier: response.actionIdentifier) {
                // receive persists to the inbox before any asynchronous service work or busy check.
                await squats.receive(action)
            }
        }
    }

    static func action(request: UNNotificationRequest, delivered: Date, identifier: String,
                       now: Date = Date()) -> SquatAction? {
        guard [ReminderService.regular, ReminderService.snooze].contains(request.identifier),
              request.content.categoryIdentifier == ReminderService.categoryID,
              let rawSession = request.content.userInfo["session"] as? String,
              let session = UUID(uuidString: rawSession) else { return nil }
        let kind: SquatAction.Kind
        switch identifier {
        case ReminderService.doneAction: kind = .done
        case ReminderService.pauseAction: kind = .pause
        case ReminderService.snoozeAction: kind = .snooze
        default: return nil // Opening/dismissing a notification is never a completed set.
        }
        return SquatAction(id: SquatAction.notificationID(session: session, request: request.identifier,
            delivered: delivered, action: identifier), sessionID: session, kind: kind,
            date: now, day: SquatSession.dayKey(now), source: "notification")
    }
}

/// Owns the second process-wide delegate used by the hub: one Squats Home region.
@MainActor final class HomeRegionService: NSObject, HomeRegionMonitoring, CLLocationManagerDelegate {
    var eventHandler: ((HomeBoundaryEvent) -> Void)?
    var failureHandler: ((String) -> Void)?
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<HomeAuthorization, Never>?
    private var locationContinuation: CheckedContinuation<(latitude: Double, longitude: Double), Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUse() async -> HomeAuthorization {
        let value = Self.authorization(manager.authorizationStatus)
        guard value == .notDetermined else { return value }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestAlways() async -> HomeAuthorization {
        let value = Self.authorization(manager.authorizationStatus)
        guard value == .whenInUse else { return value }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestAlwaysAuthorization()
        }
    }

    func currentLocation() async throws -> (latitude: Double, longitude: Double) {
        guard locationContinuation == nil else { throw HomeAutomationError.locationUnavailable }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func snapshot() -> HomeRegionSnapshot {
        let monitored = manager.monitoredRegions.first {
            $0.identifier == HomeAutomationState.regionIdentifier
        } as? CLCircularRegion
        let boundary = monitored.map {
            HomeBoundary(latitude: $0.center.latitude, longitude: $0.center.longitude, radius: $0.radius)
        }
        return HomeRegionSnapshot(authorization: Self.authorization(manager.authorizationStatus),
            monitoringAvailable: CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self),
            monitoredBoundary: boundary,
            backgroundAccess: Self.backgroundAccess(UIApplication.shared.backgroundRefreshStatus))
    }

    func startMonitoring(_ boundary: HomeBoundary) throws {
        let valid = try boundary.validated()
        let status = snapshot()
        guard status.authorization == .always else { throw HomeAutomationError.alwaysAccessRequired }
        guard status.monitoringAvailable else { throw HomeAutomationError.monitoringUnavailable }
        stopMonitoring()
        let radius = min(valid.radius, manager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: valid.latitude,
            longitude: valid.longitude), radius: radius, identifier: HomeAutomationState.regionIdentifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }

    func stopMonitoring() {
        for region in manager.monitoredRegions where region.identifier == HomeAutomationState.regionIdentifier {
            manager.stopMonitoring(for: region)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationContinuation?.resume(returning: Self.authorization(manager.authorizationStatus))
        authorizationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: (location.coordinate.latitude, location.coordinate.longitude))
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let continuation = locationContinuation {
            continuation.resume(throwing: error)
            locationContinuation = nil
        } else {
            failureHandler?(error.localizedDescription)
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        failureHandler?(error.localizedDescription)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) { emit(.entered, region: region) }
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) { emit(.exited, region: region) }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if state == .inside { emit(.stateInside, region: region) }
        if state == .outside { emit(.stateOutside, region: region) }
    }

    private func emit(_ kind: HomeBoundaryEvent.Kind, region: CLRegion) {
        guard region.identifier == HomeAutomationState.regionIdentifier else { return }
        eventHandler?(HomeBoundaryEvent(kind: kind, date: Date(), regionIdentifier: region.identifier))
    }

    private static func authorization(_ value: CLAuthorizationStatus) -> HomeAuthorization {
        switch value {
        case .authorizedAlways: return .always
        case .authorizedWhenInUse: return .whenInUse
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .restricted
        }
    }

    private static func backgroundAccess(_ value: UIBackgroundRefreshStatus) -> HomeBackgroundAccess {
        switch value {
        case .available: return .available
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
    }
}
