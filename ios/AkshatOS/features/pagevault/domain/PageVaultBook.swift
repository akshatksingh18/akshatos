import Foundation

// Pure domain types: no PDFKit, SwiftData, SwiftUI, or file-system side effects.
// New fields are decoded leniently so records written by an earlier build keep loading.

struct PageVaultBook: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Streamed content digest. Duplicate imports are detected by this, never by display name.
    var fingerprint: String
    var title: String
    var pageCount: Int
    var byteCount: Int64
    var addedAt: Date
    var lastOpenedAt: Date? = nil
    /// "Your place" — the bookmarked page, behaving like a physical bookmark. Only bookmarking
    /// moves it, so flipping through the book never loses where you actually stopped.
    var currentPage = 0
    /// Non-nil once a place has been set, which distinguishes a real bookmark on page one from a
    /// book that has never been bookmarked at all.
    var placeSetAt: Date? = nil
    var status: PageVaultReadingStatus = .wantToRead
    var statusChangedAt: Date? = nil
    /// Highlighted passages. Stored on the book so they travel with an export and are removed with it.
    var highlights: [PageVaultHighlight] = []

    init(id: UUID = UUID(), fingerprint: String, title: String, pageCount: Int, byteCount: Int64,
         addedAt: Date, lastOpenedAt: Date? = nil, currentPage: Int = 0, placeSetAt: Date? = nil,
         status: PageVaultReadingStatus = .wantToRead, statusChangedAt: Date? = nil) {
        self.id = id
        self.fingerprint = fingerprint
        self.title = title
        self.pageCount = pageCount
        self.byteCount = byteCount
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.currentPage = currentPage
        self.placeSetAt = placeSetAt
        self.status = status
        self.statusChangedAt = statusChangedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, fingerprint, title, pageCount, byteCount, addedAt, lastOpenedAt, currentPage
        case placeSetAt, status, statusChangedAt, highlights
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
        placeSetAt = try container.decodeIfPresent(Date.self, forKey: .placeSetAt)
        status = try container.decodeIfPresent(PageVaultReadingStatus.self, forKey: .status)
            ?? .wantToRead
        statusChangedAt = try container.decodeIfPresent(Date.self, forKey: .statusChangedAt)
        highlights = try container.decodeIfPresent([PageVaultHighlight].self, forKey: .highlights) ?? []
    }

    /// A persisted page can outlive the page count it was valid for, so every read clamps.
    func resolvedPage(_ requested: Int? = nil) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(requested ?? currentPage, 0), pageCount - 1)
    }

    var hasPlace: Bool { placeSetAt != nil }

    /// Where opening this book should land: the bookmark if one exists, otherwise the first page.
    var openingPage: Int { hasPlace ? resolvedPage() : 0 }

    var progressLabel: String {
        guard pageCount > 0 else { return "No pages" }
        return hasPlace ? "\(resolvedPage() + 1) / \(pageCount)" : "Not started · \(pageCount) pages"
    }

    var progressFraction: Double {
        guard hasPlace, pageCount > 1 else { return 0 }
        return Double(resolvedPage()) / Double(pageCount - 1)
    }

    func isPlace(page: Int) -> Bool { hasPlace && resolvedPage(page) == resolvedPage() }

    /// Highlights as they appear in the book, which is the order to read or export them in.
    var highlightsInReadingOrder: [PageVaultHighlight] {
        highlights.sorted { ($0.page, $0.createdAt) < ($1.page, $1.createdAt) }
    }

    func highlights(onPage page: Int) -> [PageVaultHighlight] {
        highlights.filter { $0.page == page }
    }

    /// Every mark the given page area touches.
    ///
    /// Marks are identified by the words they cover rather than by their captured text. Comparing
    /// text is what let a selection one word wider than an existing mark count as a new one.
    func highlights(onPage page: Int, covering rects: [PageVaultRect]) -> [PageVaultHighlight] {
        let folded = PageVaultHighlight.fold(rects)
        return highlights.filter { $0.page == page && $0.covers(folded) }
    }

    /// Marking words that already carry a mark extends that mark instead of stacking a second one
    /// over it, so the same passage can never be highlighted twice.
    ///
    /// The surviving mark keeps the longest text of the marks it absorbs, because that is the one
    /// describing the whole marked area — so widening a selection grows the stored passage while
    /// re-marking part of one leaves it alone. It keeps the earliest identity and date so it holds
    /// its position in the passage list instead of jumping to the end.
    mutating func addHighlight(_ highlight: PageVaultHighlight) {
        guard !highlight.text.isEmpty else { return }
        var incoming = highlight
        incoming.rects = PageVaultHighlight.fold(highlight.rects)
        // A selection with no measurable bands — an image-only page can produce one — has no
        // geometry to compare, so it falls back to the passage text rather than storing a literal
        // duplicate.
        let touching = incoming.rects.isEmpty
            ? highlights.filter { $0.page == incoming.page && $0.text == incoming.text }
            : highlights.filter { $0.page == incoming.page && $0.covers(incoming.rects) }
        guard !touching.isEmpty else {
            highlights.append(incoming)
            return
        }
        let absorbed = touching + [incoming]
        let anchor = absorbed.min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        let merged = PageVaultHighlight(
            id: anchor?.id ?? incoming.id,
            page: incoming.page,
            text: absorbed.map(\.text).max { $0.count < $1.count } ?? incoming.text,
            createdAt: anchor?.createdAt ?? incoming.createdAt,
            rects: PageVaultHighlight.fold(absorbed.flatMap(\.rects)))
        highlights.removeAll { record in touching.contains { $0.id == record.id } }
        highlights.append(merged)
    }

    mutating func removeHighlight(id: UUID) {
        highlights.removeAll { $0.id == id }
    }

    /// Clears every mark the given area touches.
    ///
    /// This is what "Remove highlight" does. It deliberately does not ask for the original
    /// selection to be reproduced: PDFKit snaps a drag to word and line boundaries differently
    /// depending on where it starts, so requiring an exact match is what made a mark effectively
    /// impossible to remove by hand.
    @discardableResult
    mutating func removeHighlights(onPage page: Int, covering rects: [PageVaultRect]) -> Int {
        let doomed = highlights(onPage: page, covering: rects)
        highlights.removeAll { record in doomed.contains { $0.id == record.id } }
        return doomed.count
    }

    /// Moves the bookmark to this page. Replaces any previous place rather than accumulating a
    /// list, which is how a physical bookmark behaves.
    mutating func setPlace(page: Int, at date: Date) {
        currentPage = resolvedPage(page)
        placeSetAt = date
        lastOpenedAt = date
    }

    mutating func clearPlace(at date: Date) {
        currentPage = 0
        placeSetAt = nil
        lastOpenedAt = date
    }

    mutating func markOpened(at date: Date) {
        lastOpenedAt = date
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

    /// Want to Read books that already carry a place: begun, then set aside, usually when another
    /// book was bookmarked. A shelf rather than a fourth status, so nothing extra is persisted.
    var started: [PageVaultBook] { recent.filter { $0.status == .wantToRead && $0.hasPlace } }

    /// Books carrying at least one kept passage, most recently marked first. This is Takeaways:
    /// what a book gave you, rather than what you are part-way through.
    var withHighlights: [PageVaultBook] {
        books.filter { !$0.highlights.isEmpty }
            .sorted { ($0.highlights.map(\.createdAt).max() ?? $0.addedAt)
                      > ($1.highlights.map(\.createdAt).max() ?? $1.addedAt) }
    }

    /// Want to Read books that have never been bookmarked.
    var unstarted: [PageVaultBook] { recent.filter { $0.status == .wantToRead && !$0.hasPlace } }

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

    @discardableResult
    mutating func addHighlight(_ highlight: PageVaultHighlight, for id: UUID) -> PageVaultBook? {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return nil }
        books[index].addHighlight(highlight)
        return books[index]
    }

    @discardableResult
    mutating func removeHighlight(_ highlightID: UUID, for id: UUID) -> PageVaultBook? {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return nil }
        books[index].removeHighlight(id: highlightID)
        return books[index]
    }

    /// Clears every mark on one page that the given selection covers.
    @discardableResult
    mutating func removeHighlights(onPage page: Int, covering rects: [PageVaultRect],
                                   for id: UUID) -> (book: PageVaultBook, removed: Int)? {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = books[index].removeHighlights(onPage: page, covering: rects)
        return (books[index], removed)
    }

    @discardableResult
    mutating func setPlace(page: Int, for id: UUID, at date: Date) -> PageVaultBook? {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return nil }
        books[index].setPlace(page: page, at: date)
        return books[index]
    }

    @discardableResult
    mutating func clearPlace(for id: UUID, at date: Date) -> PageVaultBook? {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return nil }
        books[index].clearPlace(at: date)
        return books[index]
    }
}

enum PageVaultImportFailure: Error, Equatable {
    case unreadable
    case passwordProtected
    case noPages
    case duplicate(title: String)
    case storage(String)

    /// User-facing text. Import must fail visibly rather than leave a false library entry.
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
