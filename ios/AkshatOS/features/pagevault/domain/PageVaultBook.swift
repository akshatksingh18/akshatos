import Foundation

// Pure domain types: no PDFKit, SwiftData, SwiftUI, or file-system side effects.
// New fields carry defaults so payloads written by an earlier build still decode.

struct PageVaultBook: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Streamed content digest. Duplicate imports are detected by this, never by display name.
    var fingerprint: String
    var title: String
    var pageCount: Int
    var byteCount: Int64
    var addedAt: Date
    var lastOpenedAt: Date? = nil
    var currentPage = 0
    var status: PageVaultReadingStatus = .wantToRead
    var statusChangedAt: Date? = nil
    /// Pages per day required for this book to count toward the streak. Nil means untracked.
    var dailyPageGoal: Int? = nil
    var bookmarks: [PageVaultBookmark] = []

    init(id: UUID = UUID(), fingerprint: String, title: String, pageCount: Int, byteCount: Int64,
         addedAt: Date, lastOpenedAt: Date? = nil, currentPage: Int = 0,
         status: PageVaultReadingStatus = .wantToRead, statusChangedAt: Date? = nil,
         dailyPageGoal: Int? = nil, bookmarks: [PageVaultBookmark] = []) {
        self.id = id
        self.fingerprint = fingerprint
        self.title = title
        self.pageCount = pageCount
        self.byteCount = byteCount
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.currentPage = currentPage
        self.status = status
        self.statusChangedAt = statusChangedAt
        self.dailyPageGoal = dailyPageGoal
        self.bookmarks = bookmarks
    }

    enum CodingKeys: String, CodingKey {
        case id, fingerprint, title, pageCount, byteCount, addedAt, lastOpenedAt, currentPage
        case status, statusChangedAt, dailyPageGoal, bookmarks
    }

    /// Decoded field by field rather than by the synthesized initializer, which ignores property
    /// defaults and would reject any record written before a field existed. Losing the whole
    /// library to one missing key is not an acceptable upgrade path, so absent fields fall back.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fingerprint = try container.decode(String.self, forKey: .fingerprint)
        title = try container.decode(String.self, forKey: .title)
        pageCount = try container.decode(Int.self, forKey: .pageCount)
        byteCount = try container.decode(Int64.self, forKey: .byteCount)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage) ?? 0
        status = try container.decodeIfPresent(PageVaultReadingStatus.self, forKey: .status)
            ?? .wantToRead
        statusChangedAt = try container.decodeIfPresent(Date.self, forKey: .statusChangedAt)
        dailyPageGoal = try container.decodeIfPresent(Int.self, forKey: .dailyPageGoal)
        bookmarks = try container.decodeIfPresent([PageVaultBookmark].self, forKey: .bookmarks) ?? []
    }

    /// A persisted page can outlive the page count it was valid for, so every read clamps.
    func resolvedPage(_ requested: Int? = nil) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(requested ?? currentPage, 0), pageCount - 1)
    }

    var progressLabel: String {
        pageCount > 0 ? "\(resolvedPage() + 1) / \(pageCount)" : "No pages"
    }

    var progressFraction: Double {
        guard pageCount > 1 else { return pageCount == 1 ? 1 : 0 }
        return Double(resolvedPage()) / Double(pageCount - 1)
    }

    var activeGoal: Int { status == .reading ? max(0, dailyPageGoal ?? 0) : 0 }

    mutating func remember(page: Int, at date: Date) {
        currentPage = resolvedPage(page)
        lastOpenedAt = date
    }

    func hasBookmark(page: Int) -> Bool {
        bookmarks.contains { $0.page == resolvedPage(page) }
    }

    /// One bookmark per page: bookmarking a page that already has one removes it.
    @discardableResult
    mutating func toggleBookmark(page: Int, note: String? = nil, at date: Date) -> Bool {
        let target = resolvedPage(page)
        if let existing = bookmarks.firstIndex(where: { $0.page == target }) {
            bookmarks.remove(at: existing)
            return false
        }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        bookmarks.append(PageVaultBookmark(page: target,
                                           note: (trimmed?.isEmpty ?? true) ? nil : trimmed,
                                           createdAt: date))
        bookmarks.sort { $0.page < $1.page }
        return true
    }

    mutating func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
    }

    /// PDF metadata titles are frequently blank, whitespace, or a leftover file path.
    static func displayTitle(metadataTitle: String?, fileName: String) -> String {
        let candidates = [metadataTitle, fileName]
        for candidate in candidates {
            let trimmed = (candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let withoutExtension = trimmed.lowercased().hasSuffix(".pdf")
                ? String(trimmed.dropLast(4)).trimmingCharacters(in: .whitespaces) : trimmed
            if !withoutExtension.isEmpty { return withoutExtension }
        }
        return "Untitled document"
    }
}

struct PageVaultLibrary: Codable, Equatable {
    var books: [PageVaultBook] = []

    /// Most recently read first, falling back to import time for books never opened.
    var recent: [PageVaultBook] {
        books.sorted { ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt) }
    }

    /// The single book being read. Enforced by `setStatus`, not merely by the UI.
    var current: PageVaultBook? { books.first { $0.status == .reading } }

    func books(with status: PageVaultReadingStatus) -> [PageVaultBook] {
        recent.filter { $0.status == status }
    }

    func existing(fingerprint: String) -> PageVaultBook? {
        books.first { $0.fingerprint == fingerprint }
    }

    mutating func insert(_ book: PageVaultBook) throws {
        if let clash = existing(fingerprint: book.fingerprint) {
            throw PageVaultImportFailure.duplicate(title: clash.title)
        }
        books.append(book)
    }

    mutating func update(_ book: PageVaultBook) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index] = book
    }

    @discardableResult
    mutating func remove(id: UUID) -> PageVaultBook? {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return nil }
        return books.remove(at: index)
    }

    /// Moving a book to Reading demotes whichever book was previously Reading back to Want to read,
    /// never silently to Finished. Returns every book that changed so callers can persist them.
    @discardableResult
    mutating func setStatus(_ status: PageVaultReadingStatus, for id: UUID,
                            at date: Date) -> [PageVaultBook] {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return [] }
        var changed: [PageVaultBook] = []
        if status == .reading {
            for other in books.indices where books[other].id != id && books[other].status == .reading {
                books[other].status = .wantToRead
                books[other].statusChangedAt = date
                changed.append(books[other])
            }
        }
        if books[index].status != status {
            books[index].status = status
            books[index].statusChangedAt = date
            changed.append(books[index])
        }
        return changed
    }

    /// A goal of zero or nil clears tracking rather than storing an unreachable target.
    @discardableResult
    mutating func setDailyGoal(_ goal: Int?, for id: UUID) -> PageVaultBook? {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return nil }
        let sanitized = (goal ?? 0) > 0 ? goal : nil
        books[index].dailyPageGoal = sanitized
        return books[index]
    }
}

enum PageVaultImportFailure: Error, Equatable {
    case unreadable
    case passwordProtected
    case noPages
    case duplicate(title: String)
    case storage(String)

    /// User-facing text. The spike must fail visibly rather than leave a false library entry.
    var message: String {
        switch self {
        case .unreadable:
            return "That file could not be opened as a PDF."
        case .passwordProtected:
            return "That PDF is password protected, so it cannot be added."
        case .noPages:
            return "That PDF reported no pages."
        case .duplicate(let title):
            return "Already in your library as \"\(title)\"."
        case .storage(let reason):
            return "Could not save a copy: \(reason)"
        }
    }
}

struct PageVaultOutlineNode: Equatable {
    /// Stable index path, so rows keep identity without generating fresh UUIDs on every traversal.
    var id: String
    var title: String
    var page: Int?
    var children: [PageVaultOutlineNode] = []
}

struct PageVaultOutlineRow: Equatable, Identifiable {
    var id: String
    var title: String
    var page: Int?
    var level: Int
}

extension PageVaultOutlineNode {
    /// Depth-first flattening that preserves hierarchy as an indent level.
    static func rows(_ nodes: [PageVaultOutlineNode], level: Int = 0) -> [PageVaultOutlineRow] {
        nodes.flatMap { node in
            [PageVaultOutlineRow(id: node.id, title: node.title, page: node.page, level: level)]
                + rows(node.children, level: level + 1)
        }
    }
}
