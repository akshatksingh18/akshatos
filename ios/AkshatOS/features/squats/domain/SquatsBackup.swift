import Foundation

struct SquatsBackup: Codable, Equatable {
    struct Settings: Codable, Equatable {
        let interval: Int
        let goal: Int
    }

    static let currentVersion = 1
    let version: Int
    let createdAt: Date
    var sessions: [SquatSession]
    let settings: Settings

    init(createdAt: Date = Date(), sessions: [SquatSession], interval: Int, goal: Int) {
        version = Self.currentVersion
        self.createdAt = createdAt
        self.sessions = sessions
        settings = Settings(interval: interval, goal: goal)
    }

    func validated() throws -> SquatsBackup {
        guard version == Self.currentVersion else { throw SquatsBackupError.unsupportedVersion(version) }
        guard (1...180).contains(settings.interval), (0...100).contains(settings.goal) else {
            throw SquatsBackupError.invalidSettings
        }
        guard Set(sessions.map(\.id)).count == sessions.count,
              sessions.filter(\.isActive).count <= 1 else { throw SquatsBackupError.invalidSessions }
        for session in sessions {
            guard Self.validDay(session.day), (1...180).contains(session.interval),
                  session.goal.map({ (1...100).contains($0) }) ?? true,
                  Set(session.events.map(\.id)).count == session.events.count,
                  Set(session.actionReceipts ?? []).count == (session.actionReceipts ?? []).count else {
                throw SquatsBackupError.invalidSessions
            }
            if session.state == .ended {
                guard let ended = session.ended, ended >= session.started else {
                    throw SquatsBackupError.invalidSessions
                }
            } else if session.ended != nil {
                throw SquatsBackupError.invalidSessions
            }
        }
        return self
    }

    func encoded() throws -> Data {
        _ = try validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> SquatsBackup {
        guard data.count <= 25_000_000 else { throw SquatsBackupError.tooLarge }
        do { return try JSONDecoder().decode(SquatsBackup.self, from: data).validated() }
        catch let error as SquatsBackupError { throw error }
        catch { throw SquatsBackupError.invalidFile }
    }

    private static func validDay(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value).map { formatter.string(from: $0) == value } ?? false
    }
}

enum SquatsBackupError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case invalidSettings
    case invalidSessions
    case invalidFile
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): return "This backup uses unsupported version \(version)."
        case .invalidSettings: return "The backup contains invalid Squats settings."
        case .invalidSessions: return "The backup contains inconsistent Squats history."
        case .invalidFile: return "This is not a valid Squats backup."
        case .tooLarge: return "This backup is too large to import."
        }
    }
}
