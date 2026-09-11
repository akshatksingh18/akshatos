import PDFKit
import SwiftData
import UIKit
import XCTest
@testable import AkshatOS

/// Export and restore against real files: generated PDFs, streamed hashing, the real folder layout,
/// and a separate library per "phone", so a restore is proven into a store that never saw the books.
@MainActor final class PageVaultBackupTests: XCTestCase {
    private var sandbox: URL!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pagevault-backup-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    private func makeContainer(name: String) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PageVaultSchemaV1.self)
        return try ModelContainer(for: schema, migrationPlan: PageVaultMigration.self,
                                  configurations: [ModelConfiguration(name, schema: schema,
                                                                      isStoredInMemoryOnly: true)])
    }

    /// Each phone gets its own container and file root, so nothing leaks between them.
    private func makeStore(phone: String, container: ModelContainer? = nil) throws -> PageVaultStore {
        PageVaultStore(repository: SwiftDataPageVaultRepository(container: try container ?? makeContainer(name: phone)),
                       storage: try PageVaultStorage(root: sandbox.appendingPathComponent(phone)),
                       documents: PageVaultDocumentService(),
                       now: { Date(timeIntervalSince1970: 1_788_480_000) })
    }

    private func makePDF(pages: Int, title: String) throws -> URL {
        let url = sandbox.appendingPathComponent("\(title)-\(UUID().uuidString).pdf")
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600),
                                             format: format)
        try renderer.writePDF(to: url) { context in
            for index in 0..<pages {
                context.beginPage()
                ("\(title) page \(index + 1)" as NSString).draw(at: CGPoint(x: 24, y: 24),
                                                               withAttributes: nil)
            }
        }
        return url
    }

    private func refusal(_ work: () async throws -> Void) async -> PageVaultBackupError? {
        do {
            try await work()
            return nil
        } catch {
            return error as? PageVaultBackupError
        }
    }

    func testFullExportRestoresIntoAFreshLibrary() async throws {
        let original = try makeStore(phone: "PhoneA")
        await original.load()
        await original.importBook(from: try makePDF(pages: 30, title: "Alpha"))
        await original.importBook(from: try makePDF(pages: 12, title: "Beta"))
        let alpha = try XCTUnwrap(original.books.first { $0.title == "Alpha" })
        original.setPlace(alpha, page: 9)
        XCTAssertNil(original.message)

        let folder = try await original.prepareExport(includeDocuments: true)
        let manifestURL = folder.appendingPathComponent(PageVaultBackup.manifestName)
        let backup = try PageVaultBackup.decode(Data(contentsOf: manifestURL))
        XCTAssertEqual(backup.entries.count, 2)
        for entry in backup.entries {
            let copy = folder.appendingPathComponent(try XCTUnwrap(entry.file))
            XCTAssertEqual(PDFDocument(url: copy)?.pageCount, entry.book.pageCount,
                           "Each exported PDF is a readable copy")
        }

        let container = try makeContainer(name: "PhoneB")
        let restored = try makeStore(phone: "PhoneB", container: container)
        await restored.load()
        let prepared = try await restored.prepareRestore(from: folder)
        XCTAssertEqual(prepared.plan.additions.count, 2)
        XCTAssertTrue(prepared.plan.matches.isEmpty)
        _ = try await restored.restore(prepared, mode: .addMissing)

        let restoredAlpha = try XCTUnwrap(restored.books.first { $0.title == "Alpha" })
        XCTAssertEqual(restoredAlpha.openingPage, 9, "The bookmarked place comes back")
        XCTAssertEqual(restored.current?.title, "Alpha", "The book being read comes back as that book")
        let restoredCopy = try XCTUnwrap(restored.documentURL(for: restoredAlpha))
        let originalCopy = try XCTUnwrap(original.documentURL(for: alpha))
        XCTAssertEqual(try Data(contentsOf: restoredCopy), try Data(contentsOf: originalCopy),
                       "The restored PDF is byte-identical to the exported one")
        XCTAssertNotNil(restored.coverURL(for: restoredAlpha), "Covers are regenerated, not exported")

        let reopened = try makeStore(phone: "PhoneB", container: container)
        await reopened.load()
        XCTAssertEqual(reopened.books.count, 2, "The restore was persisted, not only shown")
        XCTAssertEqual(reopened.current?.title, "Alpha")

        original.finishExport()
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path),
                       "Finishing an export clears what was staged for it")
    }

    func testReadingDataRestoresOntoAReimportedPDF() async throws {
        let source = try makePDF(pages: 40, title: "Gamma")
        let original = try makeStore(phone: "PhoneA")
        await original.load()
        await original.importBook(from: source)
        original.setPlace(try XCTUnwrap(original.books.first), page: 22)
        let file = try await original.prepareExport(includeDocuments: false)
        XCTAssertEqual(file.pathExtension, "json", "Reading data is one small file")

        let fresh = try makeStore(phone: "PhoneB")
        await fresh.load()
        let premature = await refusal { _ = try await fresh.prepareRestore(from: file) }
        XCTAssertEqual(premature, .nothingToRestore(missingDocuments: 1),
                       "Reading data cannot bring back a book whose PDF is not in the library")

        await fresh.importBook(from: source)
        let reimported = try XCTUnwrap(fresh.books.first)
        XCTAssertFalse(reimported.hasPlace)
        let prepared = try await fresh.prepareRestore(from: file)
        XCTAssertEqual(prepared.plan.matches.map(\.existingID), [reimported.id],
                       "The re-imported book is matched by its content, not its id")
        _ = try await fresh.restore(prepared, mode: .replaceMatching)
        let result = try XCTUnwrap(fresh.books.first)
        XCTAssertEqual(result.id, reimported.id, "The re-imported book keeps its own identity")
        XCTAssertEqual(result.openingPage, 22, "Its place comes back from the reading data")
        XCTAssertEqual(fresh.current?.id, reimported.id)
    }

    func testATamperedPDFRestoresNothing() async throws {
        let original = try makeStore(phone: "PhoneA")
        await original.load()
        await original.importBook(from: try makePDF(pages: 8, title: "Delta"))
        await original.importBook(from: try makePDF(pages: 9, title: "Epsilon"))
        let folder = try await original.prepareExport(includeDocuments: true)
        let backup = try PageVaultBackup.decode(
            Data(contentsOf: folder.appendingPathComponent(PageVaultBackup.manifestName)))
        let victim = try XCTUnwrap(backup.entries.last)
        let victimURL = folder.appendingPathComponent(try XCTUnwrap(victim.file))
        try FileManager.default.removeItem(at: victimURL)
        try FileManager.default.copyItem(at: try makePDF(pages: victim.book.pageCount, title: "Impostor"),
                                         to: victimURL)

        let fresh = try makeStore(phone: "PhoneB")
        await fresh.load()
        let prepared = try await fresh.prepareRestore(from: folder)
        let failure = await refusal { _ = try await fresh.restore(prepared, mode: .addMissing) }
        XCTAssertEqual(failure, .documentMismatch(title: victim.book.title),
                       "A PDF that does not match its checksum stops the restore")
        XCTAssertTrue(fresh.books.isEmpty, "Nothing is restored, not even the intact book")

        let root = sandbox.appendingPathComponent("PhoneB")
        let bookDirectories = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { UUID(uuidString: $0) != nil }
        XCTAssertTrue(bookDirectories.isEmpty, "No book directories are left behind")
        let staging = root.appendingPathComponent("Incoming")
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: staging.path)) ?? []
        XCTAssertTrue(leftovers.isEmpty, "Verified copies are discarded when a later one fails")
    }

    func testRestoreLeavesBooksAlreadyHereAloneUnlessReplacing() async throws {
        let shared = try makePDF(pages: 50, title: "Shared")
        let original = try makeStore(phone: "PhoneA")
        await original.load()
        await original.importBook(from: shared)
        await original.importBook(from: try makePDF(pages: 20, title: "Only In Export"))
        original.setPlace(try XCTUnwrap(original.books.first { $0.title == "Shared" }), page: 30)
        let folder = try await original.prepareExport(includeDocuments: true)

        let container = try makeContainer(name: "PhoneB")
        let phone = try makeStore(phone: "PhoneB", container: container)
        await phone.load()
        await phone.importBook(from: shared)
        await phone.importBook(from: try makePDF(pages: 15, title: "Only Here"))
        phone.setPlace(try XCTUnwrap(phone.books.first { $0.title == "Only Here" }), page: 4)

        let prepared = try await phone.prepareRestore(from: folder)
        XCTAssertEqual(prepared.plan.matches.count, 1)
        XCTAssertEqual(prepared.plan.additions.count, 1)
        _ = try await phone.restore(prepared, mode: .addMissing)
        XCTAssertEqual(phone.books.count, 3)
        XCTAssertFalse(try XCTUnwrap(phone.books.first { $0.title == "Shared" }).hasPlace,
                       "Only adding leaves the book already here exactly as it was")
        XCTAssertEqual(phone.current?.title, "Only Here",
                       "Only adding never takes over the book being read")

        let again = try await phone.prepareRestore(from: folder)
        XCTAssertTrue(again.plan.additions.isEmpty, "A second restore finds nothing left to add")
        _ = try await phone.restore(again, mode: .replaceMatching)
        XCTAssertEqual(try XCTUnwrap(phone.books.first { $0.title == "Shared" }).openingPage, 30,
                       "Replacing gives the book already here the export's place")
        XCTAssertEqual(phone.current?.title, "Shared", "The export's Reading book takes over")
        XCTAssertEqual(phone.startedBooks.map(\.title), ["Only Here"],
                       "The book it displaced keeps its place and shelves under Started")

        let reopened = try makeStore(phone: "PhoneB", container: container)
        await reopened.load()
        XCTAssertEqual(reopened.current?.title, "Shared", "The replacement was persisted")
        XCTAssertEqual(reopened.books.filter { $0.status == .reading }.count, 1)
    }

    func testMalformedOrMisPickedExportsAreRefused() async throws {
        let store = try makeStore(phone: "PhoneA")
        await store.load()

        let emptyStore = try makeStore(phone: "PhoneC")
        await emptyStore.load()
        let nothing = await refusal { _ = try await emptyStore.prepareExport(includeDocuments: true) }
        XCTAssertEqual(nothing, .emptyLibrary, "An empty library has nothing to export")

        let junk = sandbox.appendingPathComponent("Not An Export", isDirectory: true)
        try FileManager.default.createDirectory(at: junk, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: junk.appendingPathComponent(PageVaultBackup.manifestName))
        let malformed = await refusal { _ = try await store.prepareRestore(from: junk) }
        XCTAssertEqual(malformed, .invalidFile, "A manifest without a version is not an export")

        let empty = sandbox.appendingPathComponent("Empty Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        let bare = await refusal { _ = try await store.prepareRestore(from: empty) }
        XCTAssertEqual(bare, .invalidFile, "A folder without a manifest is not an export")

        await store.importBook(from: try makePDF(pages: 5, title: "Zeta"))
        let folder = try await store.prepareExport(includeDocuments: true)
        let manifestOnly = await refusal {
            _ = try await store.prepareRestore(from: folder.appendingPathComponent(PageVaultBackup.manifestName))
        }
        XCTAssertEqual(manifestOnly, .folderRequired,
                       "Picking only the manifest of a full export asks for the whole folder")
    }
}
