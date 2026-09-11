import PDFKit
import SwiftData
import UIKit
import XCTest
@testable import AkshatOS

/// Fitting pages to their text against real PDFs: generated pages carry solid ink at known places and
/// are measured by the same rendering path the reader uses, so the crop is checked on every side.
@MainActor final class PageVaultLayoutTests: XCTestCase {
    private var sandbox: URL!
    /// A text block from x 80–320 and, measured from the top, y 60–420 on a 400 × 600 point page:
    /// page fractions x 0.2–0.8 and, from the bottom, y 0.3–0.9. The vertical asymmetry proves the
    /// measurement does not flip the page.
    private let text = CGRect(x: 80, y: 60, width: 240, height: 360)
    private let textFractions = PageVaultInkBox(minX: 0.2, minY: 0.3, maxX: 0.8, maxY: 0.9)

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pagevault-layout-\(UUID().uuidString)", isDirectory: true)
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
                       documents: PageVaultDocumentService())
    }

    /// Pages filled with solid black blocks, in UIKit coordinates on a 400 × 600 point page.
    private func makePDF(pages: Int, blocks: (Int) -> [CGRect]) throws -> URL {
        let url = sandbox.appendingPathComponent("layout-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        try renderer.writePDF(to: url) { context in
            for index in 0..<pages {
                context.beginPage()
                UIColor.black.setFill()
                for block in blocks(index) { context.fill(block) }
            }
        }
        return url
    }

    private func importMeasured(_ store: PageVaultStore, pages: Int,
                                blocks: (Int) -> [CGRect]) async throws -> PageVaultBook {
        await store.load()
        await store.importBook(from: try makePDF(pages: pages, blocks: blocks))
        let book = try XCTUnwrap(store.books.first)
        await store.ensureLayout(for: book)
        return book
    }

    func testEveryPageIsCroppedToItsTextOnAllFourSides() async throws {
        let store = try makeStore()
        let book = try await importMeasured(store, pages: 24) { _ in [self.text] }

        let crops = try XCTUnwrap(store.pageCrops(for: book), "The book's pages have been measured")
        XCTAssertEqual(crops.count, 24)
        for crop in crops {
            let box = try XCTUnwrap(crop, "An ordinary text page is cropped")
            XCTAssertTrue(box.contains(textFractions), "No text is cut away")
            XCTAssertEqual(box.minX, 0.2, accuracy: 0.03, "The left margin is removed")
            XCTAssertEqual(box.maxX, 0.8, accuracy: 0.03, "The right margin is removed")
            XCTAssertEqual(box.minY, 0.3, accuracy: 0.03, "The bottom margin is removed")
            XCTAssertEqual(box.maxY, 0.9, accuracy: 0.03, "The top margin is removed")
        }
    }

    func testAWideFigureIsNeverClippedAndDoesNotWidenOtherPages() async throws {
        let figure = CGRect(x: 12, y: 200, width: 376, height: 120)
        let store = try makeStore()
        let book = try await importMeasured(store, pages: 40) { $0 == 17 ? [self.text, figure] : [self.text] }

        let crops = try XCTUnwrap(store.pageCrops(for: book))
        let wide = try XCTUnwrap(crops[17])
        XCTAssertLessThanOrEqual(wide.minX, 12.0 / 400, "The figure's left edge stays on screen")
        XCTAssertGreaterThanOrEqual(wide.maxX, 388.0 / 400, "The figure's right edge stays on screen")
        let ordinary = try XCTUnwrap(crops[15])
        XCTAssertEqual(ordinary.minX, 0.2, accuracy: 0.03, "One wide figure does not widen every other page")
        XCTAssertEqual(ordinary.maxX, 0.8, accuracy: 0.03)
    }

    func testAFullPageScanIsLeftExactlyAsPublished() async throws {
        let store = try makeStore()
        let book = try await importMeasured(store, pages: 8) { _ in [CGRect(x: 0, y: 0, width: 400, height: 600)] }

        let crops = try XCTUnwrap(store.pageCrops(for: book), "A scan is still measured")
        XCTAssertTrue(crops.allSatisfy { $0 == nil }, "Ink covering the whole sheet is not cropped")
    }

    func testMeasurementIsReusedAfterRelaunchAndRemovedWithTheBook() async throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        let book = try await importMeasured(store, pages: 6) { _ in [self.text] }
        let measured = try XCTUnwrap(store.pageCrops(for: book))

        let relaunched = try makeStore(container: container)
        await relaunched.load()
        let reopened = try XCTUnwrap(relaunched.books.first)
        XCTAssertEqual(relaunched.pageCrops(for: reopened), measured,
                       "A relaunch opens the book fitted from the stored measurement, without measuring again")

        relaunched.remove(reopened)
        let layouts = sandbox.appendingPathComponent("Library").appendingPathComponent("Layouts")
        let left = (try? FileManager.default.contentsOfDirectory(atPath: layouts.path)) ?? []
        XCTAssertTrue(left.isEmpty, "Removing a book removes its measurement")
    }

    func testApplyingCropsSetsEachPagesCropBoxInPoints() throws {
        let document = try XCTUnwrap(PDFDocument(url: try makePDF(pages: 2) { _ in [] }))
        PageVaultPageLayout.apply([textFractions, nil], to: document)

        let cropped = try XCTUnwrap(document.page(at: 0)).bounds(for: .cropBox)
        XCTAssertEqual(cropped.minX, 80, accuracy: 0.5)
        XCTAssertEqual(cropped.minY, 180, accuracy: 0.5)
        XCTAssertEqual(cropped.width, 240, accuracy: 0.5)
        XCTAssertEqual(cropped.height, 360, accuracy: 0.5)
        XCTAssertEqual(try XCTUnwrap(document.page(at: 1)).bounds(for: .cropBox).width, 400, accuracy: 0.5,
                       "A page without a crop keeps its published box")
    }
}
