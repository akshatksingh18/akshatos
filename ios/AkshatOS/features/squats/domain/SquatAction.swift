import Foundation

struct SquatAction: Codable, Equatable {
    enum Kind: String, Codable { case done, pause, snooze }
    var id: String
    var eventID = UUID()
    var sessionID: UUID
    var kind: Kind
    var date: Date
    var day: String
    var source: String

    static func notificationID(session: UUID, request: String, delivered: Date, action: String) -> String {
        // A repeating request reuses its identifier. Each actual delivery must remain distinct.
        "\(session.uuidString)|\(request)|\(delivered.timeIntervalSince1970.bitPattern)|\(action)"
    }

    func canApply(to session: SquatSession) -> Bool {
        guard session.id == sessionID, session.isActive, date >= session.started,
              !(session.actionReceipts ?? []).contains(id) else { return false }
        if kind == .pause { return true }
        return day == session.day && (kind == .done || session.state == .running)
    }

    func applying(to original: SquatSession) -> SquatSession {
        var session = original
        guard canApply(to: session) else { return session }
        switch kind {
        case .done:
            session.log(SquatEvent(id: eventID, date: date, kind: .done, source: source))
        case .pause:
            if session.state == .running || session.pauseReason != source {
                session.log(SquatEvent(id: eventID, date: date, kind: .pause, source: source))
            }
            session.state = .paused
            session.pauseReason = source
        case .snooze:
            session.log(SquatEvent(id: eventID, date: date, kind: .snooze, source: source))
        }
        session.actionReceipts = (session.actionReceipts ?? []) + [id]
        return session
    }
}
