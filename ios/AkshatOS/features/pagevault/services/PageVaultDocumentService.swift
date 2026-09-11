import Foundation
import PDFKit
import UIKit

/// The only place import-time PDFKit inspection happens, keeping PDFKit out of the domain layer.
/// Inspection opens the document lazily: it reads page count and metadata without rendering pages
/// or loading the file into memory.
protocol PageVaultDocumentInspecting: Sendable {
    func inspect(_ url: URL) throws -> PageVaultDocumentService.Inspection
    func coverPNG(of url: URL, maxPixel: CGFloat) -> Data?
    func inkSurvey(of url: URL, progress: @escaping @Sendable (Double) -> Void) -> PageVaultInkSurvey?
}

struct PageVaultDocumentService: PageVaultDocumentInspecting {
    struct Inspection: Equatable {
        var pageCount: Int
        var metadataTitle: String?
    }

    func inspect(_ url: URL) throws -> Inspection {
        guard let document = PDFDocument(url: url) else { throw PageVaultImportFailure.unreadable }
        guard !document.isLocked else { throw PageVaultImportFailure.passwordProtected }
        guard document.pageCount > 0 else { throw PageVaultImportFailure.noPages }
        let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        return Inspection(pageCount: document.pageCount, metadataTitle: title)
    }

    /// Renders page one only. Covers are regenerable, so a failure here is never fatal.
    func coverPNG(of url: URL, maxPixel: CGFloat = 600) -> Data? {
        guard let document = PDFDocument(url: url), !document.isLocked,
              let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .cropBox)
        let longest = max(bounds.width, bounds.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxPixel / longest)
        let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        return page.thumbnail(of: size, for: .cropBox).pngData()
    }

    /// Measures where the text sits on every page, once per book, so the reader can crop each page
    /// to it. Nil for a document that cannot be opened.
    func inkSurvey(of url: URL, progress: @escaping @Sendable (Double) -> Void) -> PageVaultInkSurvey? {
        guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else {
            return nil
        }
        return PageVaultPageLayout().survey(of: document, progress: progress)
    }
}
