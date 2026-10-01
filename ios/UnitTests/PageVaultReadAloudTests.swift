import PDFKit
import UIKit
import XCTest
@testable import AkshatOS

/// Read-aloud against real PDFs: the text layer PDFKit exposes, a running header and page numbers
/// on every page, sentences crossing pages with skip, and a book with no text at all. Each test is
/// synchronous, so the voice finishing a sentence cannot move reading on between two assertions.
@MainActor final class PageVaultReadAloudTests: XCTestCase {
    private var sandbox: URL!
    private var suite: String!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pagevault-readaloud-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        suite = "pagevault-readaloud-\(UUID().uuidString)"
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
        UserDefaults().removePersistentDomain(forName: suite)
    }

    private var defaults: UserDefaults { UserDefaults(suiteName: suite)! }

    /// Each page: the book's title as a running header, two body lines, its page number at the foot.
    private func makeBook(_ pages: [[String]]) throws -> URL {
        let url = sandbox.appendingPathComponent("book-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        let font: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
        try renderer.writePDF(to: url) { context in
            for (index, lines) in pages.enumerated() {
                context.beginPage()
                ("Atomic Test Book" as NSString).draw(at: CGPoint(x: 36, y: 20), withAttributes: font)
                for (row, line) in lines.enumerated() {
                    (line as NSString).draw(at: CGPoint(x: 36, y: 80 + CGFloat(row) * 20), withAttributes: font)
                }
                ("\(index + 1)" as NSString).draw(at: CGPoint(x: 196, y: 560), withAttributes: font)
            }
        }
        return url
    }

    private let book = [
        ["The first sentence of page one is here.", "The second sentence follows it closely."],
        ["Page two begins with this sentence.", "And it ends with this one."],
        ["The third page has only one sentence in it."]
    ]

    func testReadsFromAPageSkippingTheHeaderAndPageNumber() throws {
        let narrator = PageVaultNarrator(url: try makeBook(book), title: "Atomic Test Book",
                                         pageCount: 3, defaults: defaults)
        narrator.play(from: 0)
        XCTAssertEqual(narrator.state, .playing)
        XCTAssertEqual(narrator.page, 0)
        XCTAssertEqual(narrator.segment?.spoken, "The first sentence of page one is here.",
                       "The running header and the page number are not read")
        let text = try XCTUnwrap(PDFDocument(url: try makeBook(book))?.page(at: 0)?.string)
        let mark = try XCTUnwrap(narrator.segment)
        XCTAssertEqual(String(Array(text)[mark.offset..<(mark.offset + mark.length)]),
                       "The first sentence of page one is here.",
                       "The sentence's place matches PDFKit's own text, so the reader can tint it")
        narrator.stop()
    }

    func testSkippingCrossesPagesAndTurnsThem() throws {
        let narrator = PageVaultNarrator(url: try makeBook(book), title: "Atomic Test Book",
                                         pageCount: 3, defaults: defaults)
        var turned: [Int] = []
        narrator.onPageTurn = { turned.append($0) }
        narrator.play(from: 0)
        narrator.skip(1)
        XCTAssertEqual(narrator.segment?.spoken, "The second sentence follows it closely.")
        narrator.skip(1)
        XCTAssertEqual(narrator.page, 1)
        XCTAssertEqual(narrator.segment?.spoken, "Page two begins with this sentence.")
        XCTAssertEqual(turned, [1], "Moving onto the next page turns the reader to it")
        narrator.skip(-1)
        XCTAssertEqual(narrator.page, 0)
        XCTAssertEqual(narrator.segment?.spoken, "The second sentence follows it closely.",
                       "Back from a page's first sentence is the previous page's last")
        XCTAssertEqual(turned, [1, 0])
        narrator.stop()
    }

    func testPauseResumeAndStop() throws {
        let narrator = PageVaultNarrator(url: try makeBook(book), title: "Atomic Test Book",
                                         pageCount: 3, defaults: defaults)
        narrator.play(from: 2)
        XCTAssertEqual(narrator.segment?.spoken, "The third page has only one sentence in it.")
        narrator.pause()
        XCTAssertEqual(narrator.state, .paused)
        narrator.toggle()
        XCTAssertEqual(narrator.state, .playing)
        narrator.stop()
        XCTAssertEqual(narrator.state, .stopped)
        XCTAssertNil(narrator.segment, "Stopping clears the tinted sentence")
        narrator.skip(1)
        XCTAssertEqual(narrator.state, .stopped, "Skip does nothing once stopped")
    }

    func testTurningThePageByHandMovesReadingThere() throws {
        let narrator = PageVaultNarrator(url: try makeBook(book), title: "Atomic Test Book",
                                         pageCount: 3, defaults: defaults)
        narrator.play(from: 0)
        narrator.pause()
        narrator.follow(page: 1)
        XCTAssertEqual(narrator.state, .paused, "A paused reading stays paused on the new page")
        XCTAssertEqual(narrator.page, 1)
        XCTAssertEqual(narrator.segment?.spoken, "Page two begins with this sentence.")
        narrator.toggle()
        XCTAssertEqual(narrator.state, .playing)
        XCTAssertEqual(narrator.segment?.spoken, "Page two begins with this sentence.",
                       "Play starts at the top of the page you turned to")
        narrator.follow(page: 2)
        XCTAssertEqual(narrator.segment?.spoken, "The third page has only one sentence in it.")
        narrator.stop()
        narrator.follow(page: 0)
        XCTAssertEqual(narrator.state, .stopped, "Turning pages after stopping does not start reading")
    }

    func testABookWithNoTextSaysSoInsteadOfPlaying() throws {
        let url = sandbox.appendingPathComponent("image-only.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            UIColor.gray.setFill()
            context.fill(CGRect(x: 40, y: 40, width: 320, height: 520))
        }
        let narrator = PageVaultNarrator(url: url, title: "Scan", pageCount: 1, defaults: defaults)
        narrator.play(from: 0)
        XCTAssertEqual(narrator.state, .stopped)
        XCTAssertEqual(narrator.notice, "This book has no text to read aloud.")
    }

    func testTheChosenSpeedIsRemembered() throws {
        let url = try makeBook(book)
        let first = PageVaultNarrator(url: url, title: "Atomic Test Book", pageCount: 3, defaults: defaults)
        XCTAssertEqual(first.speed, 1, "Normal speed until one is chosen")
        first.speed = 1.5
        let next = PageVaultNarrator(url: url, title: "Atomic Test Book", pageCount: 3, defaults: defaults)
        XCTAssertEqual(next.speed, 1.5)
        defaults.set(9.0, forKey: "pagevault.readAloud.speed")
        let odd = PageVaultNarrator(url: url, title: "Atomic Test Book", pageCount: 3, defaults: defaults)
        XCTAssertEqual(odd.speed, 1, "A speed that is not on offer falls back to normal")
    }
}
