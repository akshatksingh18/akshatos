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

    private let repository: any PageVaultRepository
    private let storage: PageVaultStorage?
    private let documents: any PageVaultDocumentInspecting
    private let now: () -> Date
    private let calendar: Calendar

    init(repository: (any PageVaultRepository)? = nil,
         storage: PageVaultStorage? = nil,
         documents: any PageVaultDocumentInspecting = PageVaultDocumentService(),
         now: @escaping () -> Date = Date.init,
         calendar: Calendar = .current) {
        self.repository = repository ?? SwiftDataPageVaultRepository()
        self.storage = storage ?? (try? PageVaultStorage())
        self.documents = documents
        self.now = now
        self.calendar = calendar
    }

    var books: [PageVaultBook] { library.recent }
    var current: PageVaultBook? { library.current }
    var streak: PageVaultStreak {
        PageVaultReadingDay.streak(days, now: now(), calendar: calendar)
    }

    func books(with status: PageVaultReadingStatus) -> [PageVaultBook] {
        library.books(with: status)
    }

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

    /// Records the page reached and, when this book is the one being read against a goal, advances
    /// today's high-water mark. Paging backward to re-read never reduces progress.
    func remember(_ book: PageVaultBook, page: Int) {
        guard var stored = library.books.first(where: { $0.id == book.id }) else { return }
        let resolved = stored.resolvedPage(page)
        let firstOpen = stored.lastOpenedAt == nil
        if resolved != stored.currentPage || firstOpen {
            stored.remember(page: resolved, at: now())
            library.update(stored)
            persist(stored)
        }
        advanceToday(for: stored, reaching: resolved)
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

    @discardableResult
    func toggleBookmark(_ book: PageVaultBook, page: Int, note: String? = nil) -> Bool {
        guard var stored = library.books.first(where: { $0.id == book.id }) else { return false }
        let added = stored.toggleBookmark(page: page, note: note, at: now())
        library.update(stored)
        persist(stored)
        return added
    }

    func removeBookmark(_ book: PageVaultBook, id: UUID) {
        guard var stored = library.books.first(where: { $0.id == book.id }) else { return }
        stored.removeBookmark(id: id)
        library.update(stored)
        persist(stored)
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

    /// Outline traversal can be slow on a large document, so it never runs on the main actor.
    func outline(for book: PageVaultBook) async -> [PageVaultOutlineNode] {
        guard let url = documentURL(for: book) else { return [] }
        let documents = self.documents
        return await Task.detached(priority: .userInitiated) {
            documents.outline(of: url)
        }.value
    }

    // MARK: - Streak bookkeeping

    /// Opens today's row as soon as a goal is live, so a day that passes without reading becomes a
    /// real miss rather than an unrecorded gap.
    private func openTodayIfGoalIsActive() {
        guard let book = library.current, book.activeGoal > 0 else { return }
        let today = PageVaultReadingDay.dayKey(now(), calendar: calendar)
        guard !days.contains(where: { $0.day == today && $0.bookID == book.id }) else { return }
        let page = book.resolvedPage()
        let row = PageVaultReadingDay(day: today, bookID: book.id, startPage: page,
                                      highestPage: page, goal: book.activeGoal)
        days.append(row)
        persist(row)
    }

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
