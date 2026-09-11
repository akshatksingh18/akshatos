import Foundation

// The versioned manifest behind both PageVault exports, plus restore planning. A metadata-only
// export is this manifest alone, as one JSON file; a full-library export is a plain folder holding
// the same manifest beside a copy of every PDF. Pure Foundation, so validation and conflict handling
// are tested without a document, a store, or a file system.

struct PageVaultBackupEntry: Codable, Equatable {
    var book: PageVaultBook
    /// Where this book's PDF sits inside a full export, relative to the export folder. Nil in a
    /// metadata-only export, which carries no documents.
    var file: String?
}

struct PageVaultBackup: Codable, Equatable {
    static let currentVersion = 1
    static let manifestName = "manifest.json"
    static let documentsFolder = "books"
    /// The manifest holds metadata only, so anything this large is not a PageVault export.
    static let maximumManifestBytes = 25_000_000

    let version: Int
    let createdAt: Date
    let includesDocuments: Bool
    let entries: [PageVaultBackupEntry]
    let days: [PageVaultReadingDay]

    init(version: Int = PageVaultBackup.currentVersion, createdAt: Date, includesDocuments: Bool,
         entries: [PageVaultBackupEntry], days: [PageVaultReadingDay]) {
        self.version = version
        self.createdAt = createdAt
        self.includesDocuments = includesDocuments
        self.entries = entries
        self.days = days
    }

    /// Snapshots a library. Reading days are kept only for books in it, and every document gets a
    /// readable file name that stays unique even when two books share a title.
    init(createdAt: Date, library: PageVaultLibrary, days: [PageVaultReadingDay],
         includesDocuments: Bool) {
        let ordered = library.books.sorted {
            ($0.addedAt, $0.id.uuidString) < ($1.addedAt, $1.id.uuidString)
        }
        var used = Set<String>()
        var made: [PageVaultBackupEntry] = []
        for book in ordered {
            guard includesDocuments else {
                made.append(PageVaultBackupEntry(book: book, file: nil))
                continue
            }
            var path = PageVaultBackup.documentPath(for: book)
            if used.contains(path.lowercased()) {
                path = "\(PageVaultBackup.documentsFolder)/\(book.id.uuidString).pdf"
            }
            used.insert(path.lowercased())
            made.append(PageVaultBackupEntry(book: book, file: path))
        }
        let known = Set(library.books.map(\.id))
        self.init(createdAt: createdAt, includesDocuments: includesDocuments, entries: made,
                  days: days.filter { known.contains($0.bookID) }.sorted { $0.id < $1.id })
    }

    /// Whole-file validation: a manifest is accepted completely or not at all, before anything in
    /// the library changes.
    func validated() throws -> PageVaultBackup {
        guard version == PageVaultBackup.currentVersion else {
            throw PageVaultBackupError.unsupportedVersion(version)
        }
        let books = entries.map(\.book)
        guard Set(books.map(\.id)).count == books.count,
              Set(books.map(\.fingerprint)).count == books.count,
              books.filter({ $0.status == .reading }).count <= 1 else {
            throw PageVaultBackupError.inconsistentLibrary
        }
        for entry in entries {
            let book = entry.book
            guard PageVaultBackup.isDigest(book.fingerprint), book.pageCount > 0, book.byteCount > 0,
                  (book.dailyPageGoal ?? 1) > 0 else {
                throw PageVaultBackupError.inconsistentLibrary
            }
            if includesDocuments {
                guard let file = entry.file, PageVaultBackup.isSafeDocumentPath(file) else {
                    throw PageVaultBackupError.inconsistentLibrary
                }
            } else if entry.file != nil {
                throw PageVaultBackupError.inconsistentLibrary
            }
        }
        // Compared case-insensitively because the export may land on a case-insensitive disk.
        let files = entries.compactMap(\.file).map { $0.lowercased() }
        guard Set(files).count == files.count else { throw PageVaultBackupError.inconsistentLibrary }

        let ids = Set(books.map(\.id))
        guard Set(days.map(\.id)).count == days.count,
              days.allSatisfy({ day in
                  ids.contains(day.bookID) && PageVaultBackup.isDayKey(day.day) && day.goal >= 0
                      && day.startPage >= -1 && day.highestPage >= day.startPage
              }) else {
            throw PageVaultBackupError.inconsistentHistory
        }
        return self
    }

    func encoded() throws -> Data {
        _ = try validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> PageVaultBackup {
        guard data.count <= maximumManifestBytes else { throw PageVaultBackupError.tooLarge }
        let decoder = JSONDecoder()
        // The version is read on its own first, so a newer export reports its version instead of
        // failing as an unrecognisable file.
        guard let probe = try? decoder.decode(PageVaultBackupVersionProbe.self, from: data) else {
            throw PageVaultBackupError.invalidFile
        }
        guard probe.version == currentVersion else {
            throw PageVaultBackupError.unsupportedVersion(probe.version)
        }
        guard let manifest = try? decoder.decode(PageVaultBackup.self, from: data) else {
            throw PageVaultBackupError.invalidFile
        }
        return try manifest.validated()
    }

    /// A readable, Windows-safe name that stays unique by carrying the start of the book's id.
    static func documentPath(for book: PageVaultBook) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        let space: Unicode.Scalar = " "
        var scalars = String.UnicodeScalarView()
        for scalar in book.title.unicodeScalars {
            scalars.append(forbidden.contains(scalar) ? space : scalar)
        }
        let collapsed = String(scalars).split(separator: " ").joined(separator: " ")
        let trimmable = CharacterSet(charactersIn: " .").union(.whitespacesAndNewlines)
        var stem = String(collapsed.trimmingCharacters(in: trimmable).prefix(80))
            .trimmingCharacters(in: trimmable)
        if stem.isEmpty { stem = "Book" }
        return "\(documentsFolder)/\(stem) \(book.id.uuidString.prefix(8)).pdf"
    }

    /// Only `books/<name>.pdf`, exactly one level deep, so a crafted manifest cannot point a
    /// restore outside the folder the user chose.
    static func isSafeDocumentPath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == Substring(documentsFolder) else { return false }
        let name = String(parts[1])
        return name.count > 4 && name.count <= 255 && name.lowercased().hasSuffix(".pdf")
            && !name.hasPrefix(".") && !name.contains("\\") && !name.contains(":")
            && name.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value != 0x7F }
    }

    /// Fingerprints are lowercase SHA-256 hex, which is what lets them double as export checksums.
    static func isDigest(_ value: String) -> Bool {
        let hex = CharacterSet(charactersIn: "0123456789abcdef")
        return value.unicodeScalars.count == 64 && value.unicodeScalars.allSatisfy(hex.contains)
    }

    static func isDayKey(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard value.count == 10, parts.count == 3, parts[0].count == 4, parts[1].count == 2,
              parts[2].count == 2,
              parts.allSatisfy({ $0.unicodeScalars.allSatisfy { (48...57).contains($0.value) } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return false
        }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        return DateComponents(calendar: gregorian, year: year, month: month, day: day).isValidDate
    }
}

private struct PageVaultBackupVersionProbe: Decodable {
    let version: Int
}

enum PageVaultBackupError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case invalidFile
    case tooLarge
    case inconsistentLibrary
    case inconsistentHistory
    case folderRequired
    case missingDocument(title: String)
    case documentMismatch(title: String)
    case nothingToRestore(missingDocuments: Int)
    case emptyLibrary
    case storage(String)

    var errorDescription: String? {
        switch self {
        case .emptyLibrary:
            return "There are no books to export yet."
        case .unsupportedVersion(let version):
            return "This export uses version \(version), which this build of PageVault cannot read."
        case .invalidFile:
            return "This is not a PageVault export."
        case .tooLarge:
            return "This file is too large to be a PageVault export."
        case .inconsistentLibrary:
            return "This export's book list is inconsistent, so nothing was restored."
        case .inconsistentHistory:
            return "This export's reading history is inconsistent, so nothing was restored."
        case .folderRequired:
            return "This export includes its PDFs. Choose the whole export folder, not the manifest inside it."
        case .missingDocument(let title):
            return "The PDF for \"\(title)\" is missing from the export folder, so nothing was restored."
        case .documentMismatch(let title):
            return "The PDF for \"\(title)\" does not match its checksum, so nothing was restored."
        case .nothingToRestore(let missing):
            return missing > 0
                ? "None of these \(missing) books are in your library, and this export has no PDFs. Add those PDFs first, then restore again to bring back your places."
                : "This export has nothing to restore."
        case .storage(let reason):
            return "That could not be completed: \(reason)"
        }
    }
}

enum PageVaultRestoreMode: Equatable {
    /// Adds books the library lacks. Every book already here keeps its place, status and history.
    case addMissing
    /// Also gives books already here the export's place, status, goal and reading history.
    case replaceMatching
}

struct PageVaultRestoreMatch: Equatable {
    var existingID: UUID
    var backup: PageVaultBook
}

struct PageVaultRestoreResult: Equatable {
    var library: PageVaultLibrary
    var days: [PageVaultReadingDay]
    /// Books whose stored records must be written, each listed once.
    var changedBookIDs: [UUID]
    /// Books whose reading history is replaced wholesale, so their old rows are deleted first.
    var replacedHistory: Set<UUID>
    /// Export book id to library id for every added book, which is where its PDF must be promoted.
    var additionIDs: [UUID: UUID]
}

/// What a restore would do, worked out before anything changes so the user can confirm conflicts.
/// Books are matched by content fingerprint, never by title or id, so a re-imported PDF picks its
/// place and history back up.
struct PageVaultRestorePlan: Equatable {
    /// Books the library lacks whose PDFs travel with the export.
    var additions: [PageVaultBackupEntry] = []
    /// Books already in the library, which only `replaceMatching` touches.
    var matches: [PageVaultRestoreMatch] = []
    /// Books the library lacks that a metadata-only export cannot bring back.
    var missingDocuments: [PageVaultBook] = []

    init(backup: PageVaultBackup, library: PageVaultLibrary) {
        for entry in backup.entries {
            if let existing = library.existing(fingerprint: entry.book.fingerprint) {
                matches.append(PageVaultRestoreMatch(existingID: existing.id, backup: entry.book))
            } else if backup.includesDocuments {
                additions.append(entry)
            } else {
                missingDocuments.append(entry.book)
            }
        }
    }

    var hasWork: Bool { !additions.isEmpty || !matches.isEmpty }

    /// The library and reading history after restoring. Pure: the store verifies and copies every
    /// PDF first, and only then persists what this returns.
    func applied(to library: PageVaultLibrary, days: [PageVaultReadingDay], backup: PageVaultBackup,
                 mode: PageVaultRestoreMode, at date: Date,
                 makeID: () -> UUID = UUID.init) -> PageVaultRestoreResult {
        var result = library
        var mapped: [UUID: UUID] = [:]
        var changed: [UUID] = []
        var replaced = Set<UUID>()
        var additionIDs: [UUID: UUID] = [:]
        func noteChanged(_ id: UUID) {
            if !changed.contains(id) { changed.append(id) }
        }

        if mode == .replaceMatching {
            for match in matches {
                guard var book = result.books.first(where: { $0.id == match.existingID }) else { continue }
                book.currentPage = match.backup.currentPage
                book.placeSetAt = match.backup.placeSetAt
                book.lastOpenedAt = match.backup.lastOpenedAt
                book.dailyPageGoal = match.backup.dailyPageGoal
                // Reading is claimed below through the library, which keeps the single-Reading rule.
                if match.backup.status != .reading {
                    book.status = match.backup.status
                    book.statusChangedAt = match.backup.statusChangedAt
                }
                result.update(book)
                mapped[match.backup.id] = book.id
                replaced.insert(book.id)
                noteChanged(book.id)
            }
        }

        var taken = Set(result.books.map(\.id))
        for entry in additions {
            var book = entry.book
            if taken.contains(book.id) { book.id = makeID() }
            taken.insert(book.id)
            if book.status == .reading { book.status = .wantToRead }
            guard (try? result.insert(book)) != nil else { continue }
            mapped[entry.book.id] = book.id
            additionIDs[entry.book.id] = book.id
            noteChanged(book.id)
        }

        // The export's Reading book takes over when replacing. When only adding, it never displaces
        // a book already being read; it keeps its place and so shelves under Started instead.
        if let reading = backup.entries.first(where: { $0.book.status == .reading })?.book,
           let target = mapped[reading.id],
           mode == .replaceMatching || result.current == nil {
            for book in result.setStatus(.reading, for: target, at: date) { noteChanged(book.id) }
            if let index = result.books.firstIndex(where: { $0.id == target }) {
                result.books[index].statusChangedAt = reading.statusChangedAt ?? date
            }
        }

        var restoredDays = days.filter { !replaced.contains($0.bookID) }
        var keys = Set(restoredDays.map(\.id))
        for day in backup.days {
            guard let target = mapped[day.bookID] else { continue }
            var row = day
            row.bookID = target
            guard !keys.contains(row.id) else { continue }
            keys.insert(row.id)
            restoredDays.append(row)
        }
        restoredDays.sort { ($0.day, $0.bookID.uuidString) < ($1.day, $1.bookID.uuidString) }
        return PageVaultRestoreResult(library: result, days: restoredDays, changedBookIDs: changed,
                                      replacedHistory: replaced, additionIDs: additionIDs)
    }
}
