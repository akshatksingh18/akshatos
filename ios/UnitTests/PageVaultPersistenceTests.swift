import PDFKit
import SwiftData
import UIKit
import XCTest
@testable import AkshatOS

@MainActor final class PageVaultPersistenceTests: XCTestCase {
    private var sandbox: URL!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pagevault-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: PageVaultSchemaV1.self)
        return try ModelContainer(for: schema, migrationPlan: PageVaultMigration.self,
                                  configurations: [ModelConfiguration(schema: schema,
                                                                      isStoredInMemoryOnly: true)])
    }

    private func makeStore(container: ModelContainer? = nil,
                          now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_788_480_000) },
                          calendar: Calendar = .current) throws -> PageVaultStore {
        PageVaultStore(repository: SwiftDataPageVaultRepository(container: try container ?? makeContainer()),
                       storage: try PageVaultStorage(root: sandbox.appendingPathComponent("Library")),
                       documents: PageVaultDocumentService(),
                       now: now,
                       calendar: calendar)
    }

    /// A real multi-page PDF, so import exercises actual streaming, hashing, and PDFKit validation.
    private func makePDF(pages: Int, title: String? = nil, name: String = "book") throws -> URL {
        let url = sandbox.appendingPathComponent("\(name)-\(UUID().uuidString).pdf")
        let format = UIGraphicsPDFRendererFormat()
        if let title { format.documentInfo = [kCGPDFContextTitle as String: title] }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600),
                                             format: format)
        try renderer.writePDF(to: url) { context in
            for index in 0..<pages {
                context.beginPage()
                ("Page \(index + 1)" as NSString).draw(at: CGPoint(x: 24, y: 24), withAttributes: nil)
            }
        }
        return url
    }

    func testBookRoundTripAcrossContexts() throws {
        let container = try makeContainer()
        var original = PageVaultBook(fingerprint: "abc", title: "Deep Work", pageCount: 300,
                                     byteCount: 4_096, addedAt: Date(timeIntervalSince1970: 1_788_480_000))
        original.setPlace(page: 42, at: Date(timeIntervalSince1970: 1_788_483_600))
        let writer = ModelContext(container)
        writer.insert(try PageVaultSchemaV1.SavedBook(original))
        try writer.save()
        let reader = ModelContext(container)
        let rows = try reader.fetch(FetchDescriptor<PageVaultSchemaV1.SavedBook>())
        XCTAssertEqual(rows.count, 1)
        let restored = try JSONDecoder().decode(PageVaultBook.self,
                                                from: try XCTUnwrap(rows.first).payload)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.currentPage, 42)
    }

    func testRepositoryUpsertsRatherThanDuplicatingAPosition() throws {
        let container = try makeContainer()
        let repository = SwiftDataPageVaultRepository(container: container)
        var book = PageVaultBook(fingerprint: "abc", title: "Deep Work", pageCount: 300,
                                 byteCount: 4_096, addedAt: Date(timeIntervalSince1970: 1_788_480_000))
        try repository.save(book)
        book.setPlace(page: 120, at: Date(timeIntervalSince1970: 1_788_487_200))
        try repository.save(book)
        let loaded = try repository.load()
        XCTAssertEqual(loaded.books.count, 1, "Saving the same book twice must not add a row")
        XCTAssertEqual(loaded.books.first?.currentPage, 120)
        try repository.delete(id: book.id)
        XCTAssertTrue(try repository.load().books.isEmpty)
    }

    func testCorruptedStoreWithDuplicateFingerprintsIsRejected() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let first = PageVaultBook(fingerprint: "same", title: "One", pageCount: 10, byteCount: 1,
                                  addedAt: Date(timeIntervalSince1970: 1_788_480_000))
        let second = PageVaultBook(fingerprint: "same", title: "Two", pageCount: 10, byteCount: 1,
                                   addedAt: Date(timeIntervalSince1970: 1_788_480_000))
        context.insert(try PageVaultSchemaV1.SavedBook(first))
        context.insert(try PageVaultSchemaV1.SavedBook(second))
        try context.save()
        XCTAssertThrowsError(try SwiftDataPageVaultRepository(container: container).load())
    }

    func testImportCopiesTheDocumentAndKeepsTheSourceUntouched() async throws {
        let store = try makeStore()
        let source = try makePDF(pages: 12, title: "Borrowed Title")
        await store.load()
        await store.importBook(from: source)

        XCTAssertNil(store.message)
        XCTAssertEqual(store.books.count, 1)
        let book = try XCTUnwrap(store.books.first)
        XCTAssertEqual(book.title, "Borrowed Title", "PDF metadata titles win over the file name")
        XCTAssertEqual(book.pageCount, 12)
        XCTAssertGreaterThan(book.byteCount, 0)
        XCTAssertNotNil(store.lastImportSummary, "The spike records its import measurement")

        let copy = try XCTUnwrap(store.documentURL(for: book))
        XCTAssertTrue(FileManager.default.fileExists(atPath: copy.path), "The copy is app-owned")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path),
                      "Import must never consume the user's original file")
        XCTAssertEqual(PDFDocument(url: copy)?.pageCount, 12, "The copy opens as the same document")
    }

    func testDuplicateContentIsRejectedByFingerprintNotFileName() async throws {
        let store = try makeStore()
        let source = try makePDF(pages: 4, title: "Twice")
        await store.load()
        await store.importBook(from: source)
        let renamed = sandbox.appendingPathComponent("different-name.pdf")
        try FileManager.default.copyItem(at: source, to: renamed)
        await store.importBook(from: renamed)

        XCTAssertEqual(store.books.count, 1, "The same content is not stored twice")
        XCTAssertEqual(store.message, PageVaultImportFailure.duplicate(title: "Twice").message)
    }

    func testUnreadableFileLeavesNoLibraryEntryOrStagedCopy() async throws {
        let store = try makeStore()
        let junk = sandbox.appendingPathComponent("not-really.pdf")
        try Data("this is not a pdf".utf8).write(to: junk)
        await store.load()
        await store.importBook(from: junk)

        XCTAssertTrue(store.books.isEmpty, "A rejected import creates no false library entry")
        XCTAssertEqual(store.message, PageVaultImportFailure.unreadable.message)
        let staging = sandbox.appendingPathComponent("Library").appendingPathComponent("Incoming")
        let leftovers = (try? FileManager.default.contentsOfDirectory(at: staging,
                                                                     includingPropertiesForKeys: nil)) ?? []
        XCTAssertTrue(leftovers.isEmpty, "A failed import cleans up its partial copy")
    }

    func testBookmarkedPlaceSurvivesStoreRecreation() async throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        let source = try makePDF(pages: 50)
        await store.load()
        await store.importBook(from: source)
        let book = try XCTUnwrap(store.books.first)
        store.noteOpened(book)
        XCTAssertEqual(try XCTUnwrap(store.book(id: book.id)).openingPage, 0,
                       "Opening a book does not change where it reopens")
        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 31)

        let reopened = try makeStore(container: container)
        await reopened.load()
        let restored = try XCTUnwrap(reopened.books.first)
        XCTAssertEqual(restored.openingPage, 31, "Reopening lands on the bookmarked page")
        XCTAssertTrue(restored.hasPlace)
        XCTAssertNotNil(restored.lastOpenedAt)
    }

    func testRemoveDeletesOnlyPageVaultsCopy() async throws {
        let store = try makeStore()
        let source = try makePDF(pages: 6)
        await store.load()
        await store.importBook(from: source)
        let book = try XCTUnwrap(store.books.first)
        let copy = try XCTUnwrap(store.documentURL(for: book))

        store.remove(book)

        XCTAssertTrue(store.books.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path), "The app copy is deleted")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path),
                      "Removing a book never deletes the original source")
    }

    func testAbandonedStagingIsClearedOnLoad() async throws {
        let libraryRoot = sandbox.appendingPathComponent("Library")
        let staging = libraryRoot.appendingPathComponent("Incoming")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let orphan = staging.appendingPathComponent("interrupted.pdf")
        try Data("partial".utf8).write(to: orphan)

        let store = try makeStore()
        await store.load()

        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path),
                       "An interrupted copy is not left behind in the container")
        XCTAssertTrue(store.storageAvailable)
    }

    func testOnlyOneBookStaysReadingAcrossReload() async throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        await store.load()
        await store.importBook(from: try makePDF(pages: 10, title: "Alpha"))
        await store.importBook(from: try makePDF(pages: 12, title: "Beta"))
        let alpha = try XCTUnwrap(store.books.first { $0.title == "Alpha" })
        let beta = try XCTUnwrap(store.books.first { $0.title == "Beta" })

        store.setStatus(.reading, for: alpha)
        store.setStatus(.reading, for: beta)

        let reopened = try makeStore(container: container)
        await reopened.load()
        XCTAssertEqual(reopened.current?.title, "Beta", "The newest Reading choice wins")
        XCTAssertEqual(reopened.books(with: .wantToRead).map(\.title), ["Alpha"],
                       "The previous Reading book is demoted, not finished")
    }

    func testReadingProgressMeetsTodaysGoalAndSurvivesReload() async throws {
        let container = try makeContainer()
        let clock = Date(timeIntervalSince1970: 1_788_480_000)
        let store = try makeStore(container: container, now: { clock })
        await store.load()
        await store.importBook(from: try makePDF(pages: 200))
        let book = try XCTUnwrap(store.books.first)

        store.setStatus(.reading, for: book)
        store.setDailyGoal(10, for: book)
        XCTAssertEqual(store.days.count, 1, "A live goal opens today's row immediately")
        XCTAssertEqual(store.streak.todayGoal, 10)
        XCTAssertFalse(store.streak.todayMet)
        XCTAssertEqual(store.streak.current, 0)

        // Page index 12 is the thirteenth page, and the book had no earlier bookmark, so pages
        // one through thirteen have been read: thirteen, not twelve.
        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 12)
        XCTAssertEqual(store.streak.todayPagesRead, 13)
        XCTAssertTrue(store.streak.todayMet, "Bookmarking past the goal completes today")
        XCTAssertEqual(store.streak.current, 1)

        let reopened = try makeStore(container: container, now: { clock })
        await reopened.load()
        XCTAssertEqual(reopened.streak.current, 1, "The streak is rebuilt from stored days")
        XCTAssertEqual(reopened.streak.todayPagesRead, 13)
        XCTAssertEqual(reopened.days.count, 1, "Reloading does not duplicate today's row")
    }

    func testBookmarkingBackwardDoesNotReduceDailyProgress() async throws {
        let clock = Date(timeIntervalSince1970: 1_788_480_000)
        let store = try makeStore(now: { clock })
        await store.load()
        await store.importBook(from: try makePDF(pages: 120))
        let book = try XCTUnwrap(store.books.first)
        store.setStatus(.reading, for: book)
        store.setDailyGoal(30, for: book)

        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 20)
        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 4)
        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 19)

        // Index 20 is the twenty-first page, counted from before page one on an unbookmarked book.
        XCTAssertEqual(store.streak.todayPagesRead, 21,
                       "Bookmarking back into the book cannot reduce today's credit")
        XCTAssertFalse(store.streak.todayMet)
        XCTAssertEqual(try XCTUnwrap(store.book(id: book.id)).resolvedPage(), 19,
                       "Your place still follows the newest bookmark")
    }

    func testBookmarkingReplacesThePreviousPlace() async throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        await store.load()
        await store.importBook(from: try makePDF(pages: 60))
        let book = try XCTUnwrap(store.books.first)

        store.setPlace(book, page: 8)
        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 20)

        let reopened = try makeStore(container: container)
        await reopened.load()
        let restored = try XCTUnwrap(reopened.books.first)
        XCTAssertEqual(restored.openingPage, 20, "Only the newest bookmark survives")
        XCTAssertFalse(restored.isPlace(page: 8), "The previous place does not linger")

        reopened.clearPlace(restored)
        let cleared = try XCTUnwrap(reopened.books.first)
        XCTAssertFalse(cleared.hasPlace)
        XCTAssertEqual(cleared.openingPage, 0, "A cleared book opens at page one again")
    }

    func testImportGeneratesACoverThumbnail() async throws {
        let store = try makeStore()
        await store.load()
        await store.importBook(from: try makePDF(pages: 5))
        let book = try XCTUnwrap(store.books.first)
        let cover = try XCTUnwrap(store.coverURL(for: book), "A cover is cached after import")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cover.path))
        XCTAssertNotNil(UIImage(contentsOfFile: cover.path), "The cached cover is a usable image")
    }

    func testRemovingABookClearsItsReadingHistoryAndCover() async throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        await store.load()
        await store.importBook(from: try makePDF(pages: 80))
        let book = try XCTUnwrap(store.books.first)
        store.setStatus(.reading, for: book)
        store.setDailyGoal(5, for: book)
        let cover = try XCTUnwrap(store.coverURL(for: book))
        XCTAssertFalse(store.days.isEmpty)

        store.remove(book)

        XCTAssertTrue(store.days.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cover.path), "The cover cache is cleared")
        let reopened = try makeStore(container: container)
        await reopened.load()
        XCTAssertTrue(reopened.days.isEmpty, "Reading history does not outlive its book")
    }

    func testStoreClaimingTwoReadingBooksIsRejected() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        for name in ["One", "Two"] {
            var book = PageVaultBook(fingerprint: name, title: name, pageCount: 10, byteCount: 1,
                                     addedAt: Date(timeIntervalSince1970: 1_788_480_000))
            book.status = .reading
            context.insert(try PageVaultSchemaV1.SavedBook(book))
        }
        try context.save()
        XCTAssertThrowsError(try SwiftDataPageVaultRepository(container: container).load(),
                             "Two Reading books is a corrupt library, not a valid state")
    }

    func testFinishingWithoutAReplacementLeavesTodaysProgressIntact() async throws {
        let clock = Date(timeIntervalSince1970: 1_788_480_000)
        let store = try makeStore(now: { clock })
        await store.load()
        await store.importBook(from: try makePDF(pages: 40))
        let book = try XCTUnwrap(store.books.first)
        store.setStatus(.reading, for: book)
        store.setDailyGoal(10, for: book)
        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 12)
        XCTAssertEqual(store.streak.current, 1)

        store.setStatus(.finished, for: try XCTUnwrap(store.book(id: book.id)))

        XCTAssertNil(store.current, "Finishing leaves nothing being read")
        XCTAssertEqual(store.streak.current, 1,
                       "A day already completed is not undone by finishing the book")
    }

    func testBookmarkingClaimsTheBookAsTheOneBeingRead() async throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        await store.load()
        await store.importBook(from: try makePDF(pages: 30, title: "Alpha"))
        await store.importBook(from: try makePDF(pages: 32, title: "Beta"))
        let alpha = try XCTUnwrap(store.books.first { $0.title == "Alpha" })
        let beta = try XCTUnwrap(store.books.first { $0.title == "Beta" })
        XCTAssertNil(store.current, "Importing does not start reading anything")

        store.setPlace(alpha, page: 4)
        XCTAssertEqual(store.current?.title, "Alpha",
                       "Bookmarking is enough to make a book the one being read")

        store.setPlace(beta, page: 2)
        XCTAssertEqual(store.current?.title, "Beta", "The newest bookmarked book takes over")
        XCTAssertEqual(store.books(with: .wantToRead).map(\.title), ["Alpha"],
                       "The previous book steps back to Want to read, keeping the single-Reading rule")

        let reopened = try makeStore(container: container)
        await reopened.load()
        XCTAssertEqual(reopened.current?.title, "Beta")
    }

    func testGoalCountsPagesBetweenBookmarks() async throws {
        let clock = Date(timeIntervalSince1970: 1_788_480_000)
        let store = try makeStore(now: { clock })
        await store.load()
        await store.importBook(from: try makePDF(pages: 300))
        let book = try XCTUnwrap(store.books.first)

        store.setPlace(book, page: 40)
        store.setDailyGoal(10, for: try XCTUnwrap(store.book(id: book.id)))
        XCTAssertEqual(store.streak.todayPagesRead, 0,
                       "Today starts from the bookmark that was already there")

        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 46)
        XCTAssertEqual(store.streak.todayPagesRead, 6, "Six pages were covered since that bookmark")
        XCTAssertFalse(store.streak.todayMet)

        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 52)
        XCTAssertEqual(store.streak.todayPagesRead, 12, "Progress accumulates across bookmarks")
        XCTAssertTrue(store.streak.todayMet)
        XCTAssertEqual(store.streak.current, 1)
    }

    func testOpeningABookWithoutBookmarkingEarnsNoProgress() async throws {
        let clock = Date(timeIntervalSince1970: 1_788_480_000)
        let store = try makeStore(now: { clock })
        await store.load()
        await store.importBook(from: try makePDF(pages: 90))
        let book = try XCTUnwrap(store.books.first)
        store.setStatus(.reading, for: book)
        store.setDailyGoal(5, for: try XCTUnwrap(store.book(id: book.id)))

        store.noteOpened(try XCTUnwrap(store.book(id: book.id)))

        XCTAssertEqual(store.streak.todayPagesRead, 0,
                       "Reading without bookmarking records nothing, by design")
        XCTAssertTrue(store.streak.isAtRisk, "The day is open and unmet, so it is at risk")
        XCTAssertEqual(store.streak.current, 0)
    }

    func testFirstSessionCountsThePageYouStartOn() async throws {
        let clock = Date(timeIntervalSince1970: 1_788_480_000)
        let store = try makeStore(now: { clock })
        await store.load()
        await store.importBook(from: try makePDF(pages: 120))
        let book = try XCTUnwrap(store.books.first)
        store.setStatus(.reading, for: book)
        store.setDailyGoal(20, for: try XCTUnwrap(store.book(id: book.id)))
        XCTAssertFalse(try XCTUnwrap(store.book(id: book.id)).hasPlace)

        // Reading pages 1...20 and bookmarking page 20 is twenty pages, not nineteen: a book with
        // no bookmark starts before page one, because page one has not been read yet.
        store.setPlace(try XCTUnwrap(store.book(id: book.id)), page: 19)

        XCTAssertEqual(store.streak.todayPagesRead, 20,
                       "The first session counts the page it started on")
        XCTAssertTrue(store.streak.todayMet)
    }
}
