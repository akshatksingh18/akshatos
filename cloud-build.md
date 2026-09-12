# AkshatOS cloud build and iPhone installation

**State:** Builds come only from the GitHub Actions macOS workflow and are verified on Windows before
handover. Build 13 is the accepted Squats daily-use baseline, and **Build 20 is installed and accepted
for PageVault's reading loop**: page fitting, bookmark restore, warm paper, paged swiping and a
full-library export all passed on the phone. Build 21 added highlights, search, page themes and the
page curl; the curl and highlights passed on the phone, the rest was not tested. Build 22 is
downloaded, verified and handed over: it turns the highlighter into a toggle, makes the curl the only
reader, retires warm in favour of sepia, and adds Takeaways. This file owns build and device evidence.

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
screenshots beside the IPA, matched its published SHA-256, passed `validate-ipa.py` and is unsigned.
The kept set is deliberately small: the current build, its predecessor, the build whose reading loop
was accepted, and the accepted Squats baseline.

Everything else has been cleared out of Downloads: builds 2–4, 9–12, 14–17 and 19, the PageVault
spike artifact, and the old smoke artifact. Builds 14–17 and 19 plus the spike went to the Recycle
Bin during a cleanup and are recoverable until it is emptied; Build 18 was never downloaded at all.
Every source is in Git history and what each build found on the phone is under Phone findings below,
which is the part worth keeping. Recovering one means re-running its workflow, not restoring a file.

| Build | Folder | Merge (PR) | Main run | SHA-256 | Status |
|---|---|---|---|---|---|
| 22 | `akshatos-build-22\akshatos-ios-96` | `fdc69fc` (#33) | [34666050266](https://github.com/akshatksingh18/akshatos/actions/runs/34666050266) | `a2eb95bb0b7b17acae83e288c2ba29f694cbb2de5be377d76389a3430e376579` | Latest handed-over candidate; not device-tested |
| 21 | `akshatos-build-21\akshatos-ios-92` | `6df9b64` (#31) | [34657960237](https://github.com/akshatksingh18/akshatos/actions/runs/34657960237) | `d3ad9cad6b37706b69ed8b26f0bfd4c74584688e6a56ce221c39b8a549665a3b` | Superseded by 22; the curl and highlights passed on the phone |
| 20 | `akshatos-build-20\akshatos-ios-87` | `7415a25` (#29) | [34651471222](https://github.com/akshatksingh18/akshatos/actions/runs/34651471222) | `e4dee1146c552511e60040a13641bc6784c23d4c5c7194f260bed6b8b7273a4d` | Installed; PageVault's reading loop accepted on the phone |
| 13 | `akshatos-build-13\akshatos-ios-58` | `f484f66` (#15) | [34151147604](https://github.com/akshatksingh18/akshatos/actions/runs/34151147604) | `41522db6f8195519e87a8b93064eee60bd344288609db31f2ab64161c73fb1e0` | Accepted Squats daily-use baseline |

Build 22 notes: its packaged `Info.plist` reports build 22, version 0.2.0 and minimum iOS 17.0. The
PageVault library and Takeaways screenshots were inspected; the hub, Squats dashboard and backup sheet
are unchanged by this batch. Install it over Build 21 without uninstalling.

What to check on the phone, most valuable first:

- **Undoing a highlight.** Select a passage you already highlighted and tap the highlighter: the mark
  should disappear. The same words on another page stay their own highlight.
- **Takeaways.** The library's second button lists every book you have kept lines from, newest first;
  opening one shows its passages as blocks, and Export writes them to a PDF in Files.
- **Jumping.** Tap a search result, and a passage's "Go to page" in the reader's highlights sheet.
  Both must land on the right page — the pager took this over when the old reader was deleted, so it
  is the likeliest thing to be wrong.
- **Remembered zoom.** Pinch, turn a few pages, and confirm the zoom held. Same reason as above.
- **Sepia and night.** Sepia is now the default and warm is gone; a stored warm choice should land on
  sepia rather than resetting. Night should invert the page, not merely dim it.
- **Still unexercised on the phone:** search itself, restoring an export into a library missing those
  books, and the reading-data-only export.

Known cosmetic defect in Build 22: with nothing kept, the Takeaways empty screen sits on pure black
rather than PageVault's dark navy. Visible only in that empty state. Fixed in source afterwards —
PageVault's dark background was attached to the populated branch of each screen, so every empty state
fell through to black, and it now covers both branches of Takeaways and of a book's passage list plus
the missing-copy reader state. Build 22 as handed over still shows it; the next build carries the fix.

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
