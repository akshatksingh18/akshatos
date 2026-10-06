# PageVault feature map

**State:** PageVault v1 is accepted on the physical iPhone through Build 24, including the reading
loop, search, themes, page curl/jump, highlights/Takeaways, annotation hiding and full export/restore.
Reading streaks were removed at Akshat's request. Accepted Build 25 adds only the shared
story-quest/treasure-shelf presentation; it passed the AkshatOS PR #52 macOS CI Gate, checksum/IPA
validation, Wi-Fi installation and current-version enrollment. Akshat reports the installed build
works perfectly, accepting that refreshed presentation. AkshatOS 0.6.0 (29) replaces that themed
presentation with a plain, minimal one at Akshat's request (accepted with Build 31). `CLAUDE.md`
owns the remaining non-v1 measurement and clean-install boundaries.
PageVault is a module in the native AkshatOS hub alongside Pushup Reminder, Lift Log and Body;
WHOOP remains a separate app. The Android concept is a later fallback, not the source of iOS
file-access or rendering behavior. Locked target/toolchain/storage decisions: `CLAUDE.md`. Shared
identity and lifecycle gates: `../hub-plan.md`.

PageVault is a fixed-layout PDF reader. “Kindle-like” means the cover library, one-page-at-a-time
paged reading on tinted paper, and a bookmark that holds your place—not ePub-style text reflow or
font resizing. The page image itself is never re-laid out.

## MVP (v1): daily-use and recovery loop

- **Import:** use the iOS system file importer, filtered to PDFs and supporting multi-select where
  practical. Acquire security-scoped access only for the import operation, stream/copy each file
  into PageVault-owned Application Support storage, validate it with PDFKit, and release access.
  Cloud-backed Files providers may need to download first; show progress and recoverable errors.
  This picker is the only way in. PDFs from Akshat's laptop arrive through a cloud folder his laptop
  syncs (OneDrive), picked here like any other Files location.
- **Removed: laptop inbox folder and Open in AkshatOS.** Build 28 added a linked OneDrive folder
  copied in on every open and a PDF share-sheet entry. On the phone, linking did nothing — tapping
  **Open** in the folder picker had no effect — and Akshat judged picking from his synced folder
  enough, so he asked for both to be removed; Build 29 takes them out. Do not re-propose either.
- **Import integrity:** never buffer a large PDF into one `Data` value. Clean up interrupted partial
  copies, reject unreadable/corrupt files honestly, detect duplicates with a streamed fingerprint,
  and leave the source file untouched.
- **Library presentation:** clean, minimal and in plain words, following AkshatOS's shared design
  direction (`../features.md`). A one-line count ("12 books · 30 highlights"), an **Add
  PDF** button, **Takeaways** and **Back up** buttons, then **Continue reading** and the shelves
  **In progress**, **Want to read** and **Finished**. The Build-25 "story quest" wording (portal,
  quest queue, completed tomes, treasure shelf) was removed at Akshat's request in AkshatOS 0.6.0
  (29); do not reintroduce themed labels.
- **Library:** a cover grid grouped semantically into Continue reading, Started, Want to read and Finished, each
  book showing its page-one thumbnail, title and progress. Started holds books you have bookmarked
  but are not currently reading — usually the previous read, demoted when you bookmarked another
  book — so a half-read book never sits among unopened ones. It is a shelf, not a status: those
  books are still Want to Read. Progress reflects your bookmarked place, not
  the last page you happened to look at, so browsing never moves the bar. Books with no bookmark
  read as "Not started". Thumbnails are a disposable cache; metadata and the copied PDF are durable.
- **Reading status:** every book has exactly one status — Want to Read, Reading, or Finished. New
  imports default to Want to Read. **Bookmarking a page claims that book as the one being read**, so
  the common case needs no explicit action: if you are bookmarking it, you are reading it. Status can
  still be set by hand, and Finished always is. Only one book can be Reading at a time — a new
  bookmark in another book demotes the previous one to Want to Read, never silently to Finished. The
  library surfaces the Reading book as "continue reading"; no separate feature is needed.
- **No reading targets:** PageVault does not score reading. Daily page goals and streaks were built,
  used on the phone, and then removed at Akshat's request — bookmarking marks your place, it is not
  a metric. Do not reintroduce goals, streaks or reading statistics without asking.
- **Reader:** one page at a time, turned by a horizontal swipe, using PDFKit's
  page-view-controller paging. Continuous vertical scrolling was tried and rejected for showing two
  half pages at once. The surround is painted the same colour as the page with shadows off, so there
  are no dark letterbox bands.
- **Pages fitted to their text:** PageVault measures where the ink sits on every page of a book,
  once, in the background after import (or the first time an older book is seen), and crops each
  page to its text from all four sides. The *text block*, not the paper, then fills the screen
  width, with no zooming and no sideways panning. The measurement covers the whole book rather than
  a sample:
  - one text area is shared by every ordinary page, so text stays the same size from page to page;
  - left- and right-hand pages are positioned separately, because printed books and scans sit
    off-centre in opposite directions;
  - paper is judged against each page's own background, so off-white scans are still cropped, and
    specks of dust are ignored;
  - a page whose content reaches beyond the shared area — a wide table or figure — gets a larger box
    of its own, so nothing is ever clipped;
  - full-page scans and images are left exactly as published.
  A book that has not been measured yet opens on a short "Fitting pages" screen, with the option to
  read it unfitted instead.
  The honest limit: fitting removes margins, not the shape mismatch. A book's text block is wider for
  its height than a phone screen, so once the text fills the width, a full page still leaves some
  blank space above and below it. Filling that as well would mean stretching the letters, zooming past
  the screen width into sideways panning, or reflowing the words, which a fixed-layout PDF cannot do
  without losing its layout.
- **Jump to a page:** tap the page indicator at the bottom of the reader — the "12 / 293" — and pick
  a page with a slider or by typing the number. Both, because neither alone is enough in a long
  book: dragging finds roughly the right place without knowing the number, and typing is the only
  way to hit an exact page when one screen pixel covers several of them. Jumping is browsing, so it
  does not move your bookmark, and the sheet says so. The indicator is inert in a one-page document.
- **Marks the PDF already carried are hidden.** A PDF annotated somewhere else — Books, Preview,
  Acrobat — arrives with its highlights inside the file. PageVault hides that text markup while
  reading, in memory only, so the marks you see are always PageVault's own and always ones it can
  list and remove. The file is never written to, so re-importing it changes nothing and the marks
  come back if PageVault stops hiding them. Links are left alone; hiding those would break
  navigating the book.
  This was a real defect, not a precaution: a mark the reader could not list or clear looked exactly
  like a PageVault highlight that refused to go away. Highlight it in PageVault if you want it back
  as a passage you own.
- **A highlight flattened into the page cannot be hidden, and PageVault will not try.** Hiding works
  on annotations. Some PDFs instead carry their marks as ordinary drawn artwork — a shape filled in
  yellow, sitting in the page's content next to the letters, with no annotation anywhere in the file.
  Grit arrived that way: 2086 link annotations, zero highlight annotations, and 65 yellow shapes
  drawn across 48 pages.
  To a renderer that artwork *is* the page, exactly like the text, and every reader shows it —
  opening the file in Books, Preview or Chrome is the quickest way to confirm a mark is in the book
  rather than in PageVault. Removing it would mean rewriting the page's content, which is both
  outside "PageVault never modifies the PDF" and unsafe to guess at: a textbook's yellow callout box
  is the same drawing operation as a flattened highlight, so the rule that erased one would erase the
  other. The fix belongs to the file, before import — strip the artwork and import the clean copy.
  Both halves are **confirmed on the phone** against `07-highlight-boundary.pdf`, which carries the
  two kinds side by side and renders them identically: the annotated pages came up clean and the
  flattened page kept its marks.
- **Zoom:** pinch to zoom, with the whole fitted page as the floor — it can never be dialled smaller
  than "everything visible". The ceiling is 4x that fit. The chosen level is remembered across page
  turns, books and relaunches rather than being redialled each time.
  **A zoomed page does not turn**: swiping off the right edge while zoomed in pans within the page
  instead of moving to the next one, so you zoom back out to read on. This was confirmed on the
  phone as wanted, not reported as a defect — zooming means reading that page at that size, and a
  page that slid away under a pan would be friction. Do not "fix" it into turning while zoomed.
- The reader may rotate to landscape for wide or scanned pages while the hub and library stay
  portrait.
- **Page curl:** pages turn with the system curl transition — one `PDFView` per page inside a page
  view controller, because PDFKit's own paging exposes no curl. The device pass confirmed the curl
  and drag-to-select coexist, so it is the only reader and has no setting; PDFKit's plain paging was
  removed rather than kept as a dormant second path.
- **Your place (replaces auto-resume):** a book reopens at its bookmark, or page one if it has
  never been bookmarked. Reading, browsing back, and closing the app do **not** move it — only
  bookmarking does, exactly like a physical bookmark. This was chosen on the phone over
  last-page-viewed resume, which kept dragging the place to wherever the reader happened to stop.
  The stored page is clamped on every read, so a place beyond a shorter document falls back into
  range. The tradeoff is deliberate: forget to bookmark and you reopen where you last bookmarked,
  not where you actually stopped.
- **Bookmarks:** exactly one per book — the place marker above. Bookmarking a new page replaces
  the previous one rather than accumulating a list, because a lingering old bookmark was actively
  confusing in use. Stored as PageVault metadata; the PDF is never modified. Multiple bookmarks and
  notes are out of v1.
- **Table of contents: removed from v1.** Outline traversal was built and verified working on a
  180-page three-level PDF, then removed at Akshat's request — he did not want the navigator control
  in the reader. The implementation is recoverable from Git history if a long book makes it worth
  having again.
- **Page themes:** Paper, Sepia and Night, chosen from the reader's menu and remembered. Sepia is
  the default: it read better than the warmer white in use, so the near-duplicate warm theme was
  removed rather than kept. Sepia is a tinted overlay composited with a multiply blend, which tones
  the page while leaving black text black — a plain translucent overlay is what washes text out.
  Night blends white with a difference filter, inverting the page into light text on dark. A build
  that stored warm, or only the older warm-paper switch, lands on sepia rather than resetting.
- **Highlights:** select a line while reading and tap the highlighter, which asks which of two
  things you mean — **Highlight** or **Remove highlight**. Remove is offered only when the
  selection actually covers a mark. Highlights are PageVault metadata — the PDF file is never
  modified — and the marks are redrawn each time the book opens. They are listed per book, in
  reading order, from the reader's menu or book details, each passage carrying **Go to page** and a
  bin that asks before removing. Highlights travel inside a full export and come back with the book
  on restore. The whole set exports as its own PDF: the passages with the page each came from, which
  is a reading list, not an annotated copy of the book. A passage spanning a page break is stored
  per page.
- **A passage can only be marked once.** Marks are identified by the words they cover, not by the
  text captured, so selecting a line that already carries a mark plus one more word *extends* that
  mark rather than laying a second one over it. Removing clears whatever the selection covers,
  without asking for the original selection to be reproduced.
  This replaced a single toggling highlighter, which had to infer from the selection whether
  marking or unmarking was meant and inferred it by comparing text. On the phone that meant a
  slightly wider selection stacked two or three marks over the same words — visibly darker where
  they overlapped — and a mark became effectively impossible to remove by hand, because PDFKit
  snaps a drag to word and line boundaries differently depending on where it starts. Deleting one
  such passage in Takeaways left its siblings still drawn, which read as a mark that would not go
  away. Do not restore an inferring highlighter.
- **Takeaways:** the library's second surface, opened from its own button. It lists every book you
  have kept lines from, most recently marked first; opening one shows that book's passages as blocks
  in reading order, with the same PDF export. Each passage there carries **Go to page**, which opens
  its book at that page — the reader's own list moves a book that is already open, so the same
  control does the only thing each place can. The name is deliberate: the point is what you want to
  carry out of a book, not the marks left in it. A book nothing was kept from never appears, and an
  empty Takeaways says so rather than showing a blank list.
  **Settled: it stays a button.** Akshat originally asked for a "tab" and this was built as a button
  on the library screen, because PageVault is pushed inside the hub's navigation where a bottom tab
  bar would fight the hub's own back-navigation. He used it on the phone and called the button good
  enough, so the two-tab bar is closed — do not reopen it without him asking.
- **Full-text search:** search one book's text from the reader's menu, with results as you type,
  each showing its page and the line it matched; tapping one jumps there and **tints the words that
  matched** so the page does not have to be scanned by eye for them. The tint is a signpost, not a
  highlight: it is a different colour, nothing is stored or exported, and it is gone as soon as the
  page is turned. Matching ignores case and
  accents, needs at least two letters, and stops at 200 results so a long book stays quick. A
  scanned book has no text layer, so it honestly finds nothing — PageVault does not OCR.
- **Remove from library:** after confirmation, delete only PageVault’s private copy, metadata,
  place, and regenerable cover and page-measurement caches. Never delete or alter the original Files source.
- **Export and restore:** before daily-driver acceptance, provide a versioned metadata export and a
  full-library export containing the copied PDFs, saved as a plain folder (manifest plus PDFs)
  through Files. Restore must validate schema/hashes and handle conflicts explicitly: books are
  matched by content, missing books come back only from a full export, and books already in the
  library keep their place and history unless you confirm replacing them. Reading data alone
  restores onto PDFs you add again. Confirmed on the phone: a full export, the book removed from the
  library, and a restore bringing it back with its reading place and highlights intact.
  **Akshat has closed the remaining tests as not worth doing**: a clean-install restore,
  reading-data-only restore, and the Started shelf. Respect that and do not re-propose them.
  The one honest consequence to keep in view: clean-install restore is what would have proved an
  export is a *backup*, so restoring onto a wiped or reinstalled app remains unproven rather than
  known-good. Nothing in daily use depends on it.
- **Offline behavior:** after import, the reading loop, metadata, export preparation, and restore
  validation require no backend or network. A document provider is an import source, not a runtime
  dependency.

## Read aloud (from AkshatOS 0.8.0 (31))

Akshat's books are digital copies with a text layer, so the phone's own voice can read them like an
audiobook. On the phone, Build 31's button, bar, tint, page turns and lock-screen controls work, but
the voice sounded robotic and restarted its pitch as if every few words began a sentence. Build 31
spoke one sentence per utterance; working source 0.9.0 (32) hands the voice a whole page as one
passage (see the second bullet). Build 32 passed CI and artifact validation and is installed,
but Akshat reports the voice is still robotic. The named Enhanced/Premium voice result is pending.
Build 33 (installed) fixes the automatic voice ranking. With Ava (Premium) Akshat reports it reads
well except running on after a sentence ending in a closing quote; working source 0.11.0 (34)
fixes that and shortens the voice menu (both bullets below); not yet built or phone-tested.

- A headphones button in the reader starts reading at the top of the page on screen. A bar appears
  above the page number with back a sentence, play/pause, forward a sentence, speed and voice, and
  stop; the same button stops it too.
- The voice is given each page as one continuous passage and reports its progress, which moves the
  tint from sentence to sentence. A last sentence that does not end on the page is held back and
  spoken whole with the next page (a word hyphenated across the break is joined), so nothing is cut
  at a page turn; its carried-over words are not tinted. A heading or other line without closing
  punctuation gets a short breath rather than a full stop. Pages turn with the curl as it goes. Turning a page by hand moves reading there, still playing or still paused;
  play then starts at the top of that page. A page with no text is passed over.
- It keeps reading with the screen locked and answers the lock screen, Control Center and headphone
  buttons (play, pause, next and previous sentence), showing the book and page. A phone call or
  another app's audio pauses it. Leaving the reader stops it.
- Running headers and footers (a top or bottom line repeated on nearby pages), page numbers and
  roman numerals are skipped; words hyphenated across a line end are joined; ligatures are spelled
  out. From 0.11.0 (34) the voice is not given quotation marks (silent anyway, and `genius!” This`
  hid the sentence end so the voice ran on), curly apostrophes become plain ones, a long dash
  becomes a comma's pause instead of joining two words, and a footnote number stuck to a word's
  closing punctuation (`one.12`, or a superscript) is not read; ordinary numbers stay. A line is treated as ending a paragraph or being a heading only when it is clearly short and
  either ends its sentence or is followed by a line starting with a capital or digit, so text that
  arrives in narrow lines is not chopped into fragments. Footnotes, captions and unusual layouts are read as they come, and two-column pages may come
  out in the wrong order.
- Speeds 0.75× to 2× and the voice are remembered. When only the basic voice is installed, the first
  play says once where the natural voices are. "Best available" picks the highest-quality voice
  installed across the phone's language variants from Build 33, with the exact locale
  breaking a quality tie. A voice chosen by name keeps taking precedence. From 0.11.0 (34) the
  speed menu lists Best available plus only the voices ticked in **Choose voices…** (until he
  ticks any, the Enhanced and Premium ones); the voice in use is always listed, and unticking it
  falls back to Best available. That screen lists every installed English voice, best first, with
  a sample button (the book pauses for it), and names the region when two voices share a name.
  An app cannot download or delete iPhone voices: that stays in Settings → Accessibility → Spoken
  Content → Voices. Novelty and Personal Voice voices are not offered.
- It never moves the book's place: only the bookmark does, as everywhere in the reader. Pausing
  leaves the page on screen, so tapping the bookmark keeps it.
- Everything is on the phone: the system speech voice, no network, no account. A scanned book has
  no text and says so instead of playing; OCR stays out of scope.
- The app declares the audio background mode for this. Nothing else plays in the background.

## v2 / optional improvements

- **Notes attached to a highlight:** not built. Highlights keep the passage and its page, nothing
  more.
- **Exporting an annotated copy of the book:** explicitly not wanted. The highlights PDF lists the
  passages instead, and the original PDF is never modified.
- **Reading statistics:** out of scope now that streaks are gone. Revisit only if Akshat asks for
  numbers, and never as an analytics service.
- **Collections/shelves:** add when the library size makes a flat grid unwieldy.
- **Reference-in-place import:** an opt-in mode for extremely large files may use a security-scoped
  bookmark to avoid duplication, but only with stale-bookmark detection, availability warnings,
  and a user-driven relink flow. Copy-on-import remains the reliable default.
- **Android fallback:** a later Kotlin/Compose build may reuse the product intent but needs its own
  SAF/pdfium architecture and verification. It must not dictate iOS APIs or storage semantics.

## Explicitly out of scope

- ePub, mobi, and other non-PDF formats.
- OCR for scanned/image-only PDFs.
- DRM bypass or files the user does not own.
- Accounts, multi-user support, advertising, analytics, required cloud sync, or a PageVault backend.
- App Store/general-market distribution work unless Akshat explicitly expands the project.
- Reader-specific widgets, push notifications, App Groups, iCloud capabilities, extensions, or any
  background mode other than read-aloud's audio; the host's Pushup Reminder notification/geofence services remain independently needed.

## Feature acceptance rule

A feature is “working” only after the implemented behavior and failure cases pass on the actual
iPhone. Keep this file synchronized with `architecture.md` and `CLAUDE.md`: when scope, platform,
storage ownership, or acceptance changes, update all affected sources in the same change and keep
planned behavior distinct from verified behavior.
