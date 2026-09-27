import PDFKit
import SwiftData
import UIKit
import XCTest
@testable import AkshatOS

/// The two ways a PDF now arrives without the in-app picker: a linked inbox folder read on every
/// open, and "Open in AkshatOS" from another app. Both run against real folders and real PDFs; the
/// folder picker and the share sheet themselves are system UI and belong to the phone pass.
@MainActor final class PageVaultInboxTests: XCTestCase {
    private var sandbox: URL!
    private var folder: URL!
    private var deliveries: URL!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pagevault-inbox-\(UUID().uuidString)", isDirectory: true)
        folder = sandbox.appendingPathComponent("PageVault Inbox", isDirectory: true)
        deliveries = sandbox.appendingPathComponent("Documents/Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: deliveries, withIntermediateDirectories: true)
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
                       storage: try PageVaultStorage(root: sandbox.appendingPathComponent("Library"),
                                                     deliveries: deliveries),
                       documents: PageVaultDocumentService(),
                       now: { Date(timeIntervalSince1970: 1_788_480_000) })
    }

    @discardableResult
    private func makePDF(in directory: URL, name: String, pages: Int = 3) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        try renderer.writePDF(to: url) { context in
            for index in 0..<pages {
                context.beginPage()
                ("\(name) page \(index + 1) \(UUID().uuidString)" as NSString)
                    .draw(at: CGPoint(x: 24, y: 24), withAttributes: nil)
            }
        }
        return url
    }

    func testLinkingAFolderAddsItsPDFsAndLeavesTheFolderAlone() async throws {
        let store = try makeStore()
        let first = try makePDF(in: folder, name: "Deep Work.pdf")
        let second = try makePDF(in: folder, name: "Grit.pdf", pages: 5)
        try Data("not a pdf".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        let nested = folder.appendingPathComponent("Later", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try makePDF(in: nested, name: "Nested.pdf")
        await store.load()

        await store.linkInbox(folder)

        XCTAssertEqual(store.inboxFolderName, "PageVault Inbox")
        XCTAssertFalse(store.inboxNeedsRelink)
        XCTAssertEqual(Set(store.books.map(\.title)), ["Deep Work", "Grit"],
                       "Top-level PDFs are added; other files and subfolders are not")
        XCTAssertEqual(store.inboxReport?.added.count, 2)
        XCTAssertNil(store.message, "A pass never raises an alert")
        for source in [first, second] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: source.path),
                          "The folder is only read: its files stay where the laptop put them")
        }
        for book in store.books {
            let copy = try XCTUnwrap(store.documentURL(for: book))
            XCTAssertFalse(copy.path.hasPrefix(folder.path), "The library keeps its own copy")
            XCTAssertNotNil(PDFDocument(url: copy))
        }
    }

    func testALaterPassAddsOnlyWhatIsNew() async throws {
        let store = try makeStore()
        try makePDF(in: folder, name: "One.pdf")
        await store.load()
        await store.linkInbox(folder)
        XCTAssertEqual(store.books.count, 1)

        try makePDF(in: folder, name: "Two.pdf")
        await store.syncInbox()
        XCTAssertEqual(Set(store.books.map(\.title)), ["One", "Two"])
        XCTAssertEqual(store.inboxReport?.added, ["Two"], "Only the new file is added")

        await store.syncInbox()
        XCTAssertEqual(store.books.count, 2)
        XCTAssertEqual(store.inboxReport?.summary, "Nothing new.")
        XCTAssertEqual(store.inboxReport?.isNews, false)
    }

    func testDuplicatesAndBrokenFilesAreSettledNotRetried() async throws {
        let store = try makeStore()
        let elsewhere = sandbox.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let original = try makePDF(in: elsewhere, name: "Already.pdf")
        await store.importBook(from: original)
        XCTAssertEqual(store.books.count, 1)
        try FileManager.default.copyItem(at: original, to: folder.appendingPathComponent("Copy.pdf"))
        try Data("%PDF-1.7 truncated".utf8).write(to: folder.appendingPathComponent("Broken.pdf"))

        await store.linkInbox(folder)

        XCTAssertEqual(store.books.count, 1, "The same content is not added twice under another name")
        XCTAssertNil(store.message, "Neither the duplicate nor the broken file raises an alert")
        let report = try XCTUnwrap(store.inboxReport)
        XCTAssertEqual(report.alreadyInLibrary, 1)
        XCTAssertEqual(report.rejected.count, 1)
        XCTAssertTrue(report.rejected[0].hasPrefix("Broken.pdf: "), "The problem names its file")

        await store.syncInbox()
        XCTAssertEqual(store.inboxReport?.summary, "Nothing new.",
                       "Settled files are not read or reported again while they are unchanged")
    }

    func testARemovedBookIsNotAddedBackFromTheFolder() async throws {
        let store = try makeStore()
        try makePDF(in: folder, name: "Finished With.pdf")
        await store.load()
        await store.linkInbox(folder)
        let book = try XCTUnwrap(store.books.first)

        store.remove(book)
        await store.syncInbox()

        XCTAssertTrue(store.books.isEmpty, "Removing a book is respected while its PDF stays in the folder")
    }

    func testAFileSavedAgainIsTriedAgain() async throws {
        let store = try makeStore()
        let broken = folder.appendingPathComponent("Draft.pdf")
        try Data("not yet a pdf".utf8).write(to: broken)
        await store.load()
        await store.linkInbox(folder)
        XCTAssertTrue(store.books.isEmpty)

        try FileManager.default.removeItem(at: broken)
        try makePDF(in: folder, name: "Draft.pdf")
        await store.syncInbox()

        XCTAssertEqual(store.books.map(\.title), ["Draft"],
                       "A file replaced in the folder is a new file, even under the same name")
    }

    func testTheLinkAndItsRecordSurviveARelaunch() async throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        try makePDF(in: folder, name: "Kept.pdf")
        await store.load()
        await store.linkInbox(folder)
        store.remove(try XCTUnwrap(store.books.first))

        let relaunched = try makeStore(container: container)
        await relaunched.load()
        XCTAssertEqual(relaunched.inboxFolderName, "PageVault Inbox", "The linked folder is remembered")
        try makePDF(in: folder, name: "Fresh.pdf")
        await relaunched.syncInbox()

        XCTAssertEqual(relaunched.books.map(\.title), ["Fresh"],
                       "Only the new file is added; the settled record survived the relaunch")
    }

    func testUnlinkingForgetsTheFolderAndChangesNothingElse() async throws {
        let store = try makeStore()
        let source = try makePDF(in: folder, name: "Stays.pdf")
        await store.load()
        await store.linkInbox(folder)

        store.unlinkInbox()
        try makePDF(in: folder, name: "Ignored.pdf")
        await store.syncInbox()

        XCTAssertNil(store.inboxFolderName)
        XCTAssertNil(store.inboxReport)
        XCTAssertEqual(store.books.map(\.title), ["Stays"], "An unlinked folder is not read")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))

        let relaunched = try makeStore()
        await relaunched.load()
        XCTAssertNil(relaunched.inboxFolderName, "Unlinking is remembered")
    }

    func testAFolderThatDisappearedAsksToBeLinkedAgain() async throws {
        let store = try makeStore()
        await store.load()
        await store.linkInbox(folder)
        XCTAssertFalse(store.inboxNeedsRelink)

        try FileManager.default.removeItem(at: folder)
        await store.syncInbox()

        XCTAssertTrue(store.inboxNeedsRelink, "An unreachable folder is reported, not silently skipped")
        XCTAssertNil(store.message)
    }

    func testAnOpenedFileIsAddedAndItsDeliveredCopyRemoved() async throws {
        let store = try makeStore()
        let delivered = try makePDF(in: deliveries, name: "Shared.pdf")

        // Arrives before PageVault's screen has ever loaded the library, as from a cold launch.
        await store.importOpenedFile(delivered)

        XCTAssertEqual(store.books.map(\.title), ["Shared"])
        XCTAssertEqual(store.message, "\"Shared\" is in your library.")
        XCTAssertFalse(FileManager.default.fileExists(atPath: delivered.path),
                       "iOS's delivered copy is removed once PageVault has its own")

        store.message = nil
        let second = deliveries.appendingPathComponent("Again.pdf")
        try FileManager.default.copyItem(at: try XCTUnwrap(store.documentURL(for: store.books[0])),
                                         to: second)
        await store.importOpenedFile(second)
        XCTAssertEqual(store.books.count, 1)
        XCTAssertEqual(store.message, PageVaultImportFailure.duplicate(title: "Shared").message,
                       "Sharing a book that is already here says so")
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path),
                       "A refused delivery is cleaned up too")
    }

    func testAFileOutsideTheDeliveryFolderIsNeverDeleted() async throws {
        let store = try makeStore()
        let original = try makePDF(in: folder, name: "Original.pdf")

        await store.importOpenedFile(original)

        XCTAssertEqual(store.books.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path),
                      "Only iOS's own delivery copy may be removed, never someone else's file")
    }

    func testSimultaneousImportsOfOneFileAddItOnce() async throws {
        let store = try makeStore()
        let source = try makePDF(in: folder, name: "Twice.pdf")
        await store.load()

        async let first: Void = store.importBook(from: source)
        async let second: Void = store.importBook(from: source)
        _ = await (first, second)

        XCTAssertEqual(store.books.count, 1, "Imports run one at a time, so the second sees the first")
        XCTAssertEqual(store.message, PageVaultImportFailure.duplicate(title: "Twice").message)
        XCTAssertFalse(store.busy, "Busy clears only once every import has finished")
    }
}
