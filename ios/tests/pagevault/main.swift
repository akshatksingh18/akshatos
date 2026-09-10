import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Chicago")!
let reference = Date(timeIntervalSince1970: 1_788_480_000)
func day(_ number: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 9, day: number, hour: 12))!
}
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
assert(book(pages: 300, page: 299).progressFraction == 1, "The last page reads as complete")
assert(book(pages: 1, page: 0).progressFraction == 1, "A single-page document is complete when open")
assert(book(pages: 0).progressFraction == 0, "A pageless document has no progress")

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
print("PASS: 15 book assertions (page clamping, progress, resume, title derivation)")

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

var marked = book(pages: 500)
assert(marked.toggleBookmark(page: 40, note: "  ", at: reference), "Bookmarking a fresh page adds one")
assert(marked.bookmarks.count == 1 && marked.bookmarks[0].note == nil,
       "A whitespace-only note is stored as no note")
assert(marked.hasBookmark(page: 40), "The page reports as bookmarked")
assert(!marked.toggleBookmark(page: 40, at: reference), "Bookmarking the same page removes it")
assert(marked.bookmarks.isEmpty && !marked.hasBookmark(page: 40), "Toggling off leaves no bookmark")
marked.toggleBookmark(page: 90, note: "Good bit", at: reference)
marked.toggleBookmark(page: 12, at: reference)
assert(marked.bookmarks.map(\.page) == [12, 90], "Bookmarks stay sorted by page")
marked.toggleBookmark(page: 9_000, at: reference)
assert(marked.bookmarks.map(\.page) == [12, 90, 499], "A bookmark beyond the document clamps into range")
marked.removeBookmark(id: marked.bookmarks[1].id)
assert(marked.bookmarks.map(\.page) == [12, 499], "Removing a bookmark leaves the others")
let markedRoundTrip = try JSONDecoder().decode(PageVaultBook.self,
                                               from: try JSONEncoder().encode(marked))
assert(markedRoundTrip == marked, "Bookmarks survive a persistence round trip")
print("PASS: 9 bookmark assertions (toggle, notes, ordering, clamping, removal, round trip)")

// A build written before these fields existed must keep decoding.
let legacy = Data("""
{"id":"5B8C1B16-5F2E-44B6-9A0E-4E3B0F6A11AA","fingerprint":"old","title":"Legacy Book",
 "pageCount":120,"byteCount":2048,"addedAt":0,"currentPage":7}
""".utf8)
let upgraded = try JSONDecoder().decode(PageVaultBook.self, from: legacy)
assert(upgraded.status == .wantToRead, "An older payload defaults to Want to read")
assert(upgraded.dailyPageGoal == nil && upgraded.bookmarks.isEmpty,
       "An older payload gains empty goal and bookmark fields")
assert(upgraded.currentPage == 7, "An older payload keeps its reading position")
assert(upgraded.lastOpenedAt == nil && upgraded.statusChangedAt == nil,
       "Absent optional timestamps decode as nil rather than failing")

// The smallest record any build could have written must still load.
let minimal = Data("""
{"id":"9C1F0C7E-1A2B-4C3D-8E4F-5A6B7C8D9E0F","fingerprint":"tiny","title":"Tiny",
 "pageCount":3,"byteCount":10,"addedAt":0}
""".utf8)
let tiny = try JSONDecoder().decode(PageVaultBook.self, from: minimal)
assert(tiny.currentPage == 0 && tiny.status == .wantToRead && tiny.bookmarks.isEmpty,
       "A minimal record loads with defaults instead of throwing")

// A record missing a genuinely required field is still a corrupt record, not a default.
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
print("PASS: 6 payload migration assertions (defaults, optionals, minimal record, corrupt record)")

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

// Empty history has no streak at all.
assert(PageVaultReadingDay.streak([], now: day(5), calendar: calendar) == PageVaultStreak(),
       "No recorded days means no streak")

// Consecutive met days build a streak; today falling short is at risk, not broken.
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

// A day inside the window with no row is a real miss.
let gapped = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
              readingDay(3, book: tracked, from: 10, to: 20, goal: 10)]
let broken = PageVaultReadingDay.streak(gapped, now: day(3), calendar: calendar)
assert(broken.current == 1, "A skipped day resets the streak")
assert(broken.best == 1, "The best run reflects the reset")

// An unevaluated day pauses evaluation instead of breaking the run.
let paused = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
              readingDay(2, book: tracked, from: 0, to: 0, goal: 0),
              readingDay(3, book: tracked, from: 10, to: 20, goal: 10)]
let held = PageVaultReadingDay.streak(paused, now: day(3), calendar: calendar)
assert(held.current == 2, "Finishing a book without a replacement does not break the streak")

// Switching books mid-streak keeps one continuous streak.
let other = UUID()
let switched = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
                readingDay(2, book: other, from: 0, to: 15, goal: 10)]
assert(PageVaultReadingDay.streak(switched, now: day(2), calendar: calendar).current == 2,
       "The streak follows the habit, not one particular book")

// Future-dated rows cannot inflate today's streak.
let future = [readingDay(1, book: tracked, from: 0, to: 10, goal: 10),
              readingDay(9, book: tracked, from: 10, to: 40, goal: 10)]
assert(PageVaultReadingDay.streak(future, now: day(1), calendar: calendar).current == 1,
       "A row dated after today is ignored")

// A missed day before today breaks the run even when today is still open.
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
