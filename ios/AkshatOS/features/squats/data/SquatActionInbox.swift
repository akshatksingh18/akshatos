import Foundation

@MainActor protocol SquatActionInbox {
    func pending() throws -> [SquatAction]
    func enqueue(_ action: SquatAction) throws
    func remove(_ id: String) throws
}

/// One process, serialized on the main actor. Atomic replacement preserves the old inbox on error.
@MainActor final class FileSquatActionInbox: SquatActionInbox {
    private struct Envelope: Codable {
        var version = 1
        var actions: [SquatAction] = []
    }
    let url: URL
    private let writeData: (Data, URL, Data.WritingOptions) throws -> Void

    init(url: URL? = nil, writeData: @escaping (Data, URL, Data.WritingOptions) throws -> Void = {
        try $0.write(to: $1, options: $2)
    }) {
        self.writeData = writeData
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory,
            in: .userDomainMask)[0].appendingPathComponent("squats-actions/inbox.json")
    }

    func pending() throws -> [SquatAction] {
        // Inaccessible protected files must not look like an empty inbox.
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return [] }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
        return envelope.actions
    }

    func enqueue(_ action: SquatAction) throws {
        var actions = try pending()
        guard !actions.contains(where: { $0.id == action.id }) else { return }
        actions.append(action)
        try write(actions)
    }

    func remove(_ id: String) throws {
        try write(pending().filter { $0.id != id })
    }

    private func write(_ actions: [SquatAction]) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        // Only command IDs, session IDs and timestamps, never Home coordinates.
        try writeData(JSONEncoder().encode(Envelope(actions: actions)), url,
            [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
