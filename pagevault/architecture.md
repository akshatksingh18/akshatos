# PageVault architecture

**State:** The reading loop is confirmed on the physical iPhone as of Build 20 — page fitting,
bookmark restore, the tinted page, paging and a full-library export (results in `CLAUDE.md`). Restore into
a library missing those books passed on the phone in Build 24. Clean-install restore remains
unexercised by Akshat's decision. Reading streaks have been removed. The table of
contents was removed from v1. Accepted Build 25 refreshed the library and Takeaways with a themed
presentation only, which 0.6.0 (29) replaces with a plain, minimal one; persistence, reading
behavior and the deliberate removal of reading streaks are unchanged by either. The presentation passed the AkshatOS PR #52 macOS CI Gate,
checksum/IPA validation, installation and current-version enrollment. Akshat reports the installed
Build 25 works perfectly, accepting that focused presentation pass; broader unmeasured edge cases
remain unchanged. PageVault is a module in the AkshatOS native hub; WHOOP
stays standalone.
`../hub-plan.md` owns shared identity/build/lifecycle gates, `CLAUDE.md` owns module deployment
and recovery, and `features.md` owns product scope.

## Primary iOS stack

- **Language/UI:** Swift and SwiftUI on the locked iOS 17.0, iPhone-only target, built with the
  hub's pinned Xcode 26.6 / XcodeGen 2.46.0 / Swift 5.0 toolchain. `CLAUDE.md` owns the full list of
  locked scaffold decisions; `../ios/project.yml` is authoritative for the values.
- **Module placement:** `ios/AkshatOS/features/pagevault/{domain,data,services,ui}` inside the hub
  target, enforced by `../ios/scripts/check-boundaries.py`. `domain/` is Foundation-only, so
  PDFKit lives in `data/`/`services/` while reading-status, place and page arithmetic stay pure
  domain logic. Register the module's suites in `../ios/tests/feature-tests.json`.
- **PDF engine:** PDFKit (`PDFDocument`, `PDFView`, and `PDFPage`). Wrap
  `PDFView` with `UIViewRepresentable`; do not build a renderer or depend on undocumented PDFView
  subviews unless a proven gap forces a separately reviewed decision.
- **Persistence:** SwiftData with an explicit versioned schema and migration tests. It held up on
  device, so a Core Data/SQLite fallback is no longer an open question.
- **Files:** app-private Application Support storage, one directory per stable book UUID. Store the
  imported PDF and durable metadata separately from regenerable cover thumbnails/cache.
- **Network/services:** none required for normal use. No account, backend, analytics, remote push,
  required cloud sync, or runtime dependence on the source document provider.

## Read-aloud voice selection

The narrator offers installed non-novelty, non-personal voices for the phone's language.
An explicit saved voice identifier takes precedence. From Build 33, the Foundation-only
`PageVaultReadAloud.bestVoice` ranks automatic candidates by quality across regional variants,
then exact locale for equal quality, retaining the supplied order for other ties. The narrator
maps AVFoundation voices into that policy; synthetic domain cases need no downloaded voice.
From 0.10.1 (34), `PageVaultReadAloud.menuVoices` decides which voices the speed menu lists from the
saved `pagevault.readAloud.shownVoices` set (nil until first chosen: Enhanced and Premium only), always
keeping the voice in use, and `voiceLabel` adds a region only to same-named voices.
`ui/PageVaultVoicesView.swift` edits that set and plays samples on its own synthesizer, pausing the
book first. `spokenText` also strips quotation marks, plains apostrophes, turns long dashes into a
comma's pause and drops footnote numbers, so sentence ends stay clear to the voice; page offsets
for the tint are unaffected because they come from the page text, not the spoken text.

## Storage and import ownership

The v1 default is **copy on import**:

1. Present SwiftUI’s file importer for PDF URLs.
2. Start security-scoped resource access when required.
3. Stream/coordinate a copy to a temporary app-private path; never load the whole file into memory.
4. Validate that PDFKit can open it, compute metadata/fingerprint, then atomically promote the copy
   and metadata into the library.
5. Release security-scoped access in a `defer` path and clean up partial failures.

The copied PDF remains readable offline and independent of the original provider. The tradeoff is
duplicated storage and app-container loss on uninstall. The source PDF or a tested PageVault export
must therefore exist elsewhere before deletion/reinstallation. Expired signing should be repaired
by same-bundle overwrite, never routine uninstall.

A future reference-in-place mode is optional only. It requires a persisted security-scoped bookmark,
stale resolution detection, balanced access on every open, clear provider/offline availability state,
and a relink flow. It must not silently replace copy-on-import.

**Imports run one at a time.** Every import goes through one store path that runs imports
strictly in sequence, so two copies of a file picked together cannot both pass the duplicate check,
and that path loads the library first if it has not been loaded yet. The laptop inbox folder and
Open in AkshatOS that Build 28 added on top of it were removed in Build 29 at Akshat’s request
(`features.md`); on the next load PageVault deletes the folder record (`inbox.json`) Build 28 may
have left, and the app again declares no document types (`validate-ipa.py` checks this).

## Data model and invariants

- `Book`: stable UUID, private PDF filename, source/display metadata, page count, streamed content
  fingerprint, added/opened timestamps, reading status (`wantToRead` / `reading` / `finished`,
  default `wantToRead`) with a change timestamp, and its place.
  The single-Reading-book rule is enforced in `PageVaultLibrary.setStatus` at the data layer, not
  only in the UI, and the repository refuses to load a store claiming two Reading books.
- **Your place**: one zero-based page per book plus the time it was set, held on the book itself.
  `placeSetAt` being nil is what distinguishes a real bookmark on page one from a book never
  bookmarked, which the opening page and the progress bar both depend on. Clamped on every read so a
  place beyond a shorter document falls back into range. Only bookmarking writes it — reading,
  browsing and closing the app must not — because a place that follows the last page viewed is
  exactly the behavior that was rejected on device.
- Reading streaks are gone. Their `SavedReadingDay` model stays declared in the schema so a store
  written by an installed build still opens with no migration, but nothing writes it and every row is
  deleted on load. Dropping the entity outright would need a V2 stage, and a failed migration costs
  the whole library — not a trade worth making to delete an unused table.
- Covers are a disposable PNG cache under `Covers/`, regenerated from page one on demand and marked
  excluded from device backup — the single exception to including PageVault files in backup, since
  they are always reproducible.
- Export manifest (`PageVaultBackup`, version 1): creation time, whether documents are included, and
  every book record including status and place. A manifest written before reading streaks were
  removed also carries per-day rows, which are ignored when it is read back. Each
  book's streamed SHA-256 fingerprint doubles as its PDF checksum. A full export is a plain folder
  holding `manifest.json` and `books/<cleaned title> <id prefix>.pdf`; a metadata-only export is the
  manifest alone as one JSON file. Covers are never exported. Exports are staged under an app-owned
  `Outgoing/` folder, excluded from device backup and cleared on load, then handed to the system file
  mover.
- Restore validates the whole manifest before planning: version, unique ids and fingerprints, at
  most one Reading book, document paths confined to `books/`, history only for exported books, and
  real calendar days. It then plans by content fingerprint. Books not in the library are added,
  from a full export only; books already present are left alone unless the user confirms replacing
  their place and status. Every added PDF is copied in and re-verified by
  fingerprint, size and page count before the library changes, so one bad file restores nothing.
  The export's Reading book takes over only when replacing; when only adding, it never displaces the
  current read. An added book whose id collides with a different existing book gets a fresh id, and
  its history follows it. Planning and its result are pure domain logic (`PageVaultRestorePlan`).
- Known restore limit: PDFs are moved into place before records are written, so a store write
  failing midway can leave an orphaned copy on disk. The library then reloads from the store and
  reports the failure rather than showing the intended state.

Persisted-data changes require migrations plus in-place upgrade and export/restore tests. Imported
PDFs and metadata are durable; thumbnails and derived cover data are always regenerable. Removal is
transactional and never touches the external source.

- Highlights live on the book record: page, tidied text, creation time, and one rectangle per line in
  PDF points. Page coordinates, so trimming a page's margins never moves a mark. Because the export
  manifest embeds the book record, highlights travel with an export and leave with the book without
  any extra bookkeeping. They are replayed as in-memory `PDFAnnotation`s tagged by highlight id; the
  PDF file is never written to.
- **Annotation ownership is namespaced.** PageVault tags the annotations it draws with
  `pagevault:<id>` in `userName`, and claims only those. It previously claimed every annotation
  carrying any `userName`, which got ownership wrong both ways: a mark the PDF itself carried with
  an author name was deleted, while one carrying no name could never be removed — it sat on the page,
  absent from the passage list, with nothing able to clear it.
  The book's own text markup (`Highlight`, `Underline`, `StrikeOut`, `Squiggly`) is hidden with
  `shouldDisplay = false` rather than removed, because PageVault never writes to the PDF. Link and
  widget annotations are deliberately left visible. Compare subtypes without a leading slash:
  `PDFAnnotationSubtype.highlight.rawValue` is `/Highlight` while `annotation.type` reads back as
  `Highlight`.
  **The limit of this, worth knowing before chasing a mark that will not go:** it only reaches
  annotations. A highlight can also be flattened into the page's content stream as a filled Form
  XObject, with no annotation object anywhere — that is how Grit carries its marks. Nothing at the
  annotation layer can see or hide those, and suppressing them would mean rewriting page content,
  which PageVault does not do. Diagnose by counting annotation subtypes in the file rather than by
  looking at the screen: a page showing yellow while the document reports zero `/Highlight`
  annotations is flattened artwork, and the file has to be cleaned before import.
- **Those rectangles are the mark's identity, not decoration.** Whether a selection is touching an
  existing mark is decided by comparing line bands, in `PageVaultRect.sameBand(as:)`: same line of
  text — vertical overlap greater than half the shorter band's height — and some shared width.
  `PageVaultHighlight.fold` then merges bands that pass that test, so overlapping marks never draw
  the same words twice; `PDFAnnotation`s of type `.highlight` composite, so a doubled band is
  visibly darker. Marking folds the new bands into any mark they cover and keeps the longest text
  of the marks absorbed; removing deletes every mark the selection covers.
  The half-height rule is what keeps a paragraph one band per line. Bands from neighbouring lines
  routinely overlap by a fraction of a point, and a plain rectangle intersection would fold a
  paragraph into a single block covering its indents.
  A selection can also yield text with no measurable bands — an image-only page does — so marking
  falls back to text equality in that one case rather than storing a literal duplicate.
- The chosen page theme and the remembered zoom are `UserDefaults` preferences, not library data. A
  build that stored the retired warm theme, or only the older warm-paper switch, lands on sepia.

**Adding a field to a persisted record needs a decoder change, not just a default.** Swift's
synthesized `Decodable` ignores property defaults and rejects any record missing a non-optional
key, and the repository treats a decode failure as a corrupt store — so one added field would take
the entire library down to "could not be read" on upgrade. `PageVaultBook` therefore decodes field
by field, and every field added after the first release must be given a fallback there while
identity fields stay required. A removed field needs nothing: unknown keys are ignored.

## Reader behavior

- Use PDFKit windowed/on-demand rendering; do not pre-render or retain every page.
- `.singlePage` + `.horizontal` with `usePageViewController(true)`: one page per screen, one page per
  swipe. Continuous vertical mode is not an option — it was rejected on device for showing partial
  pages.
- Apply the opening page only after PDFKit has laid the document out, and ignore reported page
  changes until then. A `go(to:)` immediately after setting `document` is dropped, and PDFKit's
  subsequent page-one report will otherwise be persisted over the stored place.
- The reader screen may rotate to landscape while the rest of the hub stays portrait; scope this per
  screen rather than widening the app-wide orientation set.
- Page themes are one overlay view above the `PDFView`. Sepia uses a multiply compositing filter, so
  the page tones while text stays black; night uses a difference filter against white, which inverts
  the page into light text on dark. A stored warm theme, retired after Build 21, maps to sepia. A plain translucent overlay washes text out and
  must not be used. Keep the `PDFView` background white and page shadows off, so the overlay covers
  page and surround identically and a page narrower than the screen does not sit inside dark
  letterbox bands.
- Read-aloud (`services/PageVaultNarrator.swift`) opens its own `PDFDocument` on the main actor,
  reads one page's text layer at a time and hands it with its neighbours' top and bottom lines to the
  pure `domain/PageVaultReadAloud.swift`, which drops repeated headers/footers and page numbers,
  splits sentences with offsets in characters, builds the cleaned spoken text, and plans one passage
  per page (`PageVaultSpeechPlan`: the text, where each sentence starts in UTF-16 units, and an
  unfinished last sentence to carry to the next page). One `AVSpeechUtterance` per page passage,
  because an utterance per sentence made the voice restart its pitch each time; the synthesizer's
  will-speak callback maps its position back to a sentence for the tint. Only the utterance it is
  waiting on can move reading on, so a skip, stop or speed change never double-advances. The sentence is tinted through the reader
  controller, which re-applies it to whichever page view becomes visible; page turns go through the
  pager's jump with the curl animated. The narrator owns its synthesizer's delegate (a small relay
  object; `check-boundaries.py` allows `synthesizer.delegate` only), and while reading it holds the
  audio session (`.playback`, `.spokenAudio`), the remote commands and Now Playing, releasing all
  three on stop. The app's `Support/AkshatOS-Info.plist` declares the audio background mode.
- Search runs on its own `PDFDocument` off the main actor, reading each page's text layer. A detached
  task does not inherit cancellation, so the store passes an explicit signal that the calling task
  cancels — that is what makes the next keystroke supersede the search already running. Matching,
  result limits and snippet building are pure domain logic, tested without a document.
- A search result carries its match length as well as its page and offset, so arriving at the page
  can tint the matched words through `PDFView.highlightedSelections` — a transient selection tint,
  deliberately not a stored annotation and in a different colour from the marker. The offset is
  counted in Swift `Character`s while `NSRange` counts UTF-16 units, so the service re-slices the
  page's own text to convert exactly rather than assuming the two agree. The tint belongs to one
  arrival: the pager hands it to the page view it is about to build and keeps nothing, so swiping
  away and back produces a clean page.
- The page curl is the reader: a `UIPageViewController` with the system curl transition and one
  `PDFView` per page, sharing the document so crops, themes and highlight annotations apply unchanged.
  It sets only a data source — the app layer owns delegates — so each page reports itself when it
  appears. Because each page is its own view, the pager also owns what the single-view reader used to:
  jumping to a page for a search result or a highlight, and reporting a pinch so the zoom is
  remembered across pages and books. PDFKit's plain paging was removed once the device pass confirmed
  drag-to-select works under the curl; it is recoverable from Git history if that ever changes.
  A zoomed page keeps its own horizontal pan, so the pager never sees the swipe and the page does not
  turn until the zoom is released. That fell out of one `PDFView` per page rather than being designed,
  but the device pass confirmed it as wanted behaviour, so treat it as intended and do not route the
  gesture past the zoomed page.
- Fit pages to their text. A background pass renders every page's raw content, unrotated, into a
  small grayscale bitmap using its own `PDFDocument` (never the one on screen), finds the ink against
  the page's median paper brightness while ignoring specks, and caches the per-page ink boxes as a
  versioned `Layouts/<book>.json` — a regenerable cache excluded from backup and exports and removed
  with the book. The reader turns those into per-page `cropBox`es before first layout, with
  `displayBox = .cropBox`. The geometry — one shared text area with outlier edges ignored, left and
  right pages positioned separately at one size, per-page growth instead of clipping, full-bleed pages
  untouched, and whether cropping is worth it — is pure domain logic in `PageVaultCrop` and
  `PageVaultInkScan`, tested without a document. Crops apply once, as the reader opens: a measurement
  that lands while a book is open is used the next time it opens, because rebuilding the page view
  would lose the page being read.
- Anchor zoom to `scaleFactorForSizeToFit`: `minScaleFactor` equals the fit, so the reader cannot be
  zoomed out below the whole fitted page, and the maximum is a fixed multiple of it. Persist the
  zoom as a ratio of fit rather than an absolute scale, since the fit differs per document. Suppress
  the scale-changed notification while applying zoom programmatically or it will echo.
- Page changes are not persisted at all: the reader tracks the visible page in memory for its
  indicator and bookmark button, and only an explicit bookmark writes anything.
- Run text search asynchronously and cancellably if it enters v2; scanned PDFs may have no text.

## Build and deployment boundary

- Integrate PageVault in the common native hub target; no standalone PDF IPA or installed bundle ID.
  Use `../` as the canonical hub source/build owner. The former standalone bundle-ID
  suggestion is retired, not an instruction to rename an existing installation.
- PageVault adds no extension, App Group, HealthKit, push, iCloud capability, or background mode.  Preserve the common hub's Pushup Reminder notification/geofence services and central action routing.
- Akshat has no local Mac. `../.github/workflows/ios-build.yml` on a GitHub-hosted macOS
  runner creates the common unsigned Release IPA; Windows Sideloadly refreshes that cached
  binary, preserving identity and all three modules' data. Keep current/previous artifacts and
  source/version/capability/SHA-256 metadata outside Git; no media or signing secrets in the repo.
- Hub plus WHOOP uses two free-signing slots. Seven-day expiry, early refresh, USB recovery, and
  per-feature/full exports remain necessary. Uninstalling the hub removes every module's container
  data; PageVault directories/stores are logically separate, not separate OS sandboxes.
- `../hub-plan.md` and this project's `CLAUDE.md` own the activation/recovery gates.

## Physical-iPhone feasibility gate

Before a full scaffold is accepted, build the smallest PDFKit spike that imports, opens, scrolls,
zooms, navigates an outline, backgrounds, and resumes. Test outside Git with:

- a long text-heavy book;
- one of Akshat’s largest image-heavy/scanned PDFs;
- deep-outline and no-outline PDFs;
- malformed/incomplete and password-protected PDFs.

Pass only when import streams rather than buffers, the library avoids eager rendering, scroll/zoom
remain usable, memory pressure does not reproducibly terminate the app, cold/background resume is
sensible, outline behavior is understood, and low-storage/interrupted-import cleanup is safe. Measure
with Xcode/Instruments and record the implemented findings here; do not invent a memory threshold.

## Remaining scaffold decisions

Phase 1 closed the rest; see `CLAUDE.md` § Locked scaffold decisions for the settled values
(iOS 17.0, Xcode 26.6/XcodeGen 2.46.0/Swift 5.0, `com.akshatksingh18.akshatos` already
signing-accepted, SwiftData confirmed, PDFs included in device backup, versioned-JSON export
precedent, reader-only landscape). What genuinely remains:

- Nothing is open. Theme scope settled as paper, sepia and night, with sepia the default (`features.md`), and the full-library export
  container settled as a plain folder holding the manifest plus the copied PDFs.
- A Core Data/SQLite fallback remains a contingency only, not an open choice: SwiftData held up on
  device.

## Android fallback boundary

The prior Kotlin/Compose/Room/pdfium/SAF design is not the active architecture. If Android is later
activated, document it in a separate platform section with its own library choices and device gates;
do not mix persisted URI behavior into iOS or claim platform parity without testing both.

## Synchronization rule

Any material change to product scope, platform, storage ownership, data model, rendering, build/
signing, backup, or recovery must update this file, `features.md`, `CLAUDE.md`, and any future setup/
TODO guide in the same change. Keep plan, implementation, and physical verification explicitly
separate.
