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
print("PASS: 15 status assertions (default, single Reading book, demotion, shelves, goal sanitizing)")

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

// Margin trimming is what makes fixed-layout text readable on a phone, so its limits are pinned.
func ink(_ minX: Double, _ minY: Double, _ maxX: Double, _ maxY: Double) -> PageVaultInkBox {
    PageVaultInkBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
}
let typical = PageVaultCrop.cropBox(from: [ink(0.10, 0.08, 0.90, 0.92)])
assert(typical != nil, "A page with ordinary margins is worth trimming")
assert(typical!.minX > 0.08 && typical!.minX <= PageVaultCrop.maxSideInset,
       "The trim is padded inward of the ink and never exceeds the cap")
assert(typical!.width < 1, "Trimming reduces the page width, which is what raises text size")

let generous = PageVaultCrop.cropBox(from: [ink(0.30, 0.30, 0.70, 0.70)])
assert(generous != nil)
assert(generous!.minX == PageVaultCrop.maxSideInset && generous!.maxX == 1 - PageVaultCrop.maxSideInset,
       "A very wide margin is trimmed only up to the cap, so an unsampled figure cannot be shorn off")

assert(PageVaultCrop.cropBox(from: [ink(0, 0, 1, 1)]) == nil,
       "A scanned page whose ink covers the sheet is left alone")
assert(PageVaultCrop.cropBox(from: [ink(0.005, 0.005, 0.995, 0.995)]) == nil,
       "An already tight page is not re-cropped for no gain")
assert(PageVaultCrop.cropBox(from: []) == nil, "No samples means no crop")
assert(PageVaultCrop.cropBox(from: [ink(0.5, 0.5, 0.5, 0.5)]) == nil, "Empty ink is ignored")

let unioned = PageVaultCrop.cropBox(from: [ink(0.20, 0.20, 0.60, 0.60),
                                           ink(0.10, 0.15, 0.85, 0.90)])
assert(unioned != nil)
assert(unioned!.minX <= 0.10 && unioned!.maxX >= 0.85,
       "The crop spans every sample, so the widest page still fits")

assert(PageVaultCrop.samplePageIndices(pageCount: 0).isEmpty, "No pages, no samples")
assert(PageVaultCrop.samplePageIndices(pageCount: 3) == [0, 1, 2], "A short document samples fully")
let spread = PageVaultCrop.samplePageIndices(pageCount: 600)
assert(spread.count == 5 && spread.first == 1 && spread.last == 599,
       "A long document samples across its whole span, skipping the cover")
assert(spread == spread.sorted() && Set(spread).count == 5, "Samples are ordered and distinct")
print("PASS: 15 layout assertions (trim, cap, full-bleed, union, sampling)")
