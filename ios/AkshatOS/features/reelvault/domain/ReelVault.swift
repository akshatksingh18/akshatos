import Foundation

/// One of Akshat's own videos, copied into the app, with the headline shown over it.
struct ReelVideo: Codable, Identifiable, Equatable {
    var id: UUID
    /// The app's copy inside the media folder, `<uuid>.<extension>`.
    var fileName: String
    /// Shown over the video. Empty until he writes one.
    var headline: String
    var importedAt: Date
    /// Seconds.
    var duration: Double
    var byteCount: Int64
    /// Lowercase SHA-256 of the file, which is how the same video is recognised again.
    var fingerprint: String
}

enum ReelVaultError: LocalizedError, Equatable {
    case notAVideo
    case duplicate
    case storage(String)
    case emptyLibrary
    case notABackup
    case unsupportedVersion
    case invalidBackup(String)
    case missingVideo(String)
    case damagedVideo(String)
    case nothingToRestore

    var errorDescription: String? {
        switch self {
        case .notAVideo: return "That file is not a video this iPhone can play."
        case .duplicate: return "That video is already in ReelVault."
        case .storage(let reason): return "The video could not be saved: \(reason)."
        case .emptyLibrary: return "There are no videos to back up yet."
        case .notABackup: return "That is not a ReelVault backup. Pick the folder that holds reelvault.json."
        case .unsupportedVersion: return "That backup was made by a newer AkshatOS. Update the app first."
        case .invalidBackup(let reason): return "That ReelVault backup is damaged: \(reason)."
        case .missingVideo(let name): return "The backup is missing the video \"\(name)\"."
        case .damagedVideo(let name): return "The video \"\(name)\" in the backup is damaged, so nothing was restored."
        case .nothingToRestore: return "Everything in that backup is already in ReelVault."
        }
    }
}

enum ReelVault {
    static let maximumHeadlineLength = 140
    /// Containers iOS plays. Anything else is still tried, under a `.mov` name.
    static let knownExtensions = ["mp4", "mov", "m4v"]

    /// A headline as stored: one line, trimmed, at most 140 characters.
    static func headline(_ raw: String) -> String {
        let oneLine = raw.split(whereSeparator: \.isNewline).joined(separator: " ")
        let collapsed = oneLine.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return String(collapsed.prefix(maximumHeadlineLength))
    }

    /// The extension the app's copy gets, from the picked file's name.
    static func fileExtension(for name: String) -> String {
        let parts = name.split(separator: ".")
        guard parts.count > 1, let last = parts.last?.lowercased(), knownExtensions.contains(last) else {
            return "mov"
        }
        return last
    }

    static func isFingerprint(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }

    /// One plain name inside the media folder: `<something>.<known extension>`, no path parts.
    static func isSafeFileName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/"), !name.contains("\\") else { return false }
        let parts = name.split(separator: ".")
        return parts.count == 2 && knownExtensions.contains(String(parts[1]))
    }

    /// The library, or a backup's list, checked as a whole.
    static func validated(_ videos: [ReelVideo]) throws -> [ReelVideo] {
        guard Set(videos.map(\.id)).count == videos.count else { throw ReelVaultError.invalidBackup("duplicate videos") }
        guard Set(videos.map(\.fingerprint)).count == videos.count else {
            throw ReelVaultError.invalidBackup("the same video twice")
        }
        guard Set(videos.map(\.fileName)).count == videos.count else {
            throw ReelVaultError.invalidBackup("two videos share a file")
        }
        for video in videos {
            guard isSafeFileName(video.fileName) else { throw ReelVaultError.invalidBackup("an unsafe file name") }
            guard isFingerprint(video.fingerprint) else { throw ReelVaultError.invalidBackup("a bad checksum") }
            guard video.byteCount > 0, video.duration.isFinite, video.duration > 0 else {
                throw ReelVaultError.invalidBackup("an impossible size or length")
            }
            guard video.headline == headline(video.headline) else {
                throw ReelVaultError.invalidBackup("a headline that is too long")
            }
        }
        return videos
    }

    /// `0:42`, `12:05`, `1:02:09`.
    static func durationText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600, minutes = (total % 3600) / 60, rest = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest)
                         : String(format: "%d:%02d", minutes, rest)
    }
}

/// The order videos come up in the feed. Every video plays once before any plays again, and the
/// last video of one round is never the first of the next, so nothing shows twice in a row unless
/// it is the only video. This is deliberately not a random pick each swipe, which is what makes
/// the same video keep turning up.
struct ReelShuffleBag: Equatable {
    private(set) var queue: [UUID] = []
    private(set) var played: Set<UUID> = []
    private(set) var last: UUID?

    /// The next video from `ids`, the library as it is now. A video added during a round joins
    /// that round at a random place; one removed drops out of it.
    mutating func next<Generator: RandomNumberGenerator>(from ids: [UUID],
                                                         using generator: inout Generator) -> UUID? {
        let present = Set(ids)
        queue.removeAll { !present.contains($0) }
        played.formIntersection(present)
        guard !ids.isEmpty else {
            queue = []
            return nil
        }
        for id in ids where !played.contains(id) && !queue.contains(id) {
            queue.insert(id, at: Int.random(in: 0...queue.count, using: &generator))
        }
        if queue.isEmpty {
            played = []
            queue = ids.shuffled(using: &generator)
        }
        if queue.count > 1, queue[0] == last {
            queue.swapAt(0, Int.random(in: 1..<queue.count, using: &generator))
        }
        let id = queue.removeFirst()
        played.insert(id)
        last = id
        return id
    }

    mutating func next(from ids: [UUID]) -> UUID? {
        var generator = SystemRandomNumberGenerator()
        return next(from: ids, using: &generator)
    }
}

/// A full ReelVault backup: this manifest beside a folder holding every video file.
struct ReelVaultBackup: Codable, Equatable {
    static let currentVersion = 1
    static let manifestName = "reelvault.json"
    static let mediaFolder = "videos"

    var version: Int
    var createdAt: Date
    var videos: [ReelVideo]

    init(createdAt: Date, videos: [ReelVideo]) {
        version = Self.currentVersion
        self.createdAt = createdAt
        self.videos = videos
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Reads the version first, so a newer backup is reported as newer rather than as damaged.
    static func decode(_ data: Data) throws -> ReelVaultBackup {
        struct Header: Decodable { var version: Int? }
        guard let version = (try? JSONDecoder().decode(Header.self, from: data))?.version, version >= 1 else {
            throw ReelVaultError.notABackup
        }
        guard version <= currentVersion else { throw ReelVaultError.unsupportedVersion }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(ReelVaultBackup.self, from: data) else {
            throw ReelVaultError.notABackup
        }
        _ = try ReelVault.validated(backup.videos)
        return backup
    }
}

/// What restoring a backup into the current library would do. A video is recognised by its
/// fingerprint, never its name: one already here only takes the backup's headline, the rest are added.
struct ReelRestorePlan: Equatable {
    struct HeadlineChange: Equatable {
        var id: UUID
        var headline: String
    }

    var additions: [ReelVideo]
    var headlineChanges: [HeadlineChange]

    var hasWork: Bool { !additions.isEmpty || !headlineChanges.isEmpty }

    init(backup: ReelVaultBackup, library: [ReelVideo]) {
        var additions: [ReelVideo] = []
        var changes: [HeadlineChange] = []
        for video in backup.videos {
            if let existing = library.first(where: { $0.fingerprint == video.fingerprint }) {
                if existing.headline != video.headline, !video.headline.isEmpty {
                    changes.append(HeadlineChange(id: existing.id, headline: video.headline))
                }
            } else {
                additions.append(video)
            }
        }
        self.additions = additions
        headlineChanges = changes
    }
}
