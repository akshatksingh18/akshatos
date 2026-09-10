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

    private func makeStore(container: ModelContainer? = nil) throws -> PageVaultStore {
        PageVaultStore(repository: SwiftDataPageVaultRepository(container: try container ?? makeContainer()),
                       storage: try PageVaultStorage(root: sandbox.appendingPathComponent("Library")),
                       documents: PageVaultDocumentService(),
                       now: { Date(timeIntervalSince1970: 1_788_480_000) })
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
        original.remember(page: 42, at: Date(timeIntervalSince1970: 1_788_483_600))
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
        book.remember(page: 120, at: Date(timeIntervalSince1970: 1_788_487_200))
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

    func testRememberedPageSurvivesStoreRecreation() async throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        let source = try makePDF(pages: 50)
        await store.load()
        await store.importBook(from: source)
        let book = try XCTUnwrap(store.books.first)
        store.remember(book, page: 31)

        let reopened = try makeStore(container: container)
        await reopened.load()
        let restored = try XCTUnwrap(reopened.books.first)
        XCTAssertEqual(restored.currentPage, 31, "Reopening restores the last read page")
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

    func testOutlineIsEmptyForADocumentWithoutOne() async throws {
        let store = try makeStore()
        await store.load()
        await store.importBook(from: try makePDF(pages: 3))
        let book = try XCTUnwrap(store.books.first)
        let outline = await store.outline(for: book)
        XCTAssertTrue(outline.isEmpty, "A PDF with no embedded outline reports none rather than faking one")
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
}
