import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Chicago")!
let reference = Date(timeIntervalSince1970: 1_788_480_000)
func day(_ number: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 9, day: number, hour: 12))!
}
func book(pages: Int = 100, placed: Int? = nil, fingerprint: String = "aaa",
          title: String = "A Long Book", opened: Date? = nil) -> PageVaultBook {
    PageVaultBook(fingerprint: fingerprint, title: title, pageCount: pages,
                  byteCount: 1_024, addedAt: reference, lastOpenedAt: opened,
                  currentPage: placed ?? 0, placeSetAt: placed == nil ? nil : reference)
}

// A persisted place can outlive the page count it was valid for, so every read clamps.
assert(book(pages: 300, placed: 42).resolvedPage() == 42, "A valid place is preserved")
assert(book(pages: 300, placed: 900).resolvedPage() == 299, "A stale place falls back to the last page")
assert(book(pages: 300, placed: -5).resolvedPage() == 0, "A negative place falls back to the first page")
assert(book(pages: 0, placed: 7).resolvedPage() == 0, "A document with no pages resolves to zero")
assert(book(pages: 300, placed: 10).resolvedPage(120) == 120, "An explicit request is clamped too")

// Opening lands on the bookmark, or page one when the book was never bookmarked.
assert(book(pages: 300).openingPage == 0, "An unbookmarked book opens at the first page")
assert(book(pages: 300, placed: 87).openingPage == 87, "A bookmarked book opens at your place")
assert(!book(pages: 300).hasPlace && book(pages: 300, placed: 0).hasPlace,
       "A bookmark on page one is still a bookmark")
assert(book(pages: 300).progressLabel == "Not started · 300 pages",
       "An unbookmarked book does not claim progress")
assert(book(pages: 300, placed: 10).progressLabel == "11 / 300", "Progress is one-based for display")
assert(book(pages: 0).progressLabel == "No pages", "A pageless document has no progress label")
assert(book(pages: 300).progressFraction == 0, "An unbookmarked book shows an empty bar")
assert(book(pages: 300, placed: 299).progressFraction == 1, "A place on the last page fills the bar")

// Only bookmarking moves your place. Reading past it, or browsing back, must not.
var reading = book(pages: 300, placed: 8)
reading.markOpened(at: day(2))
assert(reading.currentPage == 8 && reading.hasPlace,
       "Opening a book leaves your place exactly where you bookmarked it")
reading.setPlace(page: 11, at: day(2))
assert(reading.currentPage == 11 && reading.placeSetAt == day(2) && reading.lastOpenedAt == day(2),
       "Bookmarking replaces the previous place instead of accumulating one more")
reading.setPlace(page: 5_000, at: day(3))
assert(reading.currentPage == 299, "A bookmark beyond the document clamps into range")
assert(reading.isPlace(page: 299) && !reading.isPlace(page: 298),
       "Only the bookmarked page reports as your place")
assert(!book(pages: 300).isPlace(page: 0), "An unbookmarked first page is not a place")
reading.clearPlace(at: day(4))
assert(!reading.hasPlace && reading.currentPage == 0 && reading.openingPage == 0,
       "Clearing your place returns the book to opening at page one")

// Titles come from PDF metadata when it is meaningful, and the file name otherwise.
assert(PageVaultBook.displayTitle(metadataTitle: "Real Title", fileName: "scan01.pdf") == "Real Title")
assert(PageVaultBook.displayTitle(metadataTitle: "   ", fileName: "My Book.pdf") == "My Book",
       "Blank metadata falls back to the file name without its extension")
assert(PageVaultBook.displayTitle(metadataTitle: nil, fileName: ".pdf") == "Untitled document",
       "An empty name after trimming never produces a blank title")
assert(PageVaultBook.displayTitle(metadataTitle: nil, fileName: "notes") == "notes",
       "A source without an extension is kept as written")
print("PASS: 23 book and place assertions (clamping, opening page, progress, bookmark, titles)")

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
let firstID = library.books[0].id
assert(library.setPlace(page: 3, for: firstID, at: reference.addingTimeInterval(600))?.currentPage == 3,
       "The library moves a book's place")
assert(library.recent.first?.title == "First", "Bookmarking a book moves it back to the front")
assert(library.existing(fingerprint: "two")?.title == "Second", "Fingerprint lookup finds the owner")
assert(library.clearPlace(for: firstID, at: reference)?.hasPlace == false,
       "The library can clear a place")
assert(library.setPlace(page: 1, for: UUID(), at: reference) == nil,
       "An unknown book cannot be bookmarked")
let removed = library.remove(id: firstID)
assert(removed?.title == "First" && library.books.count == 1, "Removal returns and detaches one book")
assert(library.remove(id: UUID()) == nil, "Removing an unknown book is a no-op")
let encoded = try JSONEncoder().encode(library)
let restored = try JSONDecoder().decode(PageVaultLibrary.self, from: encoded)
assert(restored == library, "The library survives a persistence round trip")
print("PASS: 11 library assertions (dedupe, recency, place, removal, round trip)")

// Only one book is Reading at a time, and the previous one is demoted, never finished.
var shelf = PageVaultLibrary()
try shelf.insert(book(fingerprint: "a", title: "Alpha"))
try shelf.insert(book(fingerprint: "b", title: "Beta"))
let alpha = shelf.books[0].id
let beta = shelf.books[1].id
assert(shelf.books.allSatisfy { $0.status == .wantToRead }, "Imports default to Want to read")
assert(shelf.current == nil, "Nothing is being read yet")
var changed = shelf.setStatus(.reading, for: alpha, at: day(1))
assert(changed.count == 1 && shelf.current?.id == alpha, "Marking Reading reports one change")
changed = shelf.setStatus(.reading, for: beta, at: day(2))
assert(shelf.current?.id == beta, "The newest Reading choice wins")
assert(shelf.books.first { $0.id == alpha }?.status == .wantToRead,
       "The previous Reading book is demoted to Want to read, never Finished")
assert(changed.count == 2, "Both the demoted and promoted books are reported for persistence")
assert(shelf.setStatus(.reading, for: beta, at: day(3)).isEmpty, "Re-selecting the same status is a no-op")
assert(shelf.setStatus(.reading, for: UUID(), at: day(3)).isEmpty, "An unknown book cannot change status")
shelf.setStatus(.finished, for: beta, at: day(4))
assert(shelf.current == nil, "Finishing the only Reading book leaves nothing being read")
assert(shelf.books(with: .finished).count == 1 && shelf.books(with: .wantToRead).count == 1,
       "Shelves group by status")
// Started is a shelf, not a status: Want to Read books that already carry a place.
var shelves = PageVaultLibrary()
try shelves.insert(book(placed: 30, fingerprint: "set-aside", title: "Set Aside"))
try shelves.insert(book(fingerprint: "unopened", title: "Unopened"))
try shelves.insert(book(placed: 5, fingerprint: "current", title: "Current"))
try shelves.insert(book(placed: 99, fingerprint: "done", title: "Done"))
shelves.setStatus(.reading, for: shelves.books[2].id, at: day(1))
shelves.setStatus(.finished, for: shelves.books[3].id, at: day(1))
assert(shelves.started.map(\.title) == ["Set Aside"],
       "A bookmarked Want to Read book shelves under Started, and Reading or Finished books do not")
assert(shelves.unstarted.map(\.title) == ["Unopened"], "An unbookmarked book stays on Want to read")
assert(shelves.started.count + shelves.unstarted.count == shelves.books(with: .wantToRead).count,
       "Started and Want to read split one status without losing or repeating a book")
shelves.clearPlace(for: shelves.books[0].id, at: day(2))
assert(shelves.started.isEmpty && shelves.unstarted.count == 2,
       "Clearing a place moves the book back to Want to read")
print("PASS: 14 status assertions (default, single Reading book, demotion, shelves, started shelf)")

// Records written by earlier builds must keep loading, including ones with fields since removed.
let legacy = Data("""
{"id":"5B8C1B16-5F2E-44B6-9A0E-4E3B0F6A11AA","fingerprint":"old","title":"Legacy Book",
 "pageCount":120,"byteCount":2048,"addedAt":0,"currentPage":7,
 "bookmarks":[{"id":"1B8C1B16-5F2E-44B6-9A0E-4E3B0F6A11AA","page":4,"createdAt":0}]}
""".utf8)
let upgraded = try JSONDecoder().decode(PageVaultBook.self, from: legacy)
assert(upgraded.status == .wantToRead, "An older payload defaults to Want to read")
assert(upgraded.currentPage == 7, "An older payload keeps its stored page")
assert(!upgraded.hasPlace, "A payload from before places existed is treated as unbookmarked")
assert(upgraded.lastOpenedAt == nil, "Absent optional timestamps decode as nil rather than failing")

let minimal = Data("""
{"id":"9C1F0C7E-1A2B-4C3D-8E4F-5A6B7C8D9E0F","fingerprint":"tiny","title":"Tiny",
 "pageCount":3,"byteCount":10,"addedAt":0}
""".utf8)
let tiny = try JSONDecoder().decode(PageVaultBook.self, from: minimal)
assert(tiny.currentPage == 0 && tiny.status == .wantToRead && !tiny.hasPlace,
       "A minimal record loads with defaults instead of throwing")

let corruptRecord = Data("""
{"id":"9C1F0C7E-1A2B-4C3D-8E4F-5A6B7C8D9E0F","title":"No fingerprint","pageCount":3,
 "byteCount":10,"addedAt":0}
""".utf8)
var rejectedCorruptRecord = false
do {
    _ = try JSONDecoder().decode(PageVaultBook.self, from: corruptRecord)
} catch {
    rejectedCorruptRecord = true
}
assert(rejectedCorruptRecord, "Leniency applies to added fields only, never to identity")
print("PASS: 6 payload migration assertions (defaults, removed fields, minimal, corrupt)")

assert(PageVaultImportFailure.passwordProtected.message.contains("password"),
       "Encrypted files fail with an explanation")
assert(PageVaultImportFailure.storage("no space").message.contains("no space"),
       "Storage failures surface their reason")
assert(PageVaultImportFailure.unreadable != PageVaultImportFailure.noPages,
       "Distinct failures stay distinguishable")
print("PASS: 3 import failure assertions (encrypted, storage reason, distinct cases)")

// Fitting pages to their text. One shared text area keeps text the same size on every page, and no
// page is ever clipped: a page with ink beyond that area gets a larger box of its own.
func ink(_ minX: Double, _ minY: Double, _ maxX: Double, _ maxY: Double) -> PageVaultInkBox {
    PageVaultInkBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
}
func near(_ first: Double, _ second: Double) -> Bool { abs(first - second) < 0.0005 }
/// Crop boxes reached by different arithmetic can differ in the last floating-point digit.
func sameBox(_ first: PageVaultInkBox?, _ second: PageVaultInkBox?) -> Bool {
    guard let first, let second else { return first == nil && second == nil }
    return near(first.minX, second.minX) && near(first.minY, second.minY)
        && near(first.maxX, second.maxX) && near(first.maxY, second.maxY)
}
func neverClips(_ survey: [PageVaultInkBox?]) -> Bool {
    zip(survey, PageVaultCrop.cropBoxes(for: survey)).allSatisfy { box, crop in
        guard let box, !box.isEmpty, let crop else { return true }
        return crop.contains(box)
    }
}

let body = [PageVaultInkBox?](repeating: ink(0.20, 0.15, 0.80, 0.85), count: 40)
let bodyCrops = PageVaultCrop.cropBoxes(for: body)
assert(bodyCrops.allSatisfy { $0 == bodyCrops[0] } && near(bodyCrops[0]!.minX, 0.188)
       && near(bodyCrops[0]!.maxX, 0.812) && near(bodyCrops[0]!.minY, 0.138)
       && near(bodyCrops[0]!.maxY, 0.862),
       "Every ordinary page is cropped to one padded text area, trimmed from all four sides")

var stray = body
stray[7] = ink(0.02, 0.15, 0.80, 0.85)
let strayCrops = PageVaultCrop.cropBoxes(for: stray)
assert(sameBox(strayCrops[9], bodyCrops[9]), "One stray mark does not widen every other page")
assert(near(strayCrops[7]!.minX, 0.008) && strayCrops[7]!.contains(stray[7]!),
       "The page carrying the mark gets a box grown to contain it rather than being clipped")

var short = [PageVaultInkBox?](repeating: ink(0.20, 0.15, 0.80, 0.85), count: 5)
short[2] = ink(0.10, 0.15, 0.90, 0.85)
assert(PageVaultCrop.cropBoxes(for: short).allSatisfy { near($0!.minX, 0.088) },
       "A short document has too few pages to call anything an outlier, so its area covers them all")

let facing: [PageVaultInkBox?] = (0..<40).map {
    $0 % 2 == 0 ? ink(0.25, 0.10, 0.85, 0.90) : ink(0.15, 0.10, 0.70, 0.90)
}
let facingCrops = PageVaultCrop.cropBoxes(for: facing)
assert(near(facingCrops[0]!.minX, 0.238) && near(facingCrops[1]!.minX, 0.113),
       "Left and right pages are positioned on their own text rather than on a union of both")
assert(near(facingCrops[0]!.width, facingCrops[1]!.width),
       "Facing pages share one box size, so text is the same size on both")

var mixed = body
mixed[3] = ink(0, 0, 1, 1)
mixed[4] = PageVaultInkBox.blank
mixed[5] = nil
let mixedCrops = PageVaultCrop.cropBoxes(for: mixed)
assert(mixedCrops[3] == nil, "A full-page image or scan is left exactly as published")
assert(sameBox(mixedCrops[4], bodyCrops[4]), "A blank page takes the shared area, so paging stays steady")
assert(mixedCrops[5] == nil, "A page that could not be measured is left alone rather than guessed at")
assert(PageVaultCrop.cropBoxes(for: [PageVaultInkBox?](repeating: ink(0, 0, 1, 1), count: 12))
       .allSatisfy { $0 == nil }, "A scanned book whose ink covers every sheet is not cropped at all")
assert(PageVaultCrop.cropBoxes(for: [PageVaultInkBox?](repeating: ink(0.01, 0.02, 0.99, 0.975), count: 12))
       .allSatisfy { $0 == nil }, "A document already trimmed tight is not re-cropped for no gain")
assert([body, stray, short, facing, mixed].allSatisfy(neverClips), "No page's ink is ever cropped away")

let slid = PageVaultCrop.sized(ink(0.90, 0.10, 0.95, 0.20), width: 0.30, height: 0.30)
assert(near(slid.maxX, 1) && near(slid.width, 0.30) && slid.minY >= 0,
       "A box resized near the edge slides back onto the page instead of running off it")

// Measuring ink on a rendered page: bitmap rows run top-down, page coordinates bottom-up.
func bitmap(_ width: Int, _ height: Int, paper: UInt8, marks: [(Int, Int)], tone: UInt8 = 0) -> [UInt8] {
    var pixels = [UInt8](repeating: paper, count: width * height)
    for (row, column) in marks { pixels[row * width + column] = tone }
    return pixels
}
let block = (2...5).flatMap { row in (3...6).map { (row, $0) } }
let found = PageVaultInkScan.inkBox(pixels: bitmap(10, 10, paper: 255, marks: block), width: 10, height: 10)
assert(found == ink(0.3, 0.4, 0.7, 0.8), "Ink bounds are found, with bitmap rows inverted into page coordinates")
let speckled = PageVaultInkScan.inkBox(pixels: bitmap(10, 10, paper: 255, marks: block + [(9, 9)]),
                                       width: 10, height: 10)
assert(speckled == found, "A lone speck of dust does not stretch the text area")
let yellowed = PageVaultInkScan.inkBox(pixels: bitmap(10, 10, paper: 200, marks: block, tone: 120),
                                       width: 10, height: 10)
assert(yellowed == found, "An off-white scan still has margins, because ink is judged against its own paper")
let blankScan = PageVaultInkScan.inkBox(pixels: bitmap(10, 10, paper: 250, marks: []), width: 10, height: 10)
assert(blankScan?.isEmpty == true, "A blank page reports no ink")
let darkScan = PageVaultInkScan.inkBox(pixels: bitmap(10, 10, paper: 20, marks: []), width: 10, height: 10)
assert(darkScan.map(PageVaultCrop.isFullBleed) == true,
       "A page that is dark all over counts as a full-page image")
assert(PageVaultInkScan.inkBox(pixels: [255, 255], width: 10, height: 10) == nil,
       "A bitmap that does not match its dimensions is rejected")

let survey = PageVaultInkSurvey(boxes: [ink(0.1, 0.1, 0.9, 0.9), nil, PageVaultInkBox.blank])
assert(survey.isCurrent(pageCount: 3) && !survey.isCurrent(pageCount: 4),
       "A measurement only applies to a document with the page count it measured")
assert(!PageVaultInkSurvey(version: 0, boxes: survey.boxes).isCurrent(pageCount: 3),
       "A measurement taken by an older method is retaken rather than trusted")
let surveyRoundTrip = try JSONDecoder().decode(PageVaultInkSurvey.self, from: JSONEncoder().encode(survey))
assert(surveyRoundTrip == survey, "A measurement with unmeasured and blank pages survives the cache round trip")
print("PASS: 22 layout assertions (four-sided crop, outliers, facing pages, scans, blank pages, ink scan, cache)")

// Export and restore. The manifest is validated whole, and restore planning never breaks the
// single-Reading rule or silently overwrites a book already in the library.
func digest(_ seed: Character) -> String { String(repeating: seed, count: 64) }
func exportable(_ seed: Character, title: String, placed: Int? = nil,
                status: PageVaultReadingStatus = .wantToRead) -> PageVaultBook {
    var made = book(pages: 100, placed: placed, fingerprint: digest(seed), title: title)
    made.status = status
    return made
}
func manifest(_ entries: [PageVaultBackupEntry], documents: Bool = true,
              version: Int = PageVaultBackup.currentVersion) -> PageVaultBackup {
    PageVaultBackup(version: version, createdAt: reference, includesDocuments: documents,
                    entries: entries)
}
func rejection(_ candidate: PageVaultBackup) -> PageVaultBackupError? {
    do { _ = try candidate.validated(); return nil } catch { return error as? PageVaultBackupError }
}
func decodeFailure(_ data: Data) -> PageVaultBackupError? {
    do { _ = try PageVaultBackup.decode(data); return nil } catch { return error as? PageVaultBackupError }
}

var exportLibrary = PageVaultLibrary()
try exportLibrary.insert(exportable("a", title: "Deep: Work / Notes?", placed: 40, status: .reading))
try exportLibrary.insert(exportable("b", title: "Deep: Work / Notes?"))
try exportLibrary.insert(exportable("c", title: "   "))
let readingID = exportLibrary.books[0].id
let full = PageVaultBackup(createdAt: reference, library: exportLibrary, includesDocuments: true)
let files = full.entries.compactMap(\.file)
let alphaFile = full.entries.first(where: { $0.book.fingerprint == digest("a") })?.file ?? ""
let blankFile = full.entries.first(where: { $0.book.fingerprint == digest("c") })?.file ?? ""
assert(full.entries.count == 3, "Every book in the library is exported")
assert(files.count == 3 && Set(files.map { $0.lowercased() }).count == 3,
       "Two books sharing a title still export to distinct files")
assert(files.allSatisfy(PageVaultBackup.isSafeDocumentPath),
       "Every generated path passes the check a restore applies")
assert(alphaFile.hasPrefix("books/Deep Work Notes ") && alphaFile.hasSuffix(".pdf"),
       "Titles are cleaned into Windows-safe file names")
assert(blankFile.hasPrefix("books/Book "), "A blank title still produces a usable file name")
let decodedFull = try PageVaultBackup.decode(full.encoded())
assert(decodedFull == full, "A full export manifest survives encoding")
let dataOnly = PageVaultBackup(createdAt: reference, library: exportLibrary, includesDocuments: false)
let decodedData = try PageVaultBackup.decode(dataOnly.encoded())
assert(decodedData == dataOnly && dataOnly.entries.allSatisfy({ $0.file == nil }),
       "A reading-data export carries no document paths and survives encoding")

let alphaBook = exportable("a", title: "Alpha")
let good = PageVaultBackupEntry(book: alphaBook, file: "books/Alpha.pdf")
assert(rejection(manifest([good])) == nil, "A well-formed manifest validates")
assert(rejection(manifest([good], version: 2)) == .unsupportedVersion(2),
       "A newer manifest is refused by its version number")
assert(rejection(manifest([good, PageVaultBackupEntry(book: exportable("a", title: "Copy"),
                                                      file: "books/Copy.pdf")])) == .inconsistentLibrary,
       "Two entries with one fingerprint are refused")
assert(rejection(manifest([
    PageVaultBackupEntry(book: exportable("a", title: "A", status: .reading), file: "books/A.pdf"),
    PageVaultBackupEntry(book: exportable("b", title: "B", status: .reading), file: "books/B.pdf"),
])) == .inconsistentLibrary, "An export claiming two Reading books is refused")
for path in ["../Alpha.pdf", "books/../Alpha.pdf", "books/sub/Alpha.pdf", "/books/Alpha.pdf",
             "books/.pdf", "books/Alpha.txt", "Books/Alpha.pdf", "books/C:Alpha.pdf"] {
    assert(rejection(manifest([PageVaultBackupEntry(book: alphaBook, file: path)])) == .inconsistentLibrary,
           "The unsafe document path \(path) is refused")
}
assert(rejection(manifest([good, PageVaultBackupEntry(book: exportable("b", title: "B"),
                                                      file: "books/ALPHA.pdf")])) == .inconsistentLibrary,
       "Two documents differing only by letter case would collide on disk, so they are refused")
assert(rejection(manifest([PageVaultBackupEntry(book: alphaBook, file: nil)])) == .inconsistentLibrary,
       "A full export must say where every PDF is")
assert(rejection(manifest([good], documents: false)) == .inconsistentLibrary,
       "A reading-data export cannot claim document paths")
assert(rejection(manifest([PageVaultBackupEntry(book: book(fingerprint: "not-a-digest"),
                                                file: "books/X.pdf")])) == .inconsistentLibrary,
       "Fingerprints must be SHA-256 hex, because they double as checksums")
assert(decodeFailure(Data("not json".utf8)) == .invalidFile, "A file that is not a manifest is refused")
assert(decodeFailure(Data(#"{"version":7,"future":true}"#.utf8)) == .unsupportedVersion(7),
       "A newer manifest reports its version instead of looking corrupt")
assert(decodeFailure(Data(count: PageVaultBackup.maximumManifestBytes + 1)) == .tooLarge,
       "An oversized file is refused before it is parsed")

var here = PageVaultLibrary()
try here.insert(exportable("a", title: "Alpha", placed: 3))
try here.insert(exportable("d", title: "Delta", placed: 7, status: .reading))
let hereAlpha = here.books[0].id
let hereDelta = here.books[1].id
let plan = PageVaultRestorePlan(backup: full, library: here)
assert(plan.matches.map(\.existingID) == [hereAlpha] && plan.additions.count == 2
       && plan.missingDocuments.isEmpty,
       "Books are matched by content fingerprint, and the rest of a full export are additions")
let dataPlan = PageVaultRestorePlan(backup: dataOnly, library: here)
assert(dataPlan.matches.count == 1 && dataPlan.additions.isEmpty && dataPlan.missingDocuments.count == 2,
       "Reading data can only restore books whose PDFs are already here")

let added = plan.applied(to: here, backup: full, mode: .addMissing, at: day(5))
let keptAlpha = added.library.books.first(where: { $0.id == hereAlpha })
assert(keptAlpha?.currentPage == 3 && keptAlpha?.status == .wantToRead,
       "Only adding leaves a book already here untouched")
assert(added.library.books.count == 4 && added.library.current?.id == hereDelta,
       "An added book never displaces the book already being read")
let replacing = plan.applied(to: here, backup: full, mode: .replaceMatching, at: day(5))
let restoredAlpha = replacing.library.books.first(where: { $0.id == hereAlpha })
assert(restoredAlpha?.currentPage == 40 && restoredAlpha?.hasPlace == true,
       "Replacing gives the book already here the export's place")
assert(replacing.library.current?.id == hereAlpha
       && replacing.library.books.first(where: { $0.id == hereDelta })?.status == .wantToRead,
       "The export's Reading book takes over and the previous one is demoted, never finished")
assert(replacing.library.books.filter({ $0.status == .reading }).count == 1,
       "A restore never leaves two Reading books")
assert(Set(replacing.changedBookIDs).count == replacing.changedBookIDs.count
       && replacing.changedBookIDs.contains(hereDelta),
       "Every changed book is reported once, including the one demoted")

let freshID = UUID()
var clash = PageVaultLibrary()
var clashing = exportable("e", title: "Unrelated")
clashing.id = readingID
try clash.insert(clashing)
let remapped = PageVaultRestorePlan(backup: full, library: clash)
    .applied(to: clash, backup: full, mode: .addMissing, at: day(5), makeID: { freshID })
assert(remapped.additionIDs[readingID] == freshID && remapped.library.books.count == 4,
       "An id already used by a different book is replaced instead of overwriting that book")
assert(remapped.library.current?.id == freshID,
       "With nothing being read, the export's Reading book resumes as the one being read")
print("PASS: 29 backup assertions (manifest round trip, file names, validation, versions, planning, add, replace, id collision)")

// Highlights live on the book, so they travel with an export and leave when the book does.
func passage(_ page: Int, _ text: String, at number: Int = 1) -> PageVaultHighlight {
    PageVaultHighlight(page: page, text: text, createdAt: day(number))
}
assert(PageVaultHighlight.tidy("grit is\npassion and\nperseverance") == "grit is passion and perseverance",
       "A selection broken at every rendered line is rejoined into one sentence")
assert(PageVaultHighlight.tidy("de-\nmanding work") == "demanding work",
       "A word hyphenated across a line break is put back together")
assert(PageVaultHighlight.tidy("  spaced   out \n\n words  ") == "spaced out words",
       "Runs of whitespace collapse and the ends are trimmed")
assert(PageVaultHighlight.tidy("   \n  ").isEmpty, "A selection of pure whitespace produces nothing")
assert(passage(3, String(repeating: "a", count: 200)).preview.count == 140,
       "A long passage previews as one truncated line")
assert(passage(3, "short").preview == "short", "A short passage previews whole")

var marked = book(pages: 300)
marked.addHighlight(passage(12, "the first line", at: 2))
marked.addHighlight(passage(4, "an earlier line", at: 3))
marked.addHighlight(passage(12, "the first line", at: 4))
assert(marked.highlights.count == 2, "Highlighting the same passage twice stores it once")
marked.addHighlight(passage(5, "", at: 5))
assert(marked.highlights.count == 2, "An empty passage is not stored")
assert(marked.highlightsInReadingOrder.map(\.page) == [4, 12],
       "Highlights are listed in the order they appear in the book")
assert(marked.highlights(onPage: 12).count == 1 && marked.highlights(onPage: 7).isEmpty,
       "Highlights can be found by page, which is how the reader redraws them")
assert(marked.highlight(onPage: 12, matching: "the first line") != nil
       && marked.highlight(onPage: 12, matching: "a different line") == nil
       && marked.highlight(onPage: 4, matching: "the first line") == nil,
       "A passage is matched by page and text together, which is what makes the highlighter a toggle")
let doomed = marked.highlightsInReadingOrder[0].id
marked.removeHighlight(id: doomed)
assert(marked.highlights.map(\.page) == [12], "Removing one highlight leaves the others alone")

let markedRoundTrip = try JSONDecoder().decode(PageVaultBook.self,
                                               from: try JSONEncoder().encode(marked))
assert(markedRoundTrip == marked, "Highlights survive the record's persistence round trip")
let beforeHighlights = Data("""
{"id":"7C1F0C7E-1A2B-4C3D-8E4F-5A6B7C8D9E0F","fingerprint":"old","title":"Before Highlights",
 "pageCount":80,"byteCount":64,"addedAt":0}
""".utf8)
let beforeHighlightsBook = try JSONDecoder().decode(PageVaultBook.self, from: beforeHighlights)
assert(beforeHighlightsBook.highlights.isEmpty,
       "A record written before highlights existed loads with none rather than failing")

var shelfWithMarks = PageVaultLibrary()
try shelfWithMarks.insert(book(fingerprint: "marked", title: "Marked"))
let markedID = shelfWithMarks.books[0].id
assert(shelfWithMarks.addHighlight(passage(2, "a line"), for: markedID)?.highlights.count == 1,
       "The library stores a highlight on the book it belongs to")
assert(shelfWithMarks.addHighlight(passage(2, "a line"), for: UUID()) == nil,
       "An unknown book cannot be highlighted")
var keeping = PageVaultLibrary()
try keeping.insert(book(fingerprint: "kept-early", title: "Kept Early"))
try keeping.insert(book(fingerprint: "kept-late", title: "Kept Late"))
try keeping.insert(book(fingerprint: "unmarked", title: "Unmarked"))
keeping.addHighlight(passage(1, "an early line", at: 2), for: keeping.books[0].id)
keeping.addHighlight(passage(2, "a later line", at: 6), for: keeping.books[1].id)
assert(keeping.withHighlights.map(\.title) == ["Kept Late", "Kept Early"],
       "Takeaways lists only books with kept passages, most recently marked first")
assert(keeping.withHighlights.allSatisfy { !$0.highlights.isEmpty },
       "A book nothing was kept from never appears in Takeaways")

let storedHighlightID = shelfWithMarks.books[0].highlights[0].id
assert(shelfWithMarks.removeHighlight(storedHighlightID, for: markedID)?.highlights.isEmpty == true,
       "The library removes a highlight by id")
print("PASS: 19 highlight assertions (tidy, preview, dedupe, ordering, page lookup, toggle match, round trip, older records, library, takeaways)")

// Searching a book's text. Matching and snippets are pure, so they are pinned without a document.
let pageText = "Grit is passion and perseverance. Grit grows when you practise deliberately."
let gritHits = PageVaultSearch.hits(in: pageText, page: 4, query: "grit", limit: 10)
assert(gritHits.count == 2, "Every occurrence on a page is its own result")
assert(gritHits.allSatisfy { $0.page == 4 }, "A hit carries the page it was found on")
assert(gritHits[0].offset == 0 && gritHits[1].offset == 34,
       "A hit carries where on the page it matched")
assert(gritHits[0].id != gritHits[1].id, "Two matches on one page stay distinguishable in a list")
assert(PageVaultSearch.hits(in: pageText, page: 0, query: "GRIT", limit: 10).count == 2,
       "Search ignores letter case")
assert(PageVaultSearch.hits(in: "café society", page: 0, query: "cafe", limit: 5).count == 1,
       "Search ignores accents, so plainly typed letters still find the word")
assert(PageVaultSearch.hits(in: pageText, page: 0, query: "grit", limit: 1).count == 1,
       "The result limit is respected")
assert(PageVaultSearch.hits(in: pageText, page: 0, query: "g", limit: 10).isEmpty,
       "A single letter is not a search")
assert(PageVaultSearch.hits(in: "", page: 0, query: "grit", limit: 10).isEmpty,
       "A page with no text layer yields nothing, which is exactly what a scan gives")
assert(!PageVaultSearch.isSearchable(" a ") && PageVaultSearch.isSearchable(" at "),
       "Whitespace does not pad a query into a search")

let longPage = String(repeating: "x", count: 200) + "needle" + String(repeating: "y", count: 200)
let middleSnippet = PageVaultSearch.snippet(from: longPage, at: 200, length: 6)
assert(middleSnippet.hasPrefix("…") && middleSnippet.hasSuffix("…"),
       "A match inside a long page is shown with ellipses on both sides")
assert(middleSnippet.contains("needle"), "The match itself is in the snippet")
assert(middleSnippet.count == 6 + PageVaultSearch.context * 2 + 2,
       "The snippet keeps a fixed amount of context around the match")
assert(PageVaultSearch.snippet(from: "short and sweet", at: 0, length: 5) == "short and sweet",
       "A short page needs no ellipses")
assert(PageVaultSearch.snippet(from: "line\nbreaks   collapse", at: 0, length: 4) == "line breaks collapse",
       "A snippet reads as one line")
assert(PageVaultSearch.snippet(from: "abc", at: 5, length: 2).isEmpty,
       "An impossible range yields nothing rather than crashing")
print("PASS: 16 search assertions (matching, case, accents, limits, snippets, empty pages)")

// Page themes. The raw values are what an installed build has already written to disk.
assert(PageVaultTheme.allCases.map(\.rawValue) == ["paper", "sepia", "night"],
       "Theme raw values are the stored form and must not be renamed")
assert(PageVaultTheme.allCases.allSatisfy { !$0.label.isEmpty }, "Every theme is named in the menu")
assert(PageVaultTheme.default == .sepia, "Sepia is the default, chosen over the warmer white")
assert(PageVaultTheme.night.inverts && !PageVaultTheme.sepia.inverts && !PageVaultTheme.paper.inverts,
       "Night inverts the page; the others tint it")
assert(PageVaultTheme.stored("sepia") == .sepia, "A stored theme is restored")
assert(PageVaultTheme.stored("warm") == .sepia,
       "A build that chose the retired warm theme lands on sepia rather than losing the choice")
assert(PageVaultTheme.stored("moonlight") == .sepia && PageVaultTheme.stored(nil) == .sepia,
       "An unknown or missing stored theme falls back to the default rather than failing")
print("PASS: 7 theme assertions (stored values, labels, default, inversion, retired warm, fallback)")
