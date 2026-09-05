import Foundation

struct HomeBoundary: Codable, Equatable {
    static let defaultRadius = 150.0
    static let allowedRadius = 50.0...1_000.0

    var latitude: Double
    var longitude: Double
    var radius: Double

    func validated() throws -> HomeBoundary {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude),
              Self.allowedRadius.contains(radius) else { throw HomeAutomationError.invalidBoundary }
        return self
    }
}

enum HomePresence: String, Codable { case unknown, inside, outside }
enum HomeAuthorization: String, Codable { case notDetermined, whenInUse, always, denied, restricted }
enum HomeBackgroundAccess: String, Codable { case available, denied, restricted }

struct HomeRegionSnapshot: Equatable {
    var authorization: HomeAuthorization
    var monitoringAvailable: Bool
    var monitored: Bool
    var backgroundAccess: HomeBackgroundAccess
}

struct HomeBoundaryEvent: Codable, Equatable {
    enum Kind: String, Codable { case entered, exited, stateInside, stateOutside }
    var id = UUID().uuidString
    var kind: Kind
    var date: Date
    var regionIdentifier: String

    var presence: HomePresence {
        switch kind {
        case .entered, .stateInside: return .inside
        case .exited, .stateOutside: return .outside
        }
    }
}

enum HomeAutomationDecision: Equatable { case none, pause, resume }

struct HomeAutomationState: Codable, Equatable {
    static let regionIdentifier = "akshatos.squats.home"
    static let debounce: TimeInterval = 120

    var boundary: HomeBoundary
    var enabled = true
    var presence: HomePresence = .unknown
    var suppressExitUntilEntry = false
    var lastEventDate: Date?

    mutating func accept(_ event: HomeBoundaryEvent, activeDay: String?, activeState: SquatSession.State?,
                         pauseReason: String?, currentDay: String) -> HomeAutomationDecision {
        guard enabled, event.regionIdentifier == Self.regionIdentifier else { return .none }
        if event.presence == presence, let lastEventDate,
           abs(event.date.timeIntervalSince(lastEventDate)) < Self.debounce { return .none }
        presence = event.presence
        lastEventDate = event.date
        if event.presence == .inside {
            suppressExitUntilEntry = false
            return activeDay == currentDay && activeState == .paused &&
                pauseReason == "homeAwayAutomation" ? .resume : .none
        }
        return activeState == .running && !suppressExitUntilEntry ? .pause : .none
    }
}

enum HomeAutomationError: LocalizedError {
    case invalidBoundary, locationUnavailable, monitoringUnavailable, alwaysAccessRequired

    var errorDescription: String? {
        switch self {
        case .invalidBoundary: return "Choose a valid Home location and radius."
        case .locationUnavailable: return "Your current location is unavailable. Check Location Services and try again."
        case .monitoringUnavailable: return "Home region monitoring is unavailable on this device."
        case .alwaysAccessRequired: return "Always location access is required for Home auto-pause while AkshatOS is closed."
        }
    }
}
