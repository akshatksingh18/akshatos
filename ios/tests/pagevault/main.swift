import Foundation

let reference = Date(timeIntervalSince1970: 1_788_480_000)
func book(pages: Int = 100, page: Int = 0, fingerprint: String = "aaa",
          title: String = "A Long Book", opened: Date? = nil) -> PageVaultBook {
    PageVaultBook(fingerprint: fingerprint, title: title, pageCount: pages,
                  byteCount: 1_024, addedAt: reference, lastOpenedAt: opened, currentPage: page)
}

// A persisted page must never escape the document's real range.
assert(book(pages: 300, page: 42).resolvedPage() == 42, "A valid page is preserved")
assert(book(pages: 300, page: 900).resolvedPage() == 299, "A stale page falls back to the last page")
assert(book(pages: 300, page: -5).resolvedPage() == 0, "A negative page falls back to the first page")
assert(book(pages: 0, page: 7).resolvedPage() == 0, "A document with no pages resolves to zero")
assert(book(pages: 300, page: 10).resolvedPage(120) == 120, "An explicit request is clamped too")
assert(book(pages: 300, page: 10).progressLabel == "11 / 300", "Progress is one-based for display")
assert(book(pages: 0).progressLabel == "No pages", "A pageless document does not claim progress")

var reading = book(pages: 300)
reading.remember(page: 5_000, at: reference)
assert(reading.currentPage == 299 && reading.lastOpenedAt == reference,
       "Remembering a page clamps it and records the read time")

// Titles come from PDF metadata when it is meaningful, and the file name otherwise.
assert(PageVaultBook.displayTitle(metadataTitle: "Real Title", fileName: "scan01.pdf") == "Real Title")
assert(PageVaultBook.displayTitle(metadataTitle: "   ", fileName: "My Book.pdf") == "My Book",
       "Blank metadata falls back to the file name without its extension")
assert(PageVaultBook.displayTitle(metadataTitle: nil, fileName: ".pdf") == "Untitled document",
       "An empty name after trimming never produces a blank title")
assert(PageVaultBook.displayTitle(metadataTitle: nil, fileName: "notes") == "notes",
       "A source without an extension is kept as written")
print("PASS: 12 book assertions (page clamping, progress, resume, title derivation)")

var library = PageVaultLibrary()
try library.insert(book(fingerprint: "one", title: "First"))
var duplicateRejected = false
do {
    try library.insert(book(fingerprint: "one", title: "Same Content, Different Name"))
} catch let failure as PageVaultImportFailure {
    duplicateRejected = failure == .duplicate(title: "First")
} catch {
    duplicateRejected = false
}
assert(duplicateRejected, "A repeated content fingerprint is rejected and names the existing book")
assert(library.books.count == 1, "A rejected duplicate leaves no second entry")
try library.insert(book(fingerprint: "two", title: "Second", opened: reference.addingTimeInterval(60)))
assert(library.recent.first?.title == "Second", "Recently read sorts ahead of merely imported")
var progressed = library.books[0]
progressed.remember(page: 3, at: reference.addingTimeInterval(600))
library.update(progressed)
assert(library.recent.first?.title == "First", "Reading a book moves it back to the front")
assert(library.existing(fingerprint: "two")?.title == "Second", "Fingerprint lookup finds the owner")
let removed = library.remove(id: progressed.id)
assert(removed?.title == "First" && library.books.count == 1, "Removal returns and detaches one book")
assert(library.remove(id: UUID()) == nil, "Removing an unknown book is a no-op")
let encoded = try JSONEncoder().encode(library)
let restored = try JSONDecoder().decode(PageVaultLibrary.self, from: encoded)
assert(restored == library, "The library survives a persistence round trip")
print("PASS: 8 library assertions (fingerprint dedupe, recency, update, removal, round trip)")

// Outline hierarchy is preserved as indent levels; PageVault never invents a table of contents.
let outline = [
    PageVaultOutlineNode(id: "0", title: "Part One", page: 0, children: [
        PageVaultOutlineNode(id: "0.0", title: "Chapter 1", page: 2),
        PageVaultOutlineNode(id: "0.1", title: "Chapter 2", page: 40, children: [
            PageVaultOutlineNode(id: "0.1.0", title: "A Section", page: 44)
        ])
    ]),
    PageVaultOutlineNode(id: "1", title: "Unlinked Appendix", page: nil)
]
let rows = PageVaultOutlineNode.rows(outline)
assert(rows.map(\.id) == ["0", "0.0", "0.1", "0.1.0", "1"], "Rows keep depth-first order")
assert(rows.map(\.level) == [0, 1, 1, 2, 0], "Indent level mirrors outline depth")
assert(rows.last?.page == nil, "An outline entry without a destination stays unlinked")
assert(PageVaultOutlineNode.rows([]).isEmpty, "A PDF with no outline produces no rows")
print("PASS: 4 outline assertions (order, depth, unlinked entries, empty outline)")

assert(PageVaultImportFailure.passwordProtected.message.contains("password"),
       "Encrypted files fail with an explanation")
assert(PageVaultImportFailure.storage("no space").message.contains("no space"),
       "Storage failures surface their reason")
assert(PageVaultImportFailure.unreadable != PageVaultImportFailure.noPages,
       "Distinct failures stay distinguishable")
print("PASS: 3 import failure assertions (encrypted, storage reason, distinct cases)")
