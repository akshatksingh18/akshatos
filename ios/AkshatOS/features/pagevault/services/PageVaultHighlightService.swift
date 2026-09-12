import CoreGraphics
import Foundation
import PDFKit
import UIKit

/// Turns PDFKit text selections into stored highlights, replays stored highlights as annotations,
/// and renders a book's highlights into a small PDF of its own.
///
/// Annotations are added to the in-memory document only. Nothing here writes to the PDF file, so a
/// highlight can never damage the book it came from.
enum PageVaultHighlightService {
    /// The marker colour, used both on the page and on the exported sheet.
    static let marker = UIColor.systemYellow

    /// The colour a search match is tinted on arrival. Deliberately not the marker colour: a
    /// signpost that vanishes on the next page turn must not look like a passage you kept.
    static let finder = UIColor.systemTeal

    /// The selection covering a search match on one page, ready to be tinted.
    ///
    /// The offset arrives counted in characters, as `PageVaultSearch` counts them, while `NSRange`
    /// counts UTF-16 units. Re-slicing the page's own text converts between the two exactly, which
    /// matters wherever a book is not plain Latin script.
    static func selection(for mark: PageVaultFindMark, in document: PDFDocument) -> PDFSelection? {
        guard mark.length > 0, mark.page >= 0, mark.page < document.pageCount,
              let page = document.page(at: mark.page), let text = page.string else { return nil }
        let characters = Array(text)
        guard mark.offset >= 0, mark.offset + mark.length <= characters.count else { return nil }
        let location = String(characters[0..<mark.offset]).utf16.count
        let length = String(characters[mark.offset..<(mark.offset + mark.length)]).utf16.count
        guard length > 0 else { return nil }
        return page.selection(for: NSRange(location: location, length: length))
    }

    /// One capture per page the selection covers, because a passage running across a page break is
    /// two highlights: each needs its own page and its own rectangles.
    struct Capture {
        var page: Int
        var text: String
        var rects: [PageVaultRect]
    }

    static func capture(_ selection: PDFSelection, in document: PDFDocument) -> [Capture] {
        var byPage: [Int: Capture] = [:]
        var order: [Int] = []
        for line in selection.selectionsByLine() {
            guard let page = line.pages.first else { continue }
            let index = document.index(for: page)
            guard index != NSNotFound else { continue }
            let bounds = line.bounds(for: page)
            let text = line.string ?? ""
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if byPage[index] == nil {
                byPage[index] = Capture(page: index, text: text, rects: [])
                order.append(index)
            } else {
                byPage[index]?.text += "\n" + text
            }
            if bounds.width > 0, bounds.height > 0 {
                byPage[index]?.rects.append(PageVaultRect(x: bounds.minX, y: bounds.minY,
                                                          width: bounds.width, height: bounds.height))
            }
        }
        return order.compactMap { byPage[$0] }
    }

    /// Draws every stored highlight onto the open document. Called once after the document is set,
    /// and again whenever a highlight is added or removed.
    static func apply(_ highlights: [PageVaultHighlight], to document: PDFDocument) {
        removeAll(from: document)
        for highlight in highlights {
            guard highlight.page >= 0, highlight.page < document.pageCount,
                  let page = document.page(at: highlight.page) else { continue }
            for rect in highlight.rects where !rect.isEmpty {
                let bounds = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = marker
                // Tags the annotation as ours, so replacing highlights never disturbs anything the
                // document itself carries.
                annotation.userName = highlight.id.uuidString
                page.addAnnotation(annotation)
            }
        }
    }

    private static func removeAll(from document: PDFDocument) {
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            for annotation in page.annotations where annotation.userName != nil {
                page.removeAnnotation(annotation)
            }
        }
    }

    /// Renders the book's highlights as a plain PDF: the title, then every passage with the page it
    /// came from. This is a reading list, not an annotated copy of the book.
    static func exportPDF(for book: PageVaultBook, generatedAt: Date) -> Data {
        let pageSize = CGSize(width: 612, height: 792)
        let margin: CGFloat = 56
        let width = pageSize.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
        let metaFont = UIFont.systemFont(ofSize: 11)
        let pageFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 12)
        let body = NSMutableParagraphStyle()
        body.lineSpacing = 2
        body.alignment = .left

        let stamp = DateFormatter()
        stamp.dateStyle = .long
        stamp.timeStyle = .none

        return renderer.pdfData { context in
            var cursor = margin
            context.beginPage()

            func newPage() {
                context.beginPage()
                cursor = margin
            }

            func draw(_ text: String, font: UIFont, color: UIColor, spacing: CGFloat) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font, .foregroundColor: color, .paragraphStyle: body
                ]
                let string = NSAttributedString(string: text, attributes: attributes)
                var remaining = string
                while remaining.length > 0 {
                    let available = pageSize.height - margin - cursor
                    let full = remaining.boundingRect(with: CGSize(width: width,
                                                                  height: .greatestFiniteMagnitude),
                                                      options: [.usesLineFragmentOrigin], context: nil)
                    if full.height <= available {
                        remaining.draw(with: CGRect(x: margin, y: cursor, width: width, height: full.height),
                                       options: [.usesLineFragmentOrigin], context: nil)
                        cursor += full.height + spacing
                        return
                    }
                    if available < font.lineHeight * 2 {
                        newPage()
                        continue
                    }
                    // Split at the last space that still fits, so a long passage flows onto the next page.
                    let fitting = fittingLength(of: remaining, width: width, height: available)
                    guard fitting > 0 else {
                        newPage()
                        continue
                    }
                    let head = remaining.attributedSubstring(from: NSRange(location: 0, length: fitting))
                    let headHeight = head.boundingRect(with: CGSize(width: width,
                                                                   height: .greatestFiniteMagnitude),
                                                       options: [.usesLineFragmentOrigin], context: nil).height
                    head.draw(with: CGRect(x: margin, y: cursor, width: width, height: headHeight),
                              options: [.usesLineFragmentOrigin], context: nil)
                    remaining = remaining.attributedSubstring(
                        from: NSRange(location: fitting, length: remaining.length - fitting))
                    newPage()
                }
            }

            draw(book.title, font: titleFont, color: .black, spacing: 6)
            let highlights = book.highlightsInReadingOrder
            let count = highlights.count == 1 ? "1 highlight" : "\(highlights.count) highlights"
            draw("\(count) · exported \(stamp.string(from: generatedAt))",
                 font: metaFont, color: .darkGray, spacing: 22)

            for highlight in highlights {
                draw("PAGE \(highlight.page + 1)", font: pageFont, color: .darkGray, spacing: 4)
                draw(highlight.text, font: bodyFont, color: .black, spacing: 18)
            }
        }
    }

    /// The longest prefix of `string` that fits in `height`, ended at a word boundary.
    private static func fittingLength(of string: NSAttributedString, width: CGFloat,
                                      height: CGFloat) -> Int {
        var low = 0
        var high = string.length
        while low < high {
            let middle = (low + high + 1) / 2
            let piece = string.attributedSubstring(from: NSRange(location: 0, length: middle))
            let size = piece.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                          options: [.usesLineFragmentOrigin], context: nil)
            if size.height <= height { low = middle } else { high = middle - 1 }
        }
        guard low > 0, low < string.length else { return low }
        let text = string.string as NSString
        let searchRange = NSRange(location: 0, length: low)
        let space = text.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards,
                                          range: searchRange)
        return space.location == NSNotFound ? low : space.location + 1
    }
}
