import Foundation

@MainActor protocol HomeAutomationPersistence {
    func load() throws -> HomeAutomationState?
    func save(_ state: HomeAutomationState) throws
    func delete() throws
}

@MainActor protocol HomeEventInbox {
    func pending() throws -> [HomeBoundaryEvent]
    func enqueue(_ event: HomeBoundaryEvent) throws
    func remove(_ id: String) throws
}

@MainActor final class FileHomeAutomationPersistence: HomeAutomationPersistence {
    private struct Envelope: Codable { var version = 1; var state: HomeAutomationState }
    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory,
            in: .userDomainMask)[0].appendingPathComponent("squats-home/config.json")
    }

    func load() throws -> HomeAutomationState? {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
        _ = try envelope.state.boundary.validated()
        return envelope.state
    }

    func save(_ state: HomeAutomationState) throws {
        _ = try state.boundary.validated()
        try Self.prepare(url)
        try JSONEncoder().encode(Envelope(state: state)).write(to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    fileprivate static func prepare(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    }
}

@MainActor final class FileHomeEventInbox: HomeEventInbox {
    private struct Envelope: Codable { var version = 1; var events: [HomeBoundaryEvent] = [] }
    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory,
            in: .userDomainMask)[0].appendingPathComponent("squats-home/events.json")
    }

    func pending() throws -> [HomeBoundaryEvent] {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return [] }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
        return envelope.events
    }

    func enqueue(_ event: HomeBoundaryEvent) throws {
        var events = try pending()
        guard !events.contains(where: { $0.id == event.id }) else { return }
        events.append(event)
        try write(events)
    }

    func remove(_ id: String) throws { try write(pending().filter { $0.id != id }) }

    private func write(_ events: [HomeBoundaryEvent]) throws {
        try FileHomeAutomationPersistence.prepare(url)
        try JSONEncoder().encode(Envelope(events: events)).write(to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
