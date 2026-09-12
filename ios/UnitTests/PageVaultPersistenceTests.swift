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

    func testRemovingABookClearsItsCoverAndRecord() async throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        await store.load()
        await store.importBook(from: try makePDF(pages: 80))
        let book = try XCTUnwrap(store.books.first)
        store.setStatus(.reading, for: book)
        let cover = try XCTUnwrap(store.coverURL(for: book))

        store.remove(book)

        XCTAssertFalse(FileManager.default.fileExists(atPath: cover.path), "The cover cache is cleared")
        let reopened = try makeStore(container: container)
        await reopened.load()
        XCTAssertTrue(reopened.books.isEmpty, "The book does not outlive its removal")
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

    func testFinishingABookLeavesNothingBeingRead() async throws {
        let store = try makeStore()
        await store.load()
        await store.importBook(from: try makePDF(pages: 40))
        let book = try XCTUnwrap(store.books.first)
        store.setPlace(book, page: 12)
        XCTAssertEqual(store.current?.id, book.id)

        store.setStatus(.finished, for: try XCTUnwrap(store.book(id: book.id)))

        XCTAssertNil(store.current, "Finishing leaves nothing being read")
        XCTAssertEqual(try XCTUnwrap(store.book(id: book.id)).resolvedPage(), 12,
                       "Finishing a book keeps the place it ended on")
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
        XCTAssertEqual(store.startedBooks.map(\.title), ["Alpha"],
                       "The set-aside book keeps its place, so it shelves under Started")
        XCTAssertTrue(store.unstartedBooks.isEmpty, "No unopened book is left on Want to read")

        let reopened = try makeStore(container: container)
        await reopened.load()
        XCTAssertEqual(reopened.current?.title, "Beta")
        XCTAssertEqual(reopened.startedBooks.map(\.title), ["Alpha"],
                       "The Started shelf is derived from stored data, so it survives a reload")
    }

    /// An installed build stored only a warm-paper switch, so that choice has to carry over to the
    /// themes that replaced it rather than resetting the reader's appearance.
    func testAnInstalledWarmPaperChoiceCarriesOverToThemes() throws {
        let suite = "pagevault-theme-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "pagevault.warmPaper")

        let store = PageVaultStore(
            repository: SwiftDataPageVaultRepository(container: try makeContainer()),
            storage: try PageVaultStorage(root: sandbox.appendingPathComponent("Themes")),
            documents: PageVaultDocumentService(), defaults: defaults)
        XCTAssertEqual(store.theme, .paper, "Warm paper turned off carries over as the plain page")

        store.theme = .night
        let reopened = PageVaultStore(
            repository: SwiftDataPageVaultRepository(container: try makeContainer()),
            storage: try PageVaultStorage(root: sandbox.appendingPathComponent("Themes")),
            documents: PageVaultDocumentService(), defaults: defaults)
        XCTAssertEqual(reopened.theme, .night, "A chosen theme is remembered across launches")

        // Build 21 had a separate warm theme; anyone who chose it should land on sepia.
        let warmSuite = "pagevault-warm-\(UUID().uuidString)"
        let warmDefaults = try XCTUnwrap(UserDefaults(suiteName: warmSuite))
        defer { warmDefaults.removePersistentDomain(forName: warmSuite) }
        warmDefaults.set("warm", forKey: "pagevault.theme")
        let carried = PageVaultStore(
            repository: SwiftDataPageVaultRepository(container: try makeContainer()),
            storage: try PageVaultStorage(root: sandbox.appendingPathComponent("Warm")),
            documents: PageVaultDocumentService(), defaults: warmDefaults)
        XCTAssertEqual(carried.theme, .sepia, "The retired warm theme carries over as sepia")
    }

    /// Streaks are gone, but an installed build wrote per-day rows into the same store. They are
    /// deleted on load rather than migrated away, so the library itself is never at risk.
    func testReadingDayRowsFromAnOlderBuildAreCleared() async throws {
        let container = try makeContainer()
        let seed = ModelContext(container)
        seed.insert(PageVaultSchemaV1.SavedReadingDay(key: "2026-09-01#\(UUID().uuidString)",
                                                      payload: Data(#"{"goal":10}"#.utf8)))
        try seed.save()

        let store = try makeStore(container: container)
        await store.load()
        await store.importBook(from: try makePDF(pages: 12))

        XCTAssertTrue(store.storageAvailable)
        XCTAssertEqual(store.books.count, 1, "The library still loads normally")
        let left = try ModelContext(container)
            .fetch(FetchDescriptor<PageVaultSchemaV1.SavedReadingDay>())
        XCTAssertTrue(left.isEmpty, "Rows left by the streak feature are cleared")
    }
}
