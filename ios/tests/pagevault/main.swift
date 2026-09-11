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
assert(shelf.setDailyGoal(20, for: alpha)?.dailyPageGoal == 20, "A goal is stored")
assert(shelf.setDailyGoal(0, for: alpha)?.dailyPageGoal == nil, "A zero goal clears tracking")
assert(shelf.setDailyGoal(-5, for: alpha)?.dailyPageGoal == nil, "A negative goal cannot be stored")
var goalHolder = book(pages: 200)
goalHolder.dailyPageGoal = 10
assert(goalHolder.activeGoal == 0, "A goal only counts while the book is being read")
goalHolder.status = .reading
assert(goalHolder.activeGoal == 10, "The Reading book exposes its goal")

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
print("PASS: 19 status assertions (default, single Reading book, demotion, shelves, goal sanitizing, started shelf)")

// Records written by earlier builds must keep loading, including ones with fields since removed.
let legacy = Data("""
{"id":"5B8C1B16-5F2E-44B6-9A0E-4E3B0F6A11AA","fingerprint":"old","title":"Legacy Book",
 "pageCount":120,"byteCount":2048,"addedAt":0,"currentPage":7,
 "bookmarks":[{"id":"1B8C1B16-5F2E-44B6-9A0E-4E3B0F6A11AA","page":4,"createdAt":0}]}
""".utf8)
let upgraded = try JSONDecoder().decode(PageVaultBook.self, from: legacy)
assert(upgraded.status == .wantToRead, "An older payload defaults to Want to read")
assert(upgraded.dailyPageGoal == nil, "An older payload has no goal")
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
print("PASS: 7 payload migration assertions (defaults, removed fields, minimal, corrupt)")

func readingDay(_ number: Int, book id: UUID, from: Int, to: Int, goal: Int) -> PageVaultReadingDay {
    PageVaultReadingDay(day: PageVaultReadingDay.dayKey(day(number), calendar: calendar),
                        bookID: id, startPage: from, highestPage: to, goal: goal)
}
let tracked = UUID()
assert(PageVaultReadingDay.dayKey(day(4), calendar: calendar) == "2026-09-04", "Day keys are local dates")
var oneDay = readingDay(1, book: tracked, from: 0, to: 5, goal: 10)
assert(oneDay.pagesRead == 5 && !oneDay.goalMet, "Progress short of the goal does not meet it")
oneDay.reach(page: 3)
assert(oneDay.highestPage == 5, "Paging backward never lowers the high-water mark")
oneDay.reach(page: 12)
assert(oneDay.pagesRead == 12 && oneDay.goalMet, "Passing the goal meets it")
assert(!readingDay(1, book: tracked, from: 0, to: 99, goal: 0).isEvaluated,
       "A zero goal marks a deliberately unevaluated day")

assert(PageVaultReadingDay.streak([], now: day(5), calendar: calendar) == PageVaultStreak(),
       "No recorded days means no streak")

let met = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
           readingDay(2, book: tracked, from: 10, to: 25, goal: 10),
           readingDay(3, book: tracked, from: 25, to: 30, goal: 10)]
let atRisk = PageVaultReadingDay.streak(met, now: day(3), calendar: calendar)
assert(atRisk.current == 2, "Today short of the goal keeps yesterday's streak")
assert(atRisk.isAtRisk && !atRisk.todayMet, "Today is reported as at risk")
assert(atRisk.todayPagesRead == 5 && atRisk.todayGoal == 10, "Today's progress is reported")
assert(atRisk.best == 2, "The best run so far is two days")

var finishedToday = met
finishedToday[2].reach(page: 40)
let complete = PageVaultReadingDay.streak(finishedToday, now: day(3), calendar: calendar)
assert(complete.current == 3 && complete.todayMet && !complete.isAtRisk,
       "Meeting today's goal extends the streak and clears the risk")

let gapped = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
              readingDay(3, book: tracked, from: 10, to: 20, goal: 10)]
let broken = PageVaultReadingDay.streak(gapped, now: day(3), calendar: calendar)
assert(broken.current == 1, "A skipped day resets the streak")
assert(broken.best == 1, "The best run reflects the reset")

let paused = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
              readingDay(2, book: tracked, from: 0, to: 0, goal: 0),
              readingDay(3, book: tracked, from: 10, to: 20, goal: 10)]
let held = PageVaultReadingDay.streak(paused, now: day(3), calendar: calendar)
assert(held.current == 2, "Finishing a book without a replacement does not break the streak")

let other = UUID()
let switched = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
                readingDay(2, book: other, from: 0, to: 15, goal: 10)]
assert(PageVaultReadingDay.streak(switched, now: day(2), calendar: calendar).current == 2,
       "The streak follows the habit, not one particular book")

let future = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
              readingDay(9, book: tracked, from: 10, to: 40, goal: 10)]
assert(PageVaultReadingDay.streak(future, now: day(1), calendar: calendar).current == 1,
       "A row dated after today is ignored")

let missedYesterday = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
                       readingDay(2, book: tracked, from: 10, to: 12, goal: 10),
                       readingDay(3, book: tracked, from: 12, to: 12, goal: 10)]
let reset = PageVaultReadingDay.streak(missedYesterday, now: day(3), calendar: calendar)
assert(reset.current == 0, "Yesterday's miss resets the streak regardless of today")
assert(reset.best == 1, "The best run is preserved after a reset")

let dayRoundTrip = try JSONDecoder().decode(PageVaultReadingDay.self,
                                            from: try JSONEncoder().encode(oneDay))
assert(dayRoundTrip == oneDay, "A reading day survives a persistence round trip")
assert(oneDay.id == "2026-09-01#\(tracked.uuidString)", "Rows are keyed by day and book")
print("PASS: 20 streak assertions (day keys, high-water, at risk, misses, pauses, book switch, round trip)")

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
assert(strayCrops[9] == bodyCrops[9], "One stray mark does not widen every other page")
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
assert(mixedCrops[4] == bodyCrops[4], "A blank page takes the shared area, so paging stays steady")
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
func manifest(_ entries: [PageVaultBackupEntry], days: [PageVaultReadingDay] = [],
              documents: Bool = true, version: Int = PageVaultBackup.currentVersion) -> PageVaultBackup {
    PageVaultBackup(version: version, createdAt: reference, includesDocuments: documents,
                    entries: entries, days: days)
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
let exportDays = [readingDay(1, book: readingID, from: -1, to: 20, goal: 10),
                  readingDay(2, book: UUID(), from: 0, to: 5, goal: 5)]
let full = PageVaultBackup(createdAt: reference, library: exportLibrary, days: exportDays,
                           includesDocuments: true)
let files = full.entries.compactMap(\.file)
let alphaFile = full.entries.first(where: { $0.book.fingerprint == digest("a") })?.file ?? ""
let blankFile = full.entries.first(where: { $0.book.fingerprint == digest("c") })?.file ?? ""
assert(full.entries.count == 3 && full.days.count == 1,
       "Reading days are exported only for books that are in the library")
assert(files.count == 3 && Set(files.map { $0.lowercased() }).count == 3,
       "Two books sharing a title still export to distinct files")
assert(files.allSatisfy(PageVaultBackup.isSafeDocumentPath),
       "Every generated path passes the check a restore applies")
assert(alphaFile.hasPrefix("books/Deep Work Notes ") && alphaFile.hasSuffix(".pdf"),
       "Titles are cleaned into Windows-safe file names")
assert(blankFile.hasPrefix("books/Book "), "A blank title still produces a usable file name")
let decodedFull = try PageVaultBackup.decode(full.encoded())
assert(decodedFull == full, "A full export manifest survives encoding")
let dataOnly = PageVaultBackup(createdAt: reference, library: exportLibrary, days: exportDays,
                               includesDocuments: false)
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
assert(rejection(manifest([good], days: [readingDay(1, book: UUID(), from: 0, to: 5, goal: 5)]))
       == .inconsistentHistory, "History for a book outside the export is refused")
var impossibleDay = readingDay(1, book: alphaBook.id, from: 0, to: 5, goal: 5)
impossibleDay.day = "2026-02-30"
assert(rejection(manifest([good], days: [impossibleDay])) == .inconsistentHistory,
       "An impossible calendar day is refused")
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
let hereDays = [readingDay(1, book: hereAlpha, from: 0, to: 3, goal: 5)]
let plan = PageVaultRestorePlan(backup: full, library: here)
assert(plan.matches.map(\.existingID) == [hereAlpha] && plan.additions.count == 2
       && plan.missingDocuments.isEmpty,
       "Books are matched by content fingerprint, and the rest of a full export are additions")
let dataPlan = PageVaultRestorePlan(backup: dataOnly, library: here)
assert(dataPlan.matches.count == 1 && dataPlan.additions.isEmpty && dataPlan.missingDocuments.count == 2,
       "Reading data can only restore books whose PDFs are already here")

let added = plan.applied(to: here, days: hereDays, backup: full, mode: .addMissing, at: day(5))
let keptAlpha = added.library.books.first(where: { $0.id == hereAlpha })
assert(keptAlpha?.currentPage == 3 && keptAlpha?.status == .wantToRead,
       "Only adding leaves a book already here untouched")
assert(added.library.books.count == 4 && added.library.current?.id == hereDelta,
       "An added book never displaces the book already being read")
assert(added.replacedHistory.isEmpty && added.days == hereDays,
       "Only adding keeps existing reading history as it was")

let replacing = plan.applied(to: here, days: hereDays, backup: full, mode: .replaceMatching, at: day(5))
let restoredAlpha = replacing.library.books.first(where: { $0.id == hereAlpha })
assert(restoredAlpha?.currentPage == 40 && restoredAlpha?.hasPlace == true,
       "Replacing gives the book already here the export's place")
assert(replacing.library.current?.id == hereAlpha
       && replacing.library.books.first(where: { $0.id == hereDelta })?.status == .wantToRead,
       "The export's Reading book takes over and the previous one is demoted, never finished")
assert(replacing.library.books.filter({ $0.status == .reading }).count == 1,
       "A restore never leaves two Reading books")
assert(replacing.days.map(\.bookID) == [hereAlpha] && replacing.days.first?.highestPage == 20,
       "The matched book's history is replaced by the export's, keyed to the book already here")
assert(Set(replacing.changedBookIDs).count == replacing.changedBookIDs.count
       && replacing.changedBookIDs.contains(hereDelta),
       "Every changed book is reported once, including the one demoted")

let freshID = UUID()
var clash = PageVaultLibrary()
var clashing = exportable("e", title: "Unrelated")
clashing.id = readingID
try clash.insert(clashing)
let remapped = PageVaultRestorePlan(backup: full, library: clash)
    .applied(to: clash, days: [], backup: full, mode: .addMissing, at: day(5), makeID: { freshID })
assert(remapped.additionIDs[readingID] == freshID && remapped.library.books.count == 4,
       "An id already used by a different book is replaced instead of overwriting that book")
assert(remapped.days.map(\.bookID) == [freshID], "Reading history follows the book to its new id")
assert(remapped.library.current?.id == freshID,
       "With nothing being read, the export's Reading book resumes as the one being read")
print("PASS: 34 backup assertions (manifest round trip, file names, validation, versions, planning, add, replace, id collision)")
