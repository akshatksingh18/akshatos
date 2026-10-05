# PageVault

Personal, local-only PDF reader module in the native AkshatOS iPhone hub for PDFs Akshat already owns. The daily-use experience
should be Kindle-like: a cover library with progress, one page at a time on tinted paper, and a
bookmark that holds your place. It shares the hub's private installation with Pushup Reminder, Lift Log and Body, not an App Store
product: no account, backend, analytics, advertising, cloud-sync requirement, or remote push service.
Android may remain a later fallback, but it does not control the initial architecture.

**Status:** PageVault v1 is fully accepted on the physical iPhone through Build 24, including full
export/restore. Accepted Build 25 refreshed the library and Takeaways presentation into a themed
AkshatOS story-quest style; at Akshat's request AkshatOS 0.6.0 (29) replaces it with a plain,
minimal design (`features.md`), accepted on the phone with Build 31. That presentation passed the AkshatOS PR #52 macOS CI Gate, including simulator UI
tests and device compilation; its checksum/IPA validation, Wi-Fi install and current-version
automatic-refresh enrollment pass. Akshat reports the installed Build 25 works perfectly, accepting
the refreshed presentation; the artifact is now AkshatOS's recovery/refresh copy. This focused report
does not add new evidence for the deliberately unmeasured edge cases below. The daily reading
loop was first **confirmed on the physical iPhone** as of Build 20, closing
phase 3's core question. Build 22's pass confirmed search page-jumps and the per-book passage list,
and found the highlighter stacking marks over each other that it then could not remove. The
highlight rework shipped in Build 23 and is **accepted on the phone**. That pass also explained the
one mark that would not clear — it was inside the PDF file, not PageVault's. Build 24 hides that
class of mark when it is a genuine annotation, alongside a direct page jump for long books, but a
mark flattened into the page's own artwork (confirmed present in a real book Akshat supplied) is not
an annotation and Build 24 cannot reach it — see `features.md`'s highlight-boundary note. All three of
Build 24's changes are now **confirmed on the phone** — routing, the page jump, and the annotation
hiding, the last against `07-highlight-boundary.pdf` from `make-test-pdfs.py`, which carries both
kinds of mark side by side: the annotated pages came up clean and the flattened page kept its marks,
which is the boundary behaving correctly rather than a defect. The stuck-mark defect first seen in
Build 22 is closed. **Export and restore have now passed on the device too** — a book removed from
the library came back from a full export with its reading place and highlights intact — which closes
the gate Akshat deliberately held to the end and, with it, v1's last unverified feature. What remains
is a clean-install restore, which means uninstalling and is his call, plus reading-data-only restore
and the Started shelf, neither of which the device rounds covered. Reading streaks were removed at his request.
**Read aloud** (from AkshatOS 0.8.0 (31)): a headphones button reads the book aloud from the page on
screen with the phone's own voice, tinting the sentence, turning pages and continuing with the screen
locked. On the phone its controls work but Build 31's voice sounded robotic and broken up; 0.9.0 (32)
speaks a page as one passage and is installed, but Akshat reports it still sounds robotic.
Local Build 33 fixes Best available to rank quality across regional language variants; CI, an IPA
and a phone pass for that change remain pending. `features.md` § Read aloud.
**Removed in Build 29:** Build 28 added a linked OneDrive laptop inbox folder and Open in AkshatOS. On the
phone, linking the folder did nothing, and Akshat asked for both to be removed; AkshatOS Build 29
takes them out (see the laptop-to-phone decision below). PDFs still reach PageVault through the
picker from a cloud folder his laptop syncs.
`../cloud-build.md` owns build numbers and per-build phone findings.

Recorded large-PDF gate results. The fixtures are not kept on disk — the set ran to 190 MB, nearly
all of it one synthetic scan — so regenerate them with `make-test-pdfs.py` when a device pass needs
them:

- A **188 MB, 120-page** scan-like PDF imported and read with all pages loading; no termination and
  no whole-file buffering observed.
- A 600-page text book, a 180-page three-level outline and a 40-page outline-less PDF all worked.
- A truncated file and a password-protected file were each rejected with a clear message and left no
  library entry.
- Re-importing a book already in the library was correctly refused.
- Reader landscape worked while the rest of the hub stayed portrait, and Pushup Reminder was unaffected.
- **Not measured:** Instruments memory figures, cold-launch restore, low-storage behavior, and a
  real (non-synthetic) scanned book. Those remain open.

What the phone has confirmed, and what is still open:

- **Confirmed on Build 20:** pages fitted to their text, with the text block filling the screen width
  and the margins gone; reopening a book landing on its bookmark; the tinted page; paged swiping; and
  a full-library export producing every book. Installing over the previous build left the library intact.
- **Confirmed on Build 21:** the page curl, including that dragging to select a line still works
  under it, and highlights themselves. That settled the one open question about the curl, so it is
  now the only reader and PDFKit's plain paging was removed.
- **Confirmed on Build 22:** jumping to a page from a search result lands correctly; the per-book
  passage list's **Go to page** works; and a zoomed page refusing to turn is **wanted behaviour**,
  not a defect — see `features.md`, and do not change it.
- **Found broken on Build 22, fixed for Build 23:** the highlighter stacked two or three marks over
  the same words and a mark could not be removed by hand, both because highlight identity compared
  captured text instead of the page area covered. Deleting such a passage in Takeaways left its
  siblings drawn, which read as a mark that would not go away. Takeaways passages also had no way
  to reach their page, and the passage bin deleted without asking.
- **Confirmed earlier:** the large-PDF gate above, and the tinted page on text pages.
- **Closed unverified, by Akshat's decision:** reading-data-only export and restore, the Started
  shelf, and a clean-install restore. He judged all three redundant once the full export/restore
  round passed, and wants no further changes. They stay implemented-but-unexercised rather than
  open work; do not re-propose them. The one consequence worth remembering is that restoring onto a
  wiped or reinstalled app is unproven, so an export is not yet demonstrated to be a backup.
- **Confirmed on Build 23:** the Highlight / Remove highlight menu, a wider selection extending a
  mark instead of stacking one, removing a mark by hand, the tint on a searched phrase after a jump,
  Go to page from a Takeaways passage, and the bin's confirmation. Akshat called the set "perfect".
- **Explained on Build 23; only half of it was fixable.** One mark stayed on a page, absent from the
  passage list and impossible to clear. It was never PageVault's — PageVault writes nothing into the
  PDF and redraws marks from its records on every open, so a mark with no record cannot be its own.
  Inspecting the actual book settled what it is, and it is **not an annotation**: the file carries
  2086 `/Link` annotations and **zero** highlight annotations. The yellow is 65 Form XObjects filled
  with one flat colour, drawn into 48 pages like any other artwork — a highlighter's output
  flattened into the page. Every one was checked and carries no text, image or other colour.
  Build 24's annotation fix was still a real fix — ownership was inferred from any `userName`, so
  PageVault could neither clear an unnamed mark nor avoid deleting a genuine author-tagged one — but
  it cannot touch this book, because there is no annotation to hide. See the boundary in
  `features.md`: artwork printed into a page is the page.
- **Confirmed on Build 24 — the pass that closed v1.** The annotation hiding, against a fixture
  carrying both kinds of mark: the annotated pages came up clean and the flattened page kept its
  marks, so the fix and the boundary were both shown in one import. The page jump by slider and by
  typed number, out-of-range refused, bookmark unmoved. Notification routing, including from a book
  left open, **Done** not moving the screen, and the 9:00 AM invitation not starting a day.
  Then full-text search, the page themes with night inverting legibly, the highlights PDF export,
  and Takeaways' own list. Finally **export and restore**, the gate held back to the end: a
  full-library export, the book removed from the library, and a restore that brought it back with
  its reading place and its highlights intact — the missing-book path that had never been exercised.
  None of it is something CI can reach.
- **Removed after that pass:** daily page goals and reading streaks, at Akshat's request. The goal
  control, streak card and per-day records are gone, and `features.md` records the decision.
- **The remaining blank band** above and below a full page is the shape difference between a book's
  text block and a phone screen, not margin. `features.md` records why only text reflow could close
  it, and reflow is not in v1.
- **Never measured:** Instruments memory figures, cold-launch restore, low-storage behavior, and a
  real scanned book.

## Files

- `.gitignore` — Android plus iOS/Xcode/SwiftPM build output, local configuration, signing material,
  packaged-app, and `*.pdf` exclusions; never commit credentials, profiles, certificates, personal
  PDFs, or IPAs. The hub repository's own `.gitignore` carries the same PDF rule, which matters more
  there because PageVault's source and feasibility fixtures live in that currently public repository.
- `features.md` — current iPhone-first product scope, v1 recovery loop, optional later features,
  Android fallback boundary, and feature acceptance rule.
- `architecture.md` — current SwiftUI/PDFKit/SwiftData plan, copy-on-import/data model, build boundary,
  physical-iPhone feasibility gate, and explicitly separate Android fallback.
- `make-test-pdfs.py` — regenerates the physical-test fixtures (long text, deep outline, no outline,
  scan-like, password-protected, truncated, and the highlight-boundary book) into a chosen folder. Needs `pypdf` and Pillow. Run it
  rather than hunting for sample files; its output is deliberately not committed.

## iPhone product and deployment decision

The accepted packaging is one native SwiftUI hub containing PageVault, Pushup Reminder, Lift Log
and Body, plus one standalone WHOOP app. This uses two free-signing slots; there is no pending
fourth-slot or paid-tier requirement. `../hub-plan.md` owns the package boundary and identity/
source-owner contract. `../` owns the hub source, which contains PageVault's
implementation; as of Build 24 it is **verified on the phone**, v1 feature by v1 feature.

PageVault is a module, not a separate iOS target or IPA. Use the hub's verified permanent bundle
identity; the former standalone `com.akshat.pagevault` suggestion is retired. No target or installed
PageVault identity has been created. The hub display name is **AkshatOS**, owned by `../hub-plan.md`.
Use the canonical `../` hub repository and its selected bundle ID; explicitly
test any existing-container migration rather than uninstalling.

PageVault needs no widget, extension, App Group, push or iCloud capability. Read aloud uses the
hub's audio background mode; this is its only declared background mode.
The hub additionally contains Pushup Reminder' ordinary local notifications and optional Home-region services.
Do not remove necessary hub services when enforcing the PDF module's minimal capabilities.

Build a conventional native Release hub IPA via the hub's GitHub Actions macOS-runner workflow (no
local Mac), then sign/refresh it from Windows with Sideloadly. No injection, guest-app launcher, JIT,
or installer-specific runtime is planned. The
same Apple Account/team and hub bundle identity must be preserved on refresh; free profiles still
expire after seven days. The detailed operational gates below apply to PageVault inside the hub,
not an independent PageVault installation.

### Current authoritative references

- Re-check Apple's account documentation before deployment. It currently allows up to ten App IDs
  and three devices, both expiring after seven days, plus three installed apps per device and
  seven-day provisioning profiles:
  <https://developer.apple.com/help/account/basics/about-your-developer-account/>.
- Re-check Sideloadly's official FAQ and changelog before activation and after an iOS, Apple-login,
  or Apple-device-component change. They document current iOS support, background refresh,
  same-bundle overwrite behavior, Wi-Fi/USB caveats, retries, and authentication fixes:
  <https://sideloadly.io/faq.html> and <https://sideloadly.io/changelog>.
- The proposed reader/import design is grounded in Apple's current PDFKit and SwiftUI APIs. Confirm
  availability against the final deployment target when scaffolding:
  <https://developer.apple.com/documentation/pdfkit/pdfview> and
  <https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aoncompletion%3A%29>.

## Locked scaffold decisions

Phase 1 is closed. These values come from the hub's implemented state, not fresh assumptions;
`../ios/project.yml` and `../.github/workflows/ios-build.yml` are authoritative and
PageVault does not choose its own target or toolchain.

- **Deployment target:** iOS 17.0, iPhone-only (`TARGETED_DEVICE_FAMILY: 1`). SwiftData is therefore
  available.
- **Toolchain:** Xcode 26.6 on the `macos-26` GitHub-hosted runner, XcodeGen 2.46.0, Swift 5.0
  language mode — all pinned by the hub workflow.
- **Identity:** `com.akshatksingh18.akshatos`, physically signing-accepted through Build 13.
  PageVault adds no target, bundle ID, entitlement, or installed app slot.
- **Persistence:** SwiftData confirmed. Pushup Reminder already runs a file-backed SwiftData store in the
  installed build with passing round-trip/reopen coverage, so the store mechanism is de-risked. A
  Core Data/SQLite fallback now applies only to a concrete PDF-scale blocker found in phase 2, not
  as an open architecture choice.
- **Module placement:** `ios/AkshatOS/features/pagevault/{domain,data,services,ui}`, enforced by
  `../ios/scripts/check-boundaries.py`. PageVault must not depend on other features or the
  app layer; `shared/` and `app/hub/` must not reference persistence or OS services; the
  process-wide notification delegate stays app-owned.
- **Domain purity:** `domain/` may import Foundation only, so **PDFKit may not appear there**.
  Import, rendering, and cover code belong in `data/`/`services/`; reading-status, place,
  page-fitting and page arithmetic stay pure domain logic and are covered by the executable domain suite.
- **Test registration:** add a `pagevault` entry to `../ios/tests/feature-tests.json` with
  its domain sources, `tests/pagevault/main.swift`, integration tests, and UI tests so `CI Gate`
  covers it per `../ci.md`. The existing UI assertion that `open-pageVault` does *not*
  exist must be updated in the same change that makes the module available.
- **Orientation:** hub, library, and Pushup Reminder stay portrait; the reader screen may rotate to landscape.
  Implement this per-screen rather than enabling landscape app-wide, because the Pushup Reminder dashboard was
  built and physically verified portrait-only. Prove rotation in the phase 2 spike.
- **Device backup:** copied PDFs are **included** in device/iCloud backup; do not mark the PDF store
  excluded-from-backup. The honest caveat is that the iPhone backup grows with the library, so a large
  library can strain iCloud storage — revisit if phase 2's storage measurement makes it impractical.
  Backup is a convenience, not a substitute for versioned export/restore, and uninstalling still
  deletes the container.
- **Export format:** follow Pushup Reminder' precedent in `SquatsBackup.swift` — a versioned JSON manifest
  with whole-file validation for the metadata-only export. The full-library export is a **plain
  folder** holding that manifest plus the copied PDFs, saved through Files. Akshat chose it over a
  single `.zip`, which would need a hand-written ZIP64 codec or the hub's first third-party package,
  and over Apple Archive, which Windows cannot open. The accepted cost: a folder cannot be sent by
  AirDrop or Mail.
- **Privacy:** unchanged. No network, account, or analytics use, and no new Info.plist usage
  descriptions: the system file importer needs no added entitlement, and the existing location/
  notification descriptions belong to Pushup Reminder.

The two decisions left open at phase 1 are now settled: the themes are paper, sepia and night
(`features.md`), and the full-library export is a plain folder (above).

## Recommended iOS architecture

- **UI:** SwiftUI on the locked iOS 17.0 target. Wrap PDFKit's
  `PDFView` with `UIViewRepresentable` for the reader rather than implementing a PDF renderer.
- **PDF engine:** Apple's PDFKit (`PDFDocument`, `PDFView`, `PDFPage`, `PDFOutline`, and
  `PDFSelection`). It supplies continuous/single-page display, native zoom, page navigation,
  thumbnails, outline traversal, and later text search without a third-party rendering dependency.
- **Metadata:** a local SwiftData store with an explicit versioned schema and migration plan. Store
  stable book UUID, internal PDF filename, display metadata, page count, cover-cache key, added/opened
  timestamps, current reading destination, and bookmark records. If feasibility work exposes a
  SwiftData blocker, Core Data or SQLite is an acceptable replacement, but persistence must stay
  local, versioned, testable, and independent of a service.
- **Files:** imported PDFs live under app-private Application Support, organized by stable book UUID.
  Cover thumbnails are a disposable cache that can always be regenerated from page one. Do not load
  an entire PDF or pre-render every page into memory.
- **Network:** the app should make no network requests during normal use. A source selected through
  Files may itself come from an iCloud/Dropbox/other document provider, but PageVault must complete a
  local copy during import and work offline afterward; that provider is not a runtime dependency.

### PDF import and ownership decision

The iOS v1 decision is **copy on import**, not a permanent external-file reference:

- Present the system document picker for PDFs, with multi-select when the platform flow supports it.
- While the returned URL is available, call `startAccessingSecurityScopedResource()` as required,
  coordinate/stream the copy into PageVault's Application Support directory, validate that the file
  can be opened as a PDF, then stop security-scoped access in a `defer` path. A cloud-provider source
  may need to finish downloading before the copy can complete; show progress and a recoverable error.
- Never read a multi-hundred-megabyte PDF into a single `Data` value. Copy it as a file/stream and
  generate only the page-one thumbnail and metadata needed for the library.
- Keep the user's source PDF untouched. "Remove from library" deletes PageVault's private copy,
  metadata, progress, bookmarks, and regenerable cache only; it never deletes the original selected
  through Files.
- Detect duplicate imports by a content hash or an equivalent stable fingerprint computed as a
  stream. Let the user keep a second copy only through an explicit future product decision.

The storage duplication is intentional. Persisting only a security-scoped bookmark/reference can
save space, but the bookmark can become stale, its permission can be revoked, a document provider can
go offline, or the user can move/delete the source. Resolving such a bookmark also requires careful
balanced security-scoped access on every open and a reconnect flow. That is a worse default for a
daily offline reader. If a future "reference in place" mode is added for exceptionally large files,
it must be opt-in, clearly label its availability risk, persist a bookmark, detect stale resolution,
and offer a user-driven relink path; it must not silently replace copy-on-import.

**Laptop-to-phone import (Akshat's decision: the picker is enough).** PDFs on his Windows laptop
reach the phone through a cloud folder the laptop syncs (OneDrive); he adds them with PageVault's
picker. Build 28 tried two more doors — a linked OneDrive inbox folder copied in on every open, and
Open in AkshatOS from share sheets. On the phone, tapping **Open** in the folder picker linked
nothing, and he asked for both to be removed rather than fixed; Build 29 removes them. Do not
re-propose either. Also rejected earlier, for the record: an in-app upload web server (networking and
the Local Network permission in a network-free app), a share extension (an extra App ID/target
against the hub plan), and exposing the app's Documents folder through file sharing.

Copy-on-import also creates an important recovery caveat: uninstalling PageVault deletes its app
container and therefore its private PDF copies. The original PDFs or a full PageVault export must
exist elsewhere before uninstalling. A merely expired provisioning profile normally prevents launch
but does not itself erase the installed container; when repairing signing, do not delete the app.

## Mapping the feature plan to iOS

- **Import and library:** use the system picker and the copy workflow above. Render a first-page
  thumbnail with `PDFPage.thumbnail`, cache it, and display a SwiftUI grid with title, author,
  progress, and recoverable states for a corrupt, encrypted, or incomplete import.
- **Reading status:** a per-book status field (Want to Read/Reading/Finished), defaulting to Want to
  Read on import. Enforce the single-Reading-book invariant in the SwiftData layer (e.g. demote the
  previous Reading book in the same write transaction), not only in the view. The library's
  "continue reading" surface is just the Reading book filtered/sorted by existing progress and
  last-opened data — no separate continue-reading store. Likewise the Started shelf is derived, not a
  fourth status: Want to Read books that have a place.
- **Reader:** `PDFView` in `.singlePage` + `.horizontal` with `usePageViewController`, so one page
  fills the screen and a swipe turns exactly one page. Continuous vertical mode was tried on device
  and rejected for showing two half pages. Keep native pinch zoom. Do not reach into undocumented
  `PDFView` subviews to force a gesture. The page curl is the accepted exception and is now the only
  reader: the device pass confirmed drag-to-select still works under it, so PDFKit's plain paging was
  removed. The pager owns page jumps and remembered zoom, because each page is its own view. The
  page indicator is the entry point for jumping to a page directly, by slider or typed number;
  `features.md` owns why both. Jumping never writes the place — only bookmarking does.
- **Your place:** persist one zero-based page per book, written only when the reader bookmarks it,
  and treat that write as also claiming the book as the one being read and crediting the pages
  covered since the previous bookmark. Reading and browsing persist nothing. Apply the opening page
  **after** PDFKit has laid the document out — a `go(to:)` issued immediately after setting
  `document` is silently dropped — and ignore reported page changes until that restore completes, or
  PDFKit's own page-one report will overwrite the restored position.
- **Bookmarks:** one per book, stored as the book's place in the metadata store. Bookmarking
  replaces the previous place. Never a mutation of the source or copied PDF.
- **Table of contents:** removed from v1 at Akshat's request after it was verified working. Do not
  reintroduce the navigator without asking; the traversal is recoverable from Git history.
- **Page themes:** sepia is a tinted overlay with `layer.compositingFilter` set to
  `multiplyBlendMode`, which tones the page while leaving black text black; a plain translucent
  overlay is what washes text out. A stored warm theme maps to sepia, so no choice is lost. Night uses `differenceBlendMode` against white, which inverts the
  page into light text on dark. Keep the `PDFView` background white and page shadows off so the
  overlay covers page and surround alike. Legibility on the image-heavy scan is still unconfirmed.
- **Remove:** require confirmation, delete only the app-owned copy and local records, and keep the
  original source untouched. Cover-cache cleanup should be deterministic.
- **Search:** implemented over each page's text layer, off the main actor, with the calling task's
  cancellation stopping the work so the next keystroke supersedes the one before. Matching and
  snippets are pure domain logic; PDFKit only supplies page text. Never promise results for
  scanned/image-only PDFs — there is no OCR.
- **Highlights:** stored as PageVault metadata on the book record, never written into the PDF, and
  replayed as in-memory annotations each time the book opens. They travel inside exports for free,
  because the manifest embeds the book record. Takeaways is the library-level view of them: books
  that have kept passages, most recently marked first, each opening the same per-book list, whose
  passages open their book at their page. Derive it from the records rather than storing a second
  index. The set exports as its own PDF of passages; an annotated copy of the book is explicitly
  not wanted.
- **Highlight identity is geometric, and the highlighter states its intent.** A mark is identified
  by the page area its line bands cover, not by the text captured with it; the highlighter offers
  Highlight and Remove highlight rather than inferring which is meant. Marking words that already
  carry a mark extends that mark, and removing clears every mark the selection covers. Two bands
  count as the same words only when they overlap by more than half the shorter one's height, so a
  band touching the line below is not absorbed and a paragraph stays one band per line rather than
  a block over its indents.
  Both halves are load-bearing and were proven necessary on the phone: a toggling highlighter that
  compared captured text treated a selection one word wider as a new mark, so the same passage
  collected two or three overlapping marks that composited darker, and no hand-made selection could
  reliably reproduce the original to remove one. Do not reintroduce text-equality identity or an
  inferring highlighter.
- **Collections, recent reading, and statistics (later):** derive these locally from the same
  metadata schema. They must not introduce an account or analytics service.
- **Out-of-scope material:** retain the PDF-only, no DRM bypass, no OCR, no accounts, no multi-user,
  and no mandatory sync boundaries from `features.md`.

## Large-PDF feasibility gate — passed, with remainders

The gate ran on the actual iPhone and passed on its core question: a 188 MB, 120-page scan-like PDF
imported and read without termination, alongside a 600-page text book, deep-outline and
outline-less files, and correctly rejected corrupt and password-protected samples. Status above
records the full result. Fixtures are generated locally and stay out of Git.

What the run did **not** establish, and what any future large-PDF claim still needs:

- Instruments memory figures. No numbers were captured, so "memory held" is an observation, not a
  measurement; do not quote a threshold that was never measured.
- Cold-launch restore, which could not be judged while the restore defect was present.
- A real scanned book. The 188 MB fixture is synthetic grayscale noise shaped like a scan; genuine
  scans add odd fonts, OCR layers, mixed page sizes and occasional malformed structure.
- Low-storage behavior, device lock/unlock, repeated open/close cycles, and first-cover generation
  time on a large file.

## Build, signing, and weekly-refresh operating model

There are two separate lifecycles. Keep them separate so a weekly signing refresh never requires a
source rebuild.

### Producing a new build

Akshat has no local Mac. The accepted primary compiler is the hub's GitHub Actions workflow
(`../.github/workflows/ios-build.yml`) on a pinned GitHub-hosted macOS/Xcode runner — not a
physical/rented Mac. `../ci.md` owns the pipeline mechanics (classification, required
checks, coverage, minutes/visibility) and `../cloud-build.md` owns the exact artifact/
checksum/download/Sideloadly-smoke-install procedure; read both before changing or relying on the
build. A borrowed/rented Mac or another macOS builder remains a documented emergency fallback only
(see Alternatives below), not the normal path.

1. This folder holds the feature plan inside the hub repository `../`, which owns source, tests and
   builds per `../hub-plan.md`. Windows authors the source; PageVault code, assets, dependencies, deployment target,
   or entitlement changes are pushed to that repository and built by its cloud workflow, not by local
   tooling. A simulator build is not an installable iPhone build.
2. The workflow builds and tests one arm64 Release hub archive with the verified permanent hub
   identifier and the minimal capabilities above, and packages a standard unsigned/re-signable IPA;
   do not bind app logic to a particular Apple ID or Sideloadly.
3. The workflow records the source commit, marketing/build version, bundle ID, minimum iOS version,
   expected entitlements, and SHA-256 checksum; `../cloud-build.md` is the release manifest
   for that evidence.
4. Download the accepted unsigned IPA from the workflow run to a stable Windows-local release cache
   outside Git. Keep at least the current known-good and immediately previous known-good build, plus
   their checksums. The exact path and recovery procedure must be documented once the scaffold creates
   a `setup.md`; this cache, not continued cloud/Mac access, is what weekly refreshes depend on.
5. Never put Apple credentials, two-factor codes, Anisette data, private keys, provisioning profiles,
   signed IPAs, or the unsigned IPA cache in Git or GitHub Actions.

A new cloud build is not needed merely because seven days passed. Windows repeatedly signs and
installs the cached, already-tested IPA. A new build is needed after application changes or when a
future iOS/Xcode compatibility change actually requires rebuilding.

### Installing and keeping it signed from Windows

1. Install Sideloadly and its currently required official Apple Windows components, pair the iPhone,
   enable Developer Mode and trust, enable iTunes **Sync with this iPhone over Wi-Fi**, and complete
   one successful USB install first. Sideloadly currently warns that wireless discovery can
   occasionally require iTunes to be open or the iPhone screen to be on, and some Windows pairing
   errors require the web/non-Microsoft-Store Apple components. Re-check the current FAQ instead of
   freezing those dependencies as permanent architecture.
2. Use Sideloadly Local Anisette and the same free Apple ID/Personal Team every time. Local Anisette
   removes dependence on a third-party Anisette relay, but signing still necessarily contacts Apple's
   authentication/provisioning services and Sideloadly itself remains replaceable tooling.
3. Preserve the shared hub identifier; disable bundle-ID randomization, tweak/dylib injection, and other
   advanced signing options. Pin/document the working signing settings so an automated refresh cannot
   silently change entitlements or identity.
4. Run the Sideloadly refresh daemon at Windows sign-in and keep Wi-Fi refresh enabled. Check app
   freshness every day or at worst every 48 hours. Sideloadly documents that its daemon acts when
   apps are "near expiry" but does not promise a user-configurable threshold: target a verified
   refresh while at least three days remain, and if the daemon has not done it, use the supported
   **Refresh All Apps Manually**/normal same-IPA install path. **Do not** create one brittle task that
   runs exactly once every seven days or blind GUI automation that calls opening the tool success.
5. Retry while the iPhone and Windows machine are on the same network. If no success is recorded
   within 24 hours of the first buffered attempt, raise a visible Windows notification and use USB as
   the deterministic recovery path. A success signal must identify PageVault's bundle ID and new
   expiry, not merely that the daemon process ran. **This is implemented** as the `AkshatOS Signing
   Health` scheduled task; `../setup.md` owns it, including the finding that Sideloadly's
   daemon has not yet been observed to refresh anything, so the refreshing half stays unproven.
6. Keep the phone installed and do not uninstall on refresh/authentication failure. If Apple changes
   authentication and Sideloadly temporarily breaks, the three-day buffer is the repair/fallback
   window. Profile expiry may block launch, but repair with the same Apple ID/team and bundle ID before
   considering removal.
7. After initial setup, validate two unattended refresh cycles and one deliberate USB recovery before
   calling the automation dependable. Periodically open PageVault after refresh and verify its local
   library/progress; re-signing the identical build should not change runtime behavior or data.

The weekly experience can be automated, but it cannot be guaranteed forever: Apple controls free
provisioning, authentication, and the seven-day profile, and can change the protocol. The durable
asset is therefore the standard IPA, stable app identity, local data export, documented settings,
early retries, and replaceable desktop signer—not a promise that one third-party utility will never
need an update.

## Data protection, export, and recovery

- Keep PDFs and the metadata database app-private with normal iOS file protection. Cover thumbnails
  are disposable and should be excluded from exports/backups unless convenient to regenerate.
- Provide an in-app, versioned export before PageVault becomes a daily driver. A metadata-only export
  contains library manifest, progress, bookmarks, schema version, and checksums; a full-library export
  additionally contains the app-owned PDF copies. Let the user choose a destination through the
  system exporter so the archive can be transferred locally and does not require PageVault servers.
- Provide and test import/restore of that archive. Validate versions and hashes, handle conflicts
  explicitly, and never overwrite an existing library without confirmation. Implemented from the
  library's "Back up or restore" sheet: each book's streamed SHA-256 fingerprint is its checksum,
  books are matched by content, and books already present are left alone unless the user confirms
  replacing their place and history. `architecture.md` owns the details. An export that cannot be
  restored on a clean install is not a backup.
- Make the storage cost of a full export clear. Original PDFs remain an acceptable independent backup
  only if metadata/bookmarks/progress are separately exported.
- Application Support PDFs are included in automatic device/iCloud backup (see Locked scaffold
  decisions). The app itself must still not require cloud backup, and the UI must direct the user to
  an explicit full-library export before uninstalling or replacing the phone, because uninstalling
  deletes the container regardless of what a device backup holds. If phase 2's storage measurement
  shows the library would strain iCloud storage, revisit this and record the change here.
- Test an in-place re-sign/update with the same bundle ID, an application-version upgrade with a
  schema migration, an expired-but-not-deleted app repaired by signing, and a clean reinstall restored
  from export. Changing the bundle ID or signing with an incompatible team can create a second app or
  lose access to the existing container, so treat identity as persistent data.

## Physical-device acceptance matrix

Before declaring the iPhone build ready for personal daily use, verify all of the following on the
actual iPhone and current iOS release:

- The native hub (PageVault, Pushup Reminder, Lift Log, Body) coexists with standalone WHOOP using two free slots.
  PageVault adds no extension/helper application slot. Reader navigation leaves pushup scheduling
  and actions intact, and releasing a PDF view does not tear down hub services.
- USB initial install, Wi-Fi re-sign, Windows restart/daemon restart, phone restart, locked-phone
  retry, temporary network loss, Apple-authentication re-login, and USB fallback all have understood
  outcomes and visible failure reporting.
- A same-IPA refresh, an upgraded IPA, and two unattended cycles retain PageVault's copied PDFs,
  progress, bookmarks, and stable icon/bundle identity.
- Import works from On My iPhone and at least one enabled Files document provider; cancellation,
  duplicate selection, insufficient storage, provider download failure, corrupt PDF, and app
  interruption during copy leave no false library entry or orphaned partial file.
- Representative small, very large, scanned/image-heavy, outline/no-outline, landscape/mixed-page,
  and encrypted/password-protected PDFs either work or fail with the documented user-facing state.
- Continuous reading, zoom, navigation, rotation, background/foreground, device lock, memory pressure,
  and cold resume do not crash and restore sensibly.
- Removing a book deletes the private copy and its local records but demonstrably leaves the original
  Files source untouched.
- Metadata-only and full-library exports restore successfully into a clean app container. Exercise
  this recovery before relying on PageVault as the only holder of annotations/progress.
- PageVault remains fully usable in airplane mode after import; only weekly Apple signing/refresh is
  external to normal app operation.

## Implementation phases and acceptance gates

1. **Lock scaffold decisions — done.** Deployment target/toolchain, bundle ID, SwiftData
   suitability, module boundaries/test registration, orientation, device-backup policy, export
   format precedent, privacy, and shared-hub identity/source ownership are settled in Locked
   scaffold decisions above. Theme scope and the export container, left open at the time, have since
   been settled there too.
2. **Prove PDFKit — passed.** Import streamed without whole-file buffering, pages were not eagerly
   rendered, the 188 MB scan-like book did not terminate the app, and rejection paths behaved. The
   remainders listed under Large-PDF feasibility gate above are carried into phase 8 rather than
   reopening this phase.
3. **Build the core library — implemented, gate still open.** Transactional import/copy, payload
   compatibility for older records, cover cache, library/remove, paged reader, page themes, your
   place and reading status are written and covered by automated data tests. Gate
   remaining: the complete offline daily loop proven across device restart and an in-place app
   upgrade, plus confirmation that the restore fix and paged reading actually behave on the phone.
4. **Close feature/quality gaps:** resolve themes honestly, add accessibility/error states, and tune
   large-file performance. Gate: every v1 statement in `features.md` either passes on-device or has
   been deliberately re-scoped there before release.
5. **Make data recoverable — implemented, gate open.** Versioned metadata-only and full-library
   export plus validated restore are written and covered by domain and real-file integration tests,
   including restore into a fresh library and a tampered PDF restoring nothing. Gate: a destructive
   test using a disposable library proves recovery on the phone, including after a clean reinstall;
   do not use a real library as the first restore test.
6. **Make a portable release:** produce/checksum the standard Release IPA, cache known-good builds on
   Windows, document exact build/sign settings, and test in-place update with the stable identifier.
   Gate: another compatible signer could use the same IPA without an app-code change.
7. **Operationalize signing:** configure Local Anisette, Sideloadly daemon startup, 24–48-hour health
   checks, three-day buffer, retry/alert behavior, and USB fallback. Gate: PageVault coexists with the
   standalone WHOOP app, preserves all three modules' data over two refreshes, and recovers from a
   forced failure.
8. **Daily-driver release:** exercise the full physical-device matrix and keep a current recoverable
   export. Gate: no open crash/data-loss/signing blocker remains; deferred search, annotation,
   collections, and statistics work stays explicitly outside v1.

## Alternatives and fallback roles

- **PWA:** a simplified offline reader could avoid code signing, but iOS web storage can be evicted,
  durable access to user-selected files is weaker, and large-PDF rendering/file handling is a poorer
  fit than native PDFKit. Keep PWA as a contingency if Apple removes workable free provisioning, not
  the PageVault primary now that weekly Windows refresh is acceptable.
- **LiveContainer:** PageVault does not need JIT, and running it as a guest adds container identity,
  permission, data-migration, and compatibility complexity without improving PDF reading. It may be a
  lab/testing fallback for multiple builds, not the daily library or the only location of copied PDFs.
- **SideStore/AltStore:** useful emergency signers, but their on-device host consumes a Personal Team
  app slot. The selected hub-plus-WHOOP model uses two, leaving one unallocated. Adding a signer
  host is a separate workflow decision, not required. Never omit/uninstall the hub or WHOOP merely
  to change signers; verify export/restore and get an explicit choice. These hosts are
  fallback/recovery tools, not the agreed primary workflow.
- **Direct Xcode install or another desktop signer:** valid emergency routes when a compatible Mac or
  signer is available. Use the same Apple ID/team, stable bundle ID, and standard IPA and avoid
  uninstalling so the existing data container has the best chance of remaining intact.
- **Android build:** the current Android draft can be revived for the old Android phone after the
  iPhone MVP if desired. It should be a separate platform plan and must not force Android libraries or
  file-access semantics into the iOS implementation.
- **Enterprise/leaked certificates, DNS revocation blocking, jailbreak/exploit-only persistence:** do
  not base PageVault or its data safety on them. They are revocable, version-dependent, and harder to
  recover than the free Personal Team plus an early-refresh/fallback-signer workflow.

## Repository and hosting

This folder is part of the AkshatOS repository (currently public), beside PageVault's source in
`../ios/AkshatOS/features/pagevault/`. At Akshat's request it was merged in from the former private
`book-reader` repository after a privacy review found no personal data; that repository keeps the
earlier commit history, and only the current files moved. GitHub stores source and documentation
only — never personal PDFs (all `*.pdf` are ignored), signing material, provisioning data,
credentials, device exports, or release IPAs.

## Working agreement

- PageVault is activated and phases 1–2 have passed; implementation continues phase by phase in
  `../`. Do not describe a later phase as closing an earlier phase's open gate.
- Treat this `CLAUDE.md` as the current platform/deployment decision, `features.md` as product scope,
  and `architecture.md` as the current technical plan. Keep all three synchronized, and keep
  implemented, cloud-tested and phone-verified claims distinct.
- Fix the behaviour, not its appearance. Painting the surround to match the page was rejected as
  "just a cosmetic change" when the real problem was page geometry; measuring every page and cropping
  to the text is what was wanted. Prefer removing a near-duplicate option to keeping both, as warm
  was dropped for sepia.
- Optimize first for the actual iPhone, local ownership, reliable reading, recoverable data, and a
  standard portable IPA. Avoid App Store/general-market architecture and avoid capabilities that the
  personal build does not need.
- Re-check current Apple Personal Team and Sideloadly requirements against official/current sources at
  setup time. Preserve the durable design when transient commands or version numbers change.
- Never commit private PDFs, signing material, Apple credentials, Anisette data, provisioning files,
  or release IPAs. Use synthetic/public fixtures for tests and keep personal feasibility PDFs outside
  Git.
- Any persisted-data change needs a schema migration and upgrade/restore test. Any bundle-ID,
  entitlement, storage-policy, or import-ownership change is an architecture decision, not a casual
  refactor.
- Any material product, platform, architecture, storage, build/signing, backup, status, or feature
  decision must update this file and every affected current-state supporting document—especially
  `features.md`, `architecture.md`, and future setup/TODO guides—in the same change. Keep planned,
  implemented, and physically verified claims distinct and search for superseded Android/iOS
  assumptions before finishing.
- When a new working file is added, add a bullet for it under `## Files` in the same edit. A future
  `setup.md` should own exact GitHub Actions cloud-build, Windows cache, Sideloadly, automation, and
  recovery commands; a future `todo.md` should own known implementation gaps. Keep this file as the
  durable operating plan rather than a chronological work log.
