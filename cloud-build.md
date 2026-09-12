# AkshatOS cloud build and iPhone installation

**State:** Builds come only from the GitHub Actions macOS workflow and are verified on Windows before
handover. Build 13 is the accepted Squats daily-use baseline, and **Build 20 is installed and accepted
for PageVault's reading loop**: page fitting, bookmark restore, warm paper, paged swiping and a
full-library export all passed on the phone. Build 21 added highlights, search, page themes and the
page curl; the curl and highlights passed on the phone, the rest was not tested. Build 22 made the
curl the only reader, retired warm in favour of sepia and added Takeaways; its device pass confirmed
search page-jumps but found the highlighter stacking marks it could not then remove. **Build 23's
reworked highlighting is accepted on the phone** — the explicit Highlight / Remove highlight choice,
the search tint, Go to page from a Takeaways passage and the delete confirmation. It also explained
the one mark that would not clear: it was inside the PDF file, not PageVault's. **Build 24 is
downloaded, verified and handed over**: it hides the book's own markup, adds a direct page jump, and
opens the feature that sent a notification. It is not device-tested. This file owns
build and device evidence.

## Current identity and artifact

- Temporarily public source: https://github.com/akshatksingh18/akshatos (renamed with history preserved).
- Local source: `D:\AI Important Files\personal-project\akshatos`.
- XcodeGen target/scheme: `AkshatOS`; display name: **AkshatOS**.
- Bundle ID: `com.akshatksingh18.akshatos`; working source version/build: **0.2.0 (24)**; minimum iOS 17.
  Build 24 is both the working source version and the last artifact produced, so the **next** code
  change bumps to 25 before anything is built from it.
  Every installable artifact gets its own build number, so a build never shares a number while
  carrying different code. Bump `CURRENT_PROJECT_VERSION` in `ios/project.yml` with the first code
  change after a build is handed over, not at build time — that is what keeps this invariant true.
- Workflow: `.github/workflows/ios-build.yml`, macOS 26/Xcode 26.6/XcodeGen 2.46.0.
- Output: `AkshatOS-unsigned.ipa`, checksum and `build-info.txt` in `akshatos-ios-<run>`.
- Content: hub picker → Squats dashboard/core, plus PageVault's library, page-curl reader, page
  themes (paper, sepia, night), reading status, bookmarked place, covers, Started shelf,
  export/restore, pages cropped to their measured text, highlights with their own PDF export, and
  full-text search; ReelVault is a planned card only. Reading streaks shipped in Builds 14–20 and
  were removed in Build 21. Build 22 makes the curl the only reader and retires the warm theme in
  favour of sepia. Build 23 reworks highlighting around an explicit Highlight / Remove highlight
  choice, tints a searched phrase on arrival, reaches a page from a Takeaways passage, and confirms
  before removing one.
- Credentials, profiles, keys, device IDs, Anisette data, and IPAs never enter Git.

The hub is a fresh identity, not an upgrade of the standalone Squat Reminder smoke app (`0.1.0 (1)`,
source `cc9fe46`), which launched once through Sideloadly and was then removed by Akshat. Same-ID data
preservation has been proven once: Build 12 installed over Build 11 without uninstalling kept
settings, permissions, Home configuration and history. Repeated refresh cycles and recovery remain
separate acceptance gates. Never use deletion as the update workflow for data-bearing builds.

## How a build is produced and verified

1. The workflow generates the icon/project and runs `ios/scripts/check-boundaries.py` before compilation.
2. It compiles and runs every registered feature domain suite from `ios/tests/feature-tests.json`.
3. It compiles the simulator build, runs the hosted XCTest and XCUITest suites with screenshot
   attachments, and compiles the unsigned arm64 device Release build. Test runners are not in the IPA.
4. It inspects bundle/version/executable, packages an ordinary Payload IPA, and writes checksum and
   build metadata.
5. Main runs upload a 14-day Actions artifact; PR runs upload none. On Windows: download it, compare
   its SHA-256 with the published checksum, run `ios/scripts/validate-ipa.py`, confirm the packaged
   `CFBundleVersion`, and inspect the screenshots. Temporary Actions storage is not the release cache.

No local Mac is available. Windows edits source; macOS/Xcode in the public GitHub build compiles.
Sideloadly locally signs the downloaded unsigned binary; weekly refresh does not require a rebuild.

## Retained artifacts

Everything below sits under `C:\Users\aksha\Downloads` with its checksum, `build-info.txt` and
screenshots beside the IPA, matched its published SHA-256, passed `validate-ipa.py` and is unsigned.
The kept set is deliberately small: the current build, the last build **confirmed on the phone**, the
build whose reading loop was accepted, and the accepted Squats baseline.

"Last confirmed on the phone" is deliberately not "the previous build number". The point of keeping
one is somewhere to fall back to when a new build misbehaves, and only a build that has actually
installed and run is that. Build 22 was discarded under this rule while Build 21 was kept: 22 was
never installed, and the device pass it did get found its headline feature broken, so it was worth
less as a fallback than the build before it.

Everything else has been cleared out of Downloads: builds 2–4, 9–12, 14–17, 19, 21 and 22, the
PageVault spike artifact, and the old smoke artifact. Builds 14–17, 19, 21 and 22 plus the spike
went to the Recycle Bin during a cleanup and are recoverable until it is emptied; Build 18 was never
downloaded. Build 21 was dropped once Build 23 was accepted on the phone and took over as the
build to fall back to.
Every source is in Git history and what each build found on the phone is under Phone findings below,
which is the part worth keeping. Recovering one means re-running its workflow, not restoring a file.

| Build | Folder | Merge (PR) | Main run | SHA-256 | Status |
|---|---|---|---|---|---|
| 24 | `akshatos-build-24\akshatos-ios-108` | `b53af3e` (#42) | [34709407596](https://github.com/akshatksingh18/akshatos/actions/runs/34709407596) | `10bd5c5fff995fc4f510f706abbcefa895578de645f1fd1111a3e105c9493b18` | Latest handed-over candidate; not device-tested |
| 23 | `akshatos-build-23\akshatos-ios-105` | `98b95cf` (#40) | [34706468115](https://github.com/akshatksingh18/akshatos/actions/runs/34706468115) | `f3160082fb7fab929895d5b18d53e6e7537a499bbdf16a6b4fff8e2d8120a4b6` | Installed; the reworked highlighting accepted on the phone — the rollback target |
| 21 | `akshatos-build-21\akshatos-ios-92` | `6df9b64` (#31) | [34657960237](https://github.com/akshatksingh18/akshatos/actions/runs/34657960237) | `d3ad9cad6b37706b69ed8b26f0bfd4c74584688e6a56ce221c39b8a549665a3b` | Last build confirmed on the phone — the curl and highlights passed; the rollback target |
| 20 | `akshatos-build-20\akshatos-ios-87` | `7415a25` (#29) | [34651471222](https://github.com/akshatksingh18/akshatos/actions/runs/34651471222) | `e4dee1146c552511e60040a13641bc6784c23d4c5c7194f260bed6b8b7273a4d` | Installed; PageVault's reading loop accepted on the phone |
| 13 | `akshatos-build-13\akshatos-ios-58` | `f484f66` (#15) | [34151147604](https://github.com/akshatksingh18/akshatos/actions/runs/34151147604) | `41522db6f8195519e87a8b93064eee60bd344288609db31f2ab64161c73fb1e0` | Accepted Squats daily-use baseline |

Build 22 notes: its packaged `Info.plist` reports build 22, version 0.2.0 and minimum iOS 17.0. The
PageVault library and Takeaways screenshots were inspected; the hub, Squats dashboard and backup sheet
are unchanged by this batch. Install it over Build 21 without uninstalling.

Build 24 notes: its packaged `Info.plist` reports build 24, version 0.2.0 and minimum iOS 17.0, from
merge commit `b53af3e`. Checksum matched and `validate-ipa.py` passed. It adds a direct page jump
from the reader's page indicator, hides text markup the PDF itself carried, and routes a tapped
notification to the feature that sent it. **Install over Build 23 without uninstalling.**

What to check on Build 24, most valuable first:

- **The stuck mark is gone.** Open the book that had it. Marks the PDF itself carried are now hidden,
  so it should simply not be there. Nothing was written to the file, so it is still in the PDF — if
  you want that passage back, highlight it in PageVault and it becomes one you can list and remove.
- **Opening a Squats notification lands on Squats.** Test it from the worst case: have a book open in
  PageVault, then tap a Squats reminder. It should leave the book and show the Squats dashboard.
  Then check the opposite — tapping **Done** on the notification must *not* move you off the page.
  The 9:00 AM invitation should also land on Squats, and still not start a day by itself.
- **Jump to a page.** Tap the "12 / 293" indicator at the bottom of the reader. Drag the slider,
  then type an exact page. Both should agree, out-of-range numbers should be refused, and jumping
  must not move your bookmark.
- **Still unexercised on the phone:** search itself, the highlights PDF export, and the page themes.
  Export and restore stay deliberately untested until the features are finished — Akshat's call.

## Phone findings

Fixtures for PageVault passes come from `../book-reader/make-test-pdfs.py`, which writes them into a
folder of your choosing. They are not kept on disk between passes: the set was 190 MB, almost all of
it one synthetic scan, so it was cleared and is regenerated when a pass needs it. They are synthetic
anyway, so a real scanned book is still needed for a memory verdict.
`../book-reader/CLAUDE.md` owns what these findings mean for PageVault's gates.

- **Build 12** (over Build 11, no uninstall): Done during both the ordinary cadence and a pending nudge
  starts a fresh full interval, the countdown survives background and force-close, buttons no longer
  jump, and all app data survived the update.
- **Build 13:** in ongoing daily use, automatic nudges and the idle 9:00 AM invitation work.
- **Build 14** (over Build 13, no uninstall): the large-PDF gate passed — a 188 MB 120-page scan-like
  PDF, a 600-page text book, outline and outline-less PDFs, corrupt and password-protected rejections,
  duplicate refusal and reader-only landscape — and Squats was unaffected. Reopening a book ignored its
  stored page (a `go(to:)` issued before layout; fixed in 15). Continuous scrolling and the table of
  contents were rejected. No Instruments memory figures were captured.
- **Build 15:** warm paper renders correctly on text pages and paging works. The daily goal was
  unreachable, progress counted swiped pages, and pages sat inside dark letterbox bands; all three
  changed in 16.
- **Build 16:** swiping was fine, but text was too small with a whole page on screen, and pinching out
  shrank it further. Build 17 responded with sampled margin trimming and a zoom floor.
- **After Build 19's handover** (screenshots of a real book): side margins stayed wide and large blank
  bands remained above and below the text. The sampled, one-inch-capped trimming with a fixed paper
  threshold could leave exactly that. Build 20 replaces it with a whole-book measurement that crops
  every page from all four sides.
- **Build 20** (installed over Build 19): text now fills the screen width, reopening a book lands on
  its bookmark, warm paper reads well, and a full-library export produced every book. Akshat then
  asked for reading streaks to be removed altogether, which Build 21 does. Still unconfirmed:
  restoring an export into a library missing those books, reading-data-only restore, and how warm
  paper looks on the image-heavy scan.

- **Build 21** (installed over Build 20): the page curl works, including dragging to select a line to
  highlight under it, and highlights themselves work. Akshat then asked for three changes — undo a
  highlight by tapping the highlighter again, make the curl permanent with no setting, and drop warm
  for sepia — all of which are in Build 22. Search, the themes and the highlights export were not
  tested in this pass.
- **Build 23** (installed over Build 21): the reworked highlighter, the search tint, Go to page from
  a Takeaways passage and the delete confirmation all work — Akshat called the set "perfect". One
  mark remained stuck on a page, absent from the passage list and impossible to clear. It was not
  PageVault's: PageVault writes nothing into the PDF and rebuilds marks from its records on every
  open, so a mark with no record cannot be one of its own. It was inside the PDF file, from wherever
  the book was annotated before import, and re-importing would have brought it back. Build 24 hides
  the book's own text markup instead. The pinch-blocks-paging behaviour was confirmed wanted again.
  Akshat also asked for a direct page jump for long books, and for a tapped Squats notification to
  open Squats rather than leaving PageVault on screen; both are in Build 24.
- **Build 22** (installed over Build 21). What worked: jumping to a page from a search result, and
  **Go to page** in the reader's per-book passage list. A zoomed page refusing to turn until the
  zoom is released is **wanted**, not a defect — Akshat asked for it to stay that way.
  What was broken, and is fixed in source for Build 23:
  - The highlighter stacked marks. Selecting a line that already carried a mark plus a little more
    text produced a second and third mark over the same words, visibly darker where they overlapped,
    and the mark could not be removed by re-tapping the highlighter. Root cause: highlight identity
    compared the captured text instead of the page area covered, so any selection that was not
    character-identical read as a new mark. A mark made on Build 21 therefore could not be removed
    on Build 22 at all, and deleting that passage in Takeaways left its siblings still drawn — which
    is why a highlight appeared to survive its own deletion.
  - Takeaways passages had no way to reach their page; tapping one did nothing.
  - The passage bin deleted with no confirmation, next to Go to page, so a mistap lost a passage.
  Akshat chose the fix: the highlighter now offers Highlight and Remove highlight explicitly rather
  than inferring which is meant, and identity is geometric. `../book-reader/features.md` owns the
  scope and `../book-reader/architecture.md` the mechanism. Search itself, the themes and the
  highlights PDF export were still not tested. Export and restore are deliberately deferred until
  the features are finished.

## Signing and physical acceptance flow

1. Pick the build from Retained artifacts. Build 13 is the Squats baseline; PageVault candidates are
   listed with their status. Keep explicit edge-case and deployment tests separate from accepted
   daily-use evidence.
2. Before signing, recheck `Get-FileHash -Algorithm SHA256 .\AkshatOS-unsigned.ipa` against the
   recorded checksum if the artifact was moved or copied.
3. Start Sideloadly with Local Anisette. If the prior startup timeout recurs, the user-reported
   working sequence was phone disconnected → launch/initialize Sideloadly → reconnect phone.
   This is an observed workaround, not a confirmed root cause or universal fix.
4. Select the connected/unlocked iPhone and `AkshatOS-unsigned.ipa`, use the same intended Apple
   Account, and preserve `com.akshatksingh18.akshatos` across signing attempts. Enter secrets only
   in Sideloadly. Verify actual signed identity before relying on retained data.
5. Complete Apple verification, Developer Mode, and developer trust prompts as required.
6. Open **AkshatOS**: the first screen must be the app picker. Select **Squat Reminder**; test back
   navigation to the hub. ReelVault must clearly say it is not available.
7. Use disposable sessions: set a one-minute interval, start/allow notifications, return to hub,
   lock the phone and receive an alert. Use notification Done, confirm one set in Squats and Undo;
   ignore another normal alert and confirm the dashboard switches to one ten-minute automatic-nudge
   countdown. Background/force-close without moving that deadline, receive the nudge, then verify
   further nudges continue every ten minutes until Done. Done must log one set, cancel the old chain
   and start a fresh full interval; notification Pause must stop the chain until Resume. Confirm the
   notification exposes only Done/Pause and that returning to the picker does not stop reminders.
8. End the day and confirm Settings reports the daily 9:00 AM start reminder scheduled. At the next
   9:00 AM delivery, tap it and verify AkshatOS opens without silently starting a session. Starting a
   day must remove that idle reminder; ending must restore it.
9. Test goal setup, same-day sessions, yesterday unfinished, history, and save-failure handling.
   Record outcomes before calling features phone-verified; full matrix remains in `CLAUDE.md`.

Wi-Fi/automatic refresh, expiry recovery, repeated in-place upgrades and notification buttons still
require physical verification. Home geofence physical verification, Shortcuts and physical recovery
remain unfinished. Keep irreplaceable history disposable until export/restore is exercised on the phone.

## Failure handling

- No device: check unlocked phone, data-capable USB cable/port, trust and official Apple Windows
  components; do not change the IPA to fix detection.
- Failed CI or missing artifact: inspect the failing step; do not sideload an unverified package.
- Hash mismatch: redownload and compare; do not install.
- Signing error: preserve non-secret error text; do not share password, 2FA, session/profile data.
- Launch crash or storage failure: keep the app installed and report iOS version and behavior.
  Never reset/delete its container as a first repair.
- Check official [Sideloadly setup](https://sideloadly.io/faq.html) when installer requirements change.
