import Foundation
import SwiftUI

/// Coordinates PageVault: copy-on-import, the library, reading status, bookmarks, reading position,
/// the daily-goal streak, and cover generation. File and document work runs off the main actor.
@MainActor final class PageVaultStore: ObservableObject {
    @Published private(set) var library = PageVaultLibrary()
    @Published private(set) var days: [PageVaultReadingDay] = []
    @Published private(set) var busy = false
    @Published private(set) var storageAvailable = false
    /// Measurement readout kept from the feasibility spike: size, page count, elapsed import time.
    @Published private(set) var lastImportSummary: String?
    @Published private(set) var coverRevision = 0
    @Published var message: String?
    /// Warm paper is the default: this is meant to read like a book, not like a document viewer.
    @Published var warmPaper: Bool {
        didSet { defaults.set(warmPaper, forKey: "pagevault.warmPaper") }
    }
    /// How far in the reader is zoomed, as a multiple of the whole-page fit. Remembered so a
    /// chosen text size survives page turns, other books and relaunches instead of being redialled.
    @Published var readingZoom: Double {
        didSet {
            let clamped = Self.clampZoom(readingZoom)
            if clamped != readingZoom { readingZoom = clamped; return }
            defaults.set(readingZoom, forKey: "pagevault.readingZoom")
        }
    }

    static let minimumZoom = 1.0
    static let maximumZoom = 4.0

    /// Never below the whole-page fit: zooming further out only shrinks text that is already small.
    static func clampZoom(_ value: Double) -> Double {
        guard value.isFinite else { return minimumZoom }
        return min(max(value, minimumZoom), maximumZoom)
    }

    private let repository: any PageVaultRepository
    private let storage: PageVaultStorage?
    private let documents: any PageVaultDocumentInspecting
    private let now: () -> Date
    private let calendar: Calendar
    private let defaults: UserDefaults

    init(repository: (any PageVaultRepository)? = nil,
         storage: PageVaultStorage? = nil,
         documents: any PageVaultDocumentInspecting = PageVaultDocumentService(),
         now: @escaping () -> Date = Date.init,
         calendar: Calendar = .current,
         defaults: UserDefaults = .standard) {
        self.repository = repository ?? SwiftDataPageVaultRepository()
        self.storage = storage ?? (try? PageVaultStorage())
        self.documents = documents
        self.now = now
        self.calendar = calendar
        self.defaults = defaults
        self.warmPaper = defaults.object(forKey: "pagevault.warmPaper") as? Bool ?? true
        self.readingZoom = Self.clampZoom(defaults.object(forKey: "pagevault.readingZoom") as? Double
                                          ?? Self.minimumZoom)
    }

    var books: [PageVaultBook] { library.recent }
    var current: PageVaultBook? { library.current }
    var streak: PageVaultStreak {
        PageVaultReadingDay.streak(days, now: now(), calendar: calendar)
    }

    func books(with status: PageVaultReadingStatus) -> [PageVaultBook] {
        library.books(with: status)
    }

    var startedBooks: [PageVaultBook] { library.started }
    var unstartedBooks: [PageVaultBook] { library.unstarted }

    func documentURL(for book: PageVaultBook) -> URL? {
        storage?.documentURL(for: book.id)
    }

    func coverURL(for book: PageVaultBook) -> URL? {
        guard let storage, storage.hasCover(for: book.id) else { return nil }
        return storage.coverURL(for: book.id)
    }

    func load() async {
        guard let storage else {
            storageAvailable = false
            message = PageVaultImportFailure.storage("the app container is unavailable").message
            return
        }
        storage.clearAbandonedStaging()
        do {
            library = try repository.load()
            days = try repository.loadDays()
            storageAvailable = true
            openTodayIfGoalIsActive()
            await ensureCovers()
        } catch {
            storageAvailable = false
            message = "Your library could not be read: \(error.localizedDescription)"
        }
    }

    func importBook(from source: URL) async {
        guard let storage else {
            message = PageVaultImportFailure.storage("the app container is unavailable").message
            return
        }
        busy = true
        defer { busy = false }
        let known = Dictionary(library.books.map { ($0.fingerprint, $0.title) },
                               uniquingKeysWith: { first, _ in first })
        let documents = self.documents
        let importedAt = now()
        do {
            let outcome = try await Task.detached(priority: .userInitiated) {
                try Self.performImport(source: source, storage: storage, documents: documents,
                                       known: known, importedAt: importedAt)
            }.value
            try library.insert(outcome.book)
            try repository.save(outcome.book)
            lastImportSummary = Self.summary(for: outcome)
            await ensureCover(for: outcome.book)
        } catch let failure as PageVaultImportFailure {
            message = failure.message
        } catch {
            message = PageVaultImportFailure.storage(error.localizedDescription).message
        }
    }

    /// Opening a book only refreshes recency. Reading progress is counted from bookmark to
    /// bookmark, so browsing pages deliberately records nothing.
    func noteOpened(_ book: PageVaultBook) {
        guard var stored = library.books.first(where: { $0.id == book.id }) else { return }
        stored.markOpened(at: now())
        library.update(stored)
        persist(stored)
    }

    /// Bookmarking is the single deliberate signal that reading happened: it moves your place,
    /// claims the book as the one being read, and credits the pages covered since the last
    /// bookmark toward today's goal.
    func setPlace(_ book: PageVaultBook, page: Int) {
        if book.status != .reading {
            for updated in library.setStatus(.reading, for: book.id, at: now()) { persist(updated) }
        }
        guard let updated = library.setPlace(page: page, for: book.id, at: now()) else { return }
        persist(updated)
        openTodayIfGoalIsActive()
        advanceToday(for: updated, reaching: updated.resolvedPage())
    }

    func clearPlace(_ book: PageVaultBook) {
        guard let updated = library.clearPlace(for: book.id, at: now()) else { return }
        persist(updated)
    }

    @discardableResult
    func setStatus(_ status: PageVaultReadingStatus, for book: PageVaultBook) -> Bool {
        let changed = library.setStatus(status, for: book.id, at: now())
        guard !changed.isEmpty else { return false }
        for updated in changed { persist(updated) }
        if status == .finished && library.current == nil {
            pauseTodayEvaluation(for: book.id)
        }
        openTodayIfGoalIsActive()
        return true
    }

    func setDailyGoal(_ goal: Int?, for book: PageVaultBook) {
        guard let updated = library.setDailyGoal(goal, for: book.id) else { return }
        persist(updated)
        openTodayIfGoalIsActive()
    }

    func book(id: UUID) -> PageVaultBook? {
        library.books.first { $0.id == id }
    }

    func remove(_ book: PageVaultBook) {
        guard let storage else { return }
        do {
            try repository.delete(id: book.id)
            try repository.deleteDays(bookID: book.id)
            try storage.remove(id: book.id)
            library.remove(id: book.id)
            days.removeAll { $0.bookID == book.id }
        } catch {
            message = "That book could not be removed: \(error.localizedDescription)"
        }
    }

    // MARK: - Streak bookkeeping

    /// Opens today's row as soon as a goal is live, so a day that passes without a bookmark becomes
    /// a real miss rather than an unrecorded gap. The row starts at wherever your place is, so only
    /// pages bookmarked after that count toward today.
    private func openTodayIfGoalIsActive() {
        guard let book = library.current, book.activeGoal > 0 else { return }
        let today = PageVaultReadingDay.dayKey(now(), calendar: calendar)
        guard !days.contains(where: { $0.day == today && $0.bookID == book.id }) else { return }
        // A book with no bookmark yet starts *before* page one, because page one has not been read.
        // Without this the first session of every book undercounts by exactly one page.
        let baseline = book.hasPlace ? book.resolvedPage() : -1
        let reachedBefore = days.filter { $0.bookID == book.id }.map(\.highestPage).max()
        let page = max(baseline, reachedBefore ?? baseline)
        let row = PageVaultReadingDay(day: today, bookID: book.id, startPage: page,
                                      highestPage: page, goal: book.activeGoal)
        days.append(row)
        persist(row)
    }

    /// `page` is the newly bookmarked place, not a page merely viewed.
    private func advanceToday(for book: PageVaultBook, reaching page: Int) {
        guard book.status == .reading, book.activeGoal > 0 else { return }
        let today = PageVaultReadingDay.dayKey(now(), calendar: calendar)
        guard let index = days.firstIndex(where: { $0.day == today && $0.bookID == book.id }) else {
            openTodayIfGoalIsActive()
            return
        }
        guard page > days[index].highestPage else { return }
        days[index].reach(page: page)
        persist(days[index])
    }

    /// Finishing a book with nothing chosen next leaves today unevaluated instead of counting a miss.
    private func pauseTodayEvaluation(for bookID: UUID) {
        let today = PageVaultReadingDay.dayKey(now(), calendar: calendar)
        guard !days.contains(where: { $0.day == today }) else { return }
        let row = PageVaultReadingDay(day: today, bookID: bookID, startPage: 0,
                                      highestPage: 0, goal: 0)
        days.append(row)
        persist(row)
    }

    // MARK: - Covers

    private func ensureCovers() async {
        for book in library.books where coverURL(for: book) == nil {
            await ensureCover(for: book)
        }
    }

    private func ensureCover(for book: PageVaultBook) async {
        guard let storage, !storage.hasCover(for: book.id) else { return }
        let url = storage.documentURL(for: book.id)
        let documents = self.documents
        let data = await Task.detached(priority: .utility) {
            documents.coverPNG(of: url, maxPixel: 600)
        }.value
        guard let data else { return }
        try? storage.writeCover(data, for: book.id)
        coverRevision += 1
    }

    // MARK: - Persistence helpers

    private func persist(_ book: PageVaultBook) {
        do {
            try repository.save(book)
        } catch {
            message = "That change could not be saved: \(error.localizedDescription)"
        }
    }

    private func persist(_ day: PageVaultReadingDay) {
        do {
            try repository.save(day)
        } catch {
            message = "Your reading day could not be saved: \(error.localizedDescription)"
        }
    }

    // MARK: - Import

    private struct ImportOutcome: Sendable {
        var book: PageVaultBook
        var duration: TimeInterval
    }

    nonisolated private static func performImport(
        source: URL, storage: PageVaultStorage, documents: any PageVaultDocumentInspecting,
        known: [String: String], importedAt: Date
    ) throws -> ImportOutcome {
        let began = Date()
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let staged = try storage.stage(from: source)
        if let clash = known[staged.fingerprint] {
            storage.discard(staged.url)
            throw PageVaultImportFailure.duplicate(title: clash)
        }
        let inspection: PageVaultDocumentService.Inspection
        do {
            inspection = try documents.inspect(staged.url)
        } catch {
            storage.discard(staged.url)
            throw error
        }
        let book = PageVaultBook(
            fingerprint: staged.fingerprint,
            title: PageVaultBook.displayTitle(metadataTitle: inspection.metadataTitle,
                                              fileName: source.lastPathComponent),
            pageCount: inspection.pageCount,
            byteCount: staged.byteCount,
            addedAt: importedAt)
        try storage.promote(staged.url, to: book.id)
        return ImportOutcome(book: book, duration: Date().timeIntervalSince(began))
    }

    private static func summary(for outcome: ImportOutcome) -> String {
        let size = ByteCountFormatter.string(fromByteCount: outcome.book.byteCount, countStyle: .file)
        let seconds = String(format: "%.1fs", outcome.duration)
        return "\(size) · \(outcome.book.pageCount) pages · copied in \(seconds)"
    }
}
