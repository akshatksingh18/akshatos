# AkshatOS cloud build and iPhone installation

**State:** Builds come only from the GitHub Actions macOS workflow and are verified on Windows before
handover. Build 13 is the accepted Squats daily-use baseline, and **Build 20 is installed and accepted
for PageVault's reading loop**: page fitting, bookmark restore, warm paper, paged swiping and a
full-library export all passed on the phone. Build 21 removes reading streaks and adds highlights,
full-text search, page themes and an opt-in page curl; it is downloaded, verified and handed over,
and not yet device-tested. This file owns build and device evidence.

## Current identity and artifact

- Temporarily public source: https://github.com/akshatksingh18/akshatos (renamed with history preserved).
- Local source: `D:\AI Important Files\personal-project\akshatos`.
- XcodeGen target/scheme: `AkshatOS`; display name: **AkshatOS**.
- Bundle ID: `com.akshatksingh18.akshatos`; working source version/build: **0.2.0 (21)**; minimum iOS 17.
  Every installable artifact gets its own build number, so a build never shares a number while
  carrying different code.
- Workflow: `.github/workflows/ios-build.yml`, macOS 26/Xcode 26.6/XcodeGen 2.46.0.
- Output: `AkshatOS-unsigned.ipa`, checksum and `build-info.txt` in `akshatos-ios-<run>`.
- Content: hub picker → Squats dashboard/core, plus PageVault's library, page-curl reader, page
  themes (paper, sepia, night), reading status, bookmarked place, covers, Started shelf,
  export/restore, pages cropped to their measured text, highlights with their own PDF export, and
  full-text search; ReelVault is a planned card only. Reading streaks shipped in Builds 14–20 and
  were removed in Build 21. Build 22 makes the curl the only reader, turns the highlighter into a
  toggle so a mistaken highlight can be undone, and retires the warm theme in favour of sepia.
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
screenshots beside the IPA, matched its published SHA-256 and is unsigned. All but the spike also
passed `validate-ipa.py` or the equivalent identity/payload inspection. Earlier builds (2–4 and 9–12)
and the smoke artifact are no longer there; their sources remain in Git history. Build 18
(`akshatos-ios-79`, main run 34538261451, merge `9861f44`, adding the Started shelf) was produced but
never downloaded, because Build 19 superseded it before any device pass.

| Build | Folder | Merge (PR) | Main run | SHA-256 | Status |
|---|---|---|---|---|---|
| 21 | `akshatos-build-21\akshatos-ios-92` | `6df9b64` (#31) | [34657960237](https://github.com/akshatksingh18/akshatos/actions/runs/34657960237) | `d3ad9cad6b37706b69ed8b26f0bfd4c74584688e6a56ce221c39b8a549665a3b` | Latest handed-over candidate; not device-tested |
| 20 | `akshatos-build-20\akshatos-ios-87` | `7415a25` (#29) | [34651471222](https://github.com/akshatksingh18/akshatos/actions/runs/34651471222) | `e4dee1146c552511e60040a13641bc6784c23d4c5c7194f260bed6b8b7273a4d` | Installed; PageVault's reading loop accepted on the phone |
| 19 | `akshatos-build-19\akshatos-ios-82` | `089cc15` (#27) | [34548930454](https://github.com/akshatksingh18/akshatos/actions/runs/34548930454) | `932432e0b8d52895b4837c071cfb6a8023033826c31fe1fb82c2206010ea84c8` | Superseded by 20; not device-tested |
| 17 | `akshatos-build-17\akshatos-ios-76` | `52181f6` (#24) | [34530751880](https://github.com/akshatksingh18/akshatos/actions/runs/34530751880) | `87c1adce1fb91ceab4925d1e89c3411d0a96217c10e1c03f28a394e61be7b96e` | Superseded by 19 |
| 16 | `akshatos-build-16\akshatos-ios-72` | `c1f378f` (#22) | [34524075937](https://github.com/akshatksingh18/akshatos/actions/runs/34524075937) | `3205ae71f7bb93cbbd381daab23ab914fcafbaee521d8fdc361e4dec21899053` | Phone-tested |
| 15 | `akshatos-build-15\akshatos-ios-69` | `e209269` (#20) | [34511400591](https://github.com/akshatksingh18/akshatos/actions/runs/34511400591) | `c90f5c83ceb22f5ed49d153902e01d2991c182316f98492b136aaa9c92266bed` | Phone-tested |
| 14 | `akshatos-build-14\akshatos-ios-66` | `b3ff429` (#18) | [34487510067](https://github.com/akshatksingh18/akshatos/actions/runs/34487510067) | `64a8c7da2ada589fd02a04de46d38d43ca16c7d6a9d54feacd864b2ef8b35af8` | Phone-tested; large-PDF gate passed |
| 13 | `akshatos-build-13\akshatos-ios-58` | `f484f66` (#15) | [34151147604](https://github.com/akshatksingh18/akshatos/actions/runs/34151147604) | `41522db6f8195519e87a8b93064eee60bd344288609db31f2ab64161c73fb1e0` | Accepted Squats daily-use baseline |
| — | `akshatos-pagevault-spike\akshatos-ios-62` | `e353c8d` (#17) | [34430943640](https://github.com/akshatksingh18/akshatos/actions/runs/34430943640) | `e0aa63edf3102a7707d39265b914711976686454956860ca5e3d2c555f372555` | Reports 0.2.0 (13) despite containing PageVault; never install |

Build 21 notes: its packaged `Info.plist` reports build 21, version 0.2.0 and minimum iOS 17.0, and
all four screenshots (hub, Squats dashboard, empty PageVault library, backup sheet) were inspected —
the empty-library "Zero KB" footer is gone. Install it over Build 20 without uninstalling: the
library, bookmarks and page measurements all live in the app container. PageVault's streak card
disappears in this build; that is the removal landing, not data loss. Squats keeps its own goal and
streak, which are untouched.

What to check on the phone, most valuable first:

- **Highlights.** Select a line, tap the highlighter, reopen the book, and confirm the mark is still
  drawn in place. Check that the list (reader menu or book details) jumps to the right page, that
  swiping deletes, and that Export produces a readable PDF of the passages in Files.
- **Search.** From the reader menu, search a word that appears more than once and confirm the results
  land on the right pages. The 188 MB scan should find nothing: it has no text layer, and there is
  no OCR.
- **Themes.** Paper, Sepia and Night from the reader menu. Night should invert the page into
  light text on dark rather than merely dimming it.
- **Page curl and highlights: confirmed on Build 21.** Both worked on the phone, including dragging
  to select a line under the curl. Build 22 therefore makes the curl the only reader, removes its
  setting, and turns the highlighter into a toggle so a mistaken highlight can be undone.
- **Export/restore is still unexercised on the phone.** Use a disposable library first: add two
  fixture PDFs, highlight and bookmark one, export both ways to Files, remove the books, then restore
  and confirm places, statuses, the Started shelf and the highlights all come back. Never make a real
  library the first restore.

## Phone findings

Fixtures for PageVault passes are generated at `C:\Users\aksha\Downloads\pagevault-test-pdfs` by
`../book-reader/make-test-pdfs.py`. They are synthetic, so a real scanned book is still needed for a
memory verdict. `../book-reader/CLAUDE.md` owns what these findings mean for PageVault's gates.

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
