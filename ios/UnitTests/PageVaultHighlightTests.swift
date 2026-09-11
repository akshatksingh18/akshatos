import PDFKit
import SwiftData
import UIKit
import XCTest
@testable import AkshatOS

/// Highlights against real files: saved through the store, reloaded from it, carried by an export,
/// and rendered into a PDF of their own.
@MainActor final class PageVaultHighlightTests: XCTestCase {
    private var sandbox: URL!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pagevault-highlights-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    private func makeContainer(_ name: String) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PageVaultSchemaV1.self)
        return try ModelContainer(for: schema, migrationPlan: PageVaultMigration.self,
                                  configurations: [ModelConfiguration(name, schema: schema,
                                                                      isStoredInMemoryOnly: true)])
    }

    private func makeStore(root: String, container: ModelContainer) throws -> PageVaultStore {
        PageVaultStore(repository: SwiftDataPageVaultRepository(container: container),
                       storage: try PageVaultStorage(root: sandbox.appendingPathComponent(root)),
                       documents: PageVaultDocumentService())
    }

    private func makePDF(pages: Int, name: String = "book") throws -> URL {
        let url = sandbox.appendingPathComponent("\(name)-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        try renderer.writePDF(to: url) { context in
            for index in 0..<pages {
                context.beginPage()
                ("Page \(index + 1)" as NSString).draw(at: CGPoint(x: 24, y: 24), withAttributes: nil)
            }
        }
        return url
    }

    func testAHighlightIsStoredOnTheBookAndSurvivesReload() async throws {
        let container = try makeContainer("A")
        let store = try makeStore(root: "Phone", container: container)
        await store.load()
        await store.importBook(from: try makePDF(pages: 10))
        let book = try XCTUnwrap(store.books.first)

        store.addHighlight(text: "grit is passion\nand persever-\nance", page: 3,
                           rects: [PageVaultRect(x: 72, y: 400, width: 300, height: 14)], to: book)

        let saved = try XCTUnwrap(store.book(id: book.id)?.highlights.first)
        XCTAssertEqual(saved.text, "grit is passion and perseverance",
                       "Line breaks and hyphenation are resolved when the highlight is saved")
        XCTAssertEqual(saved.page, 3)
        XCTAssertEqual(saved.rects.count, 1, "The rectangles that redraw the mark are kept")

        let reopened = try makeStore(root: "Phone", container: container)
        await reopened.load()
        let reloaded = try XCTUnwrap(reopened.books.first)
        XCTAssertEqual(reloaded.highlights.count, 1, "A highlight is part of the stored book record")

        reopened.removeHighlight(saved.id, from: reloaded)
        XCTAssertTrue(try XCTUnwrap(reopened.book(id: book.id)).highlights.isEmpty)
        let afterRemoval = try makeStore(root: "Phone", container: container)
        await afterRemoval.load()
        XCTAssertTrue(try XCTUnwrap(afterRemoval.books.first).highlights.isEmpty,
                      "Removal is persisted, not just shown")
    }

    func testHighlightsTravelWithAFullExport() async throws {
        let source = try makePDF(pages: 12, name: "shared")
        let origin = try makeStore(root: "PhoneA", container: try makeContainer("A"))
        await origin.load()
        await origin.importBook(from: source)
        let book = try XCTUnwrap(origin.books.first)
        origin.addHighlight(text: "a line worth keeping", page: 2, rects: [], to: book)
        let folder = try await origin.prepareExport(includeDocuments: true)

        let fresh = try makeStore(root: "PhoneB", container: try makeContainer("B"))
        await fresh.load()
        let prepared = try await fresh.prepareRestore(from: folder)
        _ = try await fresh.restore(prepared, mode: .addMissing)

        let restored = try XCTUnwrap(fresh.books.first)
        XCTAssertEqual(restored.highlights.map(\.text), ["a line worth keeping"],
                       "Highlights come back with the book they belong to")
    }

    func testHighlightsExportAsTheirOwnPDF() async throws {
        let store = try makeStore(root: "Phone", container: try makeContainer("A"))
        await store.load()
        await store.importBook(from: try makePDF(pages: 30))
        let book = try XCTUnwrap(store.books.first)
        store.addHighlight(text: "the first passage", page: 0, rects: [], to: book)
        store.addHighlight(text: String(repeating: "a long passage that runs on. ", count: 60),
                           page: 11, rects: [], to: try XCTUnwrap(store.book(id: book.id)))

        let file = try await store.prepareHighlightsExport(for: try XCTUnwrap(store.book(id: book.id)))

        XCTAssertEqual(file.pathExtension, "pdf")
        let document = try XCTUnwrap(PDFDocument(url: file), "The export opens as a PDF")
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: " ")
        XCTAssertTrue(text.contains("the first passage"), "Every passage is written out")
        XCTAssertTrue(text.contains("PAGE 12"), "Each passage carries the page it came from")
    }

    func testExportingABookWithNoHighlightsIsRefused() async throws {
        let store = try makeStore(root: "Phone", container: try makeContainer("A"))
        await store.load()
        await store.importBook(from: try makePDF(pages: 4))
        let book = try XCTUnwrap(store.books.first)

        do {
            _ = try await store.prepareHighlightsExport(for: book)
            XCTFail("A book with no highlights has nothing to export")
        } catch let error as PageVaultBackupError {
            XCTAssertEqual(error, .noHighlights)
        }
    }
}
