import Foundation

@MainActor protocol HomeRegionMonitoring: AnyObject {
    var eventHandler: ((HomeBoundaryEvent) -> Void)? { get set }
    var failureHandler: ((String) -> Void)? { get set }
    func requestWhenInUse() async -> HomeAuthorization
    func requestAlways() async -> HomeAuthorization
    func currentLocation() async throws -> (latitude: Double, longitude: Double)
    func snapshot() -> HomeRegionSnapshot
    func startMonitoring(_ boundary: HomeBoundary) throws
    func stopMonitoring()
}

/// Test/preview fallback; the app composition root injects the real process-wide adapter.
@MainActor final class InactiveHomeRegionMonitor: HomeRegionMonitoring {
    var eventHandler: ((HomeBoundaryEvent) -> Void)?
    var failureHandler: ((String) -> Void)?
    func requestWhenInUse() async -> HomeAuthorization { .restricted }
    func requestAlways() async -> HomeAuthorization { .restricted }
    func currentLocation() async throws -> (latitude: Double, longitude: Double) {
        throw HomeAutomationError.locationUnavailable
    }
    func snapshot() -> HomeRegionSnapshot {
        HomeRegionSnapshot(authorization: .restricted, monitoringAvailable: false,
                           monitoredBoundary: nil, backgroundAccess: .restricted)
    }
    func startMonitoring(_ boundary: HomeBoundary) throws { throw HomeAutomationError.monitoringUnavailable }
    func stopMonitoring() { }
}
