import Foundation

/// Where the editable splits live. They are a short list of names and exercises, so they sit in
/// the app's preferences as one JSON value rather than in the workout database.
@MainActor protocol LiftSplitStoring {
    /// Nil when nothing has been saved yet, so a new install can start from the default splits.
    func load() throws -> [LiftSplit]?
    func save(_ splits: [LiftSplit]) throws
}

@MainActor final class DefaultsLiftSplitStorage: LiftSplitStoring {
    static let key = "liftlog.splits"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() throws -> [LiftSplit]? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try JSONDecoder().decode([LiftSplit].self, from: data)
    }

    func save(_ splits: [LiftSplit]) throws {
        defaults.set(try JSONEncoder().encode(splits), forKey: Self.key)
    }
}
