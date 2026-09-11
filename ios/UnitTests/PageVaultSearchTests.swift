import PDFKit
import SwiftData
import UIKit
import XCTest
@testable import AkshatOS

/// Search against real PDFs: the text layer PDFKit exposes, the store's background search, and an
/// image-only page that must honestly find nothing.
@MainActor final class PageVaultSearchTests: XCTestCase {
    private var sandbox: URL!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pagevault-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    private func makeStore() throws -> PageVaultStore {
        let schema = Schema(versionedSchema: PageVaultSchemaV1.self)
        let container = try ModelContainer(for: schema, migrationPlan: PageVaultMigration.self,
                                           configurations: [ModelConfiguration(schema: schema,
                                                                               isStoredInMemoryOnly: true)])
        return PageVaultStore(repository: SwiftDataPageVaultRepository(container: container),
                              storage: try PageVaultStorage(root: sandbox.appendingPathComponent("Library")),
                              documents: PageVaultDocumentService())
    }

    /// One line of real text per page, so the page a hit reports is unambiguous.
    private func makePDF(lines: [String]) throws -> URL {
        let url = sandbox.appendingPathComponent("searchable-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        try renderer.writePDF(to: url) { context in
            for line in lines {
                context.beginPage()
                (line as NSString).draw(at: CGPoint(x: 36, y: 36),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            }
        }
        return url
    }

    private func imported(_ store: PageVaultStore, lines: [String]) async throws -> PageVaultBook {
        await store.load()
        await store.importBook(from: try makePDF(lines: lines))
        return try XCTUnwrap(store.books.first)
    }

    func testSearchFindsEveryPageCarryingThePhrase() async throws {
        let store = try makeStore()
        let book = try await imported(store, lines: [
            "Grit is passion and perseverance",
            "Nothing of interest on this page",
            "The word grit appears again here"
        ])

        let hits = await store.search("grit", in: book)

        XCTAssertEqual(hits.map(\.page), [0, 2], "Both pages carrying the word are found, in order")
        XCTAssertTrue(hits.allSatisfy { $0.snippet.lowercased().contains("grit") },
                      "Each result shows the line it matched")
    }

    func testSearchIgnoresCaseAndRefusesAOneLetterQuery() async throws {
        let store = try makeStore()
        let book = try await imported(store, lines: ["Deliberate practice", "practice again"])

        let upper = await store.search("PRACTICE", in: book)
        XCTAssertEqual(upper.count, 2, "Case is ignored")

        let tooShort = await store.search("p", in: book)
        XCTAssertTrue(tooShort.isEmpty, "One letter is not a search")
    }

    func testSearchFindsNothingInAPageOfImages() async throws {
        let url = sandbox.appendingPathComponent("scan-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        // A filled rectangle has no text layer, exactly like a scanned page.
        try renderer.writePDF(to: url) { context in
            for _ in 0..<3 {
                context.beginPage()
                UIColor.gray.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
            }
        }
        let store = try makeStore()
        await store.load()
        await store.importBook(from: url)
        let book = try XCTUnwrap(store.books.first)

        let hits = await store.search("anything", in: book)

        XCTAssertTrue(hits.isEmpty, "A scanned page has no text, and PageVault does not OCR")
    }
}
