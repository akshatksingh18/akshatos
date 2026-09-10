# AkshatOS cloud build and iPhone installation

**State:** Build 10 makes a pending ten-minute deadline the single main countdown, keeps **Your day
so far** completion-only and persists the regular cadence anchor. PR #7 passed the full gate and merged as
`e99b7aa0ab2eaa71a583e6abfd42937c4d1d1cd9`. Its
[main delivery run #43](https://github.com/akshatksingh18/akshatos/actions/runs/34057258895)
passed 49 domain assertions, 58 XCTest cases, the UI test, simulator/device compilation, IPA
inspection and `CI Gate`, then uploaded Build 10. The downloaded IPA matches its published checksum
and package identity, and both simulator screenshots were inspected. Akshat installed it after
uninstalling Build 9; phone testing found the snooze clock resets on foreground and Done leaves that
nudge active. Build 11 persists the snooze deadline and resets to a full interval on snooze-related
Done. PR #10 merged as `8b5b8c4c8cba5ef251abe90938fa000f8b4c5f24`; main delivery run #49
passed the complete pipeline and uploaded `akshatos-ios-49`. Its downloaded IPA matches the published
checksum and passed local identity/payload inspection; both screenshots were inspected. Builds 9 and
4 remain retained fallbacks.
Build 12 application source `c5f787efb628cf63531c57e4cf9478edf5d8731b` adds universal running-Done
cadence reset and stable button-state geometry. [PR #12 run #34073932922](https://github.com/akshatksingh18/akshatos/actions/runs/34073932922)
passed 49 domain assertions, 63 integration/persistence tests, one UI test, simulator/device builds,
IPA inspection and `CI Gate`; as intended, the PR uploaded no IPA. PR #12 merged as
`061272f3781b091360ae47cd4ac2bed983c73ef3`; [main delivery run #53](https://github.com/akshatksingh18/akshatos/actions/runs/34074441041)
repeated the complete gate and uploaded `akshatos-ios-53`. Its downloaded IPA matches the cloud
checksum, passed local identity/payload inspection, and both screenshots were visually inspected.
Build 13 application source `94d186b189859363a8ddce7abe963b46deab9175` adds bounded automatic
ten-minute nudges and the idle 9:00 AM start invitation. PR #15 run #57 passed the complete gate and
uploaded no IPA as intended. PR #15 merged as `f484f663647a2be0cad44f3bb1c7fe2671b6572d`;
[main delivery run #58](https://github.com/akshatksingh18/akshatos/actions/runs/34151147604)
passed the complete gate and uploaded `akshatos-ios-58`. The downloaded Build-13 IPA matches SHA-256
`41522db6f8195519e87a8b93064eee60bd344288609db31f2ab64161c73fb1e0`, passed local identity/
metadata/payload validation, and both screenshots were visually inspected. Akshat installed Build 13
and reports that its implemented workflow—including automatic nudges and idle-start behavior—works
well in ongoing phone use. The broader physical edge-case and refresh/recovery matrix remains open.
This file owns the build evidence.

Akshat reports that sideloading and installed Build 13 are working well in ongoing use. Treat the
installation workflow and implemented Build-13 daily behavior as accepted for continued development;
do not require another baseline installation before finishing code. This report does not by itself
close unreported edge-case, automated-refresh, expiry-recovery or multi-cycle soak gates.

## Current identity and artifact

- Temporarily public source: https://github.com/akshatksingh18/akshatos (renamed with history preserved).
- Local source: `D:\AI Important Files\personal-project\akshatos`.
- XcodeGen target/scheme: `AkshatOS`; display name: **AkshatOS**.
- Bundle ID: `com.akshatksingh18.akshatos`; working source version/build: **0.2.0 (15)**; minimum iOS 17.
  Every installable artifact gets its own build number, so a build never shares a number while
  carrying different code. Build 13 is the installed Squats-only build; 14 added PageVault and was
  physically tested; 15 carries the reader redesign that followed.
  Build 13 is installed and accepted for its implemented daily workflow, including automatic nudges
  and idle-start behavior. Build 12 is the retained accepted predecessor; Build 11 remains an older fallback.
- Workflow: `.github/workflows/ios-build.yml`, macOS 26/Xcode 26.6/XcodeGen 2.46.0.
- Output: `AkshatOS-unsigned.ipa`, checksum and `build-info.txt` in `akshatos-ios-<run>`.
- Content: hub picker → Squats dashboard/core, plus PageVault's library, paged reader, warm paper,
  reading status, daily-goal streak, bookmarked place and cover cache; ReelVault is a planned card
  only. Build 14's import and large-PDF reading passed on the phone; the reader redesign in build 15
  has not been device-tested.
- Credentials, profiles, keys, device IDs, Anisette data, and IPAs never enter Git.

The hub is a fresh identity, not an in-place upgrade of the former standalone smoke app.
Akshat removed that disposable app after its successful launch. No activity/history feature existed
in it; no migration is implemented. Do not reuse deletion as the workflow for future data-bearing
  AkshatOS updates. Build 10 was also installed after uninstalling Build 9, so same-ID refresh/data
  preservation was subsequently proven by installing Build 12 over Build 11 without deleting the
  app; repeated refresh cycles and recovery remain separate acceptance gates.

## Cloud validation and delivery

Build-10 source `f7fa520` added three integration regressions for persisted cadence across
foreground/relaunch, one-time Build-9 session migration, snooze countdown priority and completion-
only dashboard history. [PR #7 run](https://github.com/akshatksingh18/akshatos/actions/runs/34056727988)
passed 49 domain assertions, 58 integration/persistence tests, one UI test, both builds, IPA
inspection and `CI Gate`. Main delivery run #43 repeated that complete pipeline for merge commit
`e99b7aa0ab2eaa71a583e6abfd42937c4d1d1cd9` and uploaded `akshatos-ios-43`.

Build-11 application source `9586f8af537108bb1c11024bad63eb2f85a9d94c` adds a stable persisted
snooze deadline, conditional Done cadence reset, real SwiftData disk recreation and reset failure/
retry coverage. [PR #10 run #34067380053](https://github.com/akshatksingh18/akshatos/actions/runs/34067380053)
passed 49 domain assertions, 61 integration/persistence tests, one UI test, simulator/device builds,
IPA inspection and `CI Gate`. The PR correctly uploaded no IPA. PR #10 merged as
`8b5b8c4c8cba5ef251abe90938fa000f8b4c5f24`; [main delivery run #49](https://github.com/akshatksingh18/akshatos/actions/runs/34068524652)
repeated the full passing pipeline and uploaded `akshatos-ios-49`.

Build-12 application source `c5f787efb628cf63531c57e4cf9478edf5d8731b` adds universal running-Done
cadence reset, retry coverage for replacement scheduling, and stable dashboard action geometry.
[PR #12 run #34073932922](https://github.com/akshatksingh18/akshatos/actions/runs/34073932922)
passed 49 domain assertions, 63 integration/persistence tests, one UI test, simulator/device builds,
IPA inspection and `CI Gate`. The PR correctly uploaded no IPA. PR #12 merged as
`061272f3781b091360ae47cd4ac2bed983c73ef3`; [main delivery run #53](https://github.com/akshatksingh18/akshatos/actions/runs/34074441041)
repeated the complete passing pipeline and uploaded `akshatos-ios-53`.

Build-13 application source `94d186b189859363a8ddce7abe963b46deab9175` adds one normal reminder
followed by 59 automatic ten-minute nudges, bounded foreground refill/migration, a two-action
Done/Pause category, and an idle-only repeating 9:00 AM start invitation. After an initial red run
exposed eight stale fixture/expectation assertions (with compilation and UI already passing),
[PR #15 run #57](https://github.com/akshatksingh18/akshatos/actions/runs/34150335957)
passed 49 domain assertions, 63 integration/persistence tests, five SwiftData tests, one UI test,
simulator/device builds, IPA inspection and `CI Gate`. PR #15 merged as
`f484f663647a2be0cad44f3bb1c7fe2671b6572d`; main delivery run #58 repeated the full passing pipeline
and uploaded `akshatos-ios-58`.

Build-9 application source `e999ed282392abb0cc0f3f230e794aa79a26c12c` selects a configurable
eight-set daily goal and 150-meter Home radius, expands the registered suite to 47 domain assertions,
55 integration/persistence tests and one UI test, and fixes repair of a repeating request without a
next fire date. The app-logic parent passed
[PR #4 run #36](https://github.com/akshatksingh18/akshatos/actions/runs/34002015676), including both
builds and IPA inspection. The exact source/documentation head `b11623e` passed the same checks in
the [rerun of PR #4 run #37](https://github.com/akshatksingh18/akshatos/actions/runs/34002685377);
as a PR run, it did not upload an IPA artifact.
[Main delivery run #39](https://github.com/akshatksingh18/akshatos/actions/runs/34042431950)
then passed the complete pipeline on merge commit `87003204292dec58210432479a3522abc2cc6bf7`
and uploaded `akshatos-ios-39`.

Foreground-reconciliation source `8c1cc96469ea6f74fe81e60de1690064181bbac2` repairs invalid idle
preferences, validates the active recurring request and current-session snooze, removes stale
snoozes, and compares/replaces the actual monitored Home circle while resetting stale presence.
[PR #1 run #32](https://github.com/akshatksingh18/akshatos/actions/runs/33999479820) passed 20-source
boundary checks, 37 domain assertions, 45 integration/persistence tests, one hub/settings UI test,
simulator/device compilation, IPA inspection and `CI Gate`. The PR run did not upload an IPA. PR #1
merged the source to `main` as `1996004ea56353f53ef1bccde4366b2741e9f099`.
[Main delivery run #33](https://github.com/akshatksingh18/akshatos/actions/runs/34000405465)
then passed the same complete pipeline for that merge commit and uploaded the unexpired
`akshatos-ios-33` artifact. That artifact has not been downloaded or hash-verified locally, so it
does not replace build 4 as the selected local preview.

Post-review correction source `d80653da39433815c1d12fb9470adb9417a6f819` decouples remembered
notification grants from alert availability, counts both When In Use and Always as prior location
authorization, proves both flags survive store recreation and drive revoked wording, and marks the
protected Home configuration/event files and directory as excluded from device backup. It also adds
docs-only PR classification while keeping `CI Gate` present. It passed
[PR #1 run #27](https://github.com/akshatksingh18/akshatos/actions/runs/33985917032): 20-source
boundary checks, 37 domain assertions, 41 integration/persistence tests, one hub/settings UI test,
simulator/device compilation, IPA inspection and CI Gate. The PR run did not upload an IPA.
Final classifier/documentation source `d3864970a2beb2ebcc463bf73fca0574542ca942` then passed
[PR #1 run #28](https://github.com/akshatksingh18/akshatos/actions/runs/33986900743), including the
full macOS job because that update changed the workflow. Application source remained `d80653d`.
The subsequent Markdown-only source `931d3a568d5540167dbf9734020a1715a3cd3420` passed Source
checks and the required `CI Gate` in
[PR #1 run #29](https://github.com/akshatksingh18/akshatos/actions/runs/33987404033) while `Build
installable IPA` was skipped, proving the required check still resolves without spending macOS
minutes on a documentation-only PR update.

Build 8 closes three gaps found in a follow-up review of the build-7 dashboard/Settings UI task: a
monotonic `notificationEverAuthorized`/`homeEverAuthorized` flag so a permission that was granted at
least once and later denied is phrased as a revocation rather than a first-time denial, an icon-based
Home automation-health row on the main dashboard itself (previously a plain muted line), and a shared
`AdaptiveRow` component that stacks label/value rows vertically at accessibility Dynamic Type sizes.
Exact source `81bc36b58814c69e174013219d577ad5a4699f4d` passed
[PR #1 run #24](https://github.com/akshatksingh18/akshatos/actions/runs/33981449101) on its first
push: 20-source boundary checks, 37 domain assertions, 41 integration/persistence tests, one
hub/settings UI test, simulator/device compilation, IPA inspection and CI Gate. PR runs do not
upload IPA artifacts, so build 4 below remains the latest downloaded IPA; this work is phone-unverified.

Build 7 completes the dashboard/Settings UI: authoritative `NotificationAuthorization` and
`HomeAuthorization` tracking on `SquatStore` (replacing a boolean and fragile status-string
matching), a `SettingsRoute`-driven one-tap action on blocking alerts, a dedicated Notifications
settings section with Focus/Scheduled Summary/banner caveats, distinct denied/restricted/when-in-use
Home messaging, per-state hero icons, and VoiceOver/Dynamic Type/Reduce Motion/Increased-Contrast
accessibility behavior. Exact source `995e11fd64e074eb7810f0ab1b8acfe47eee9866` passed
[PR #1 run #22](https://github.com/akshatksingh18/akshatos/actions/runs/33979169339): 20-source
boundary checks, 37 domain assertions, 39 integration/persistence tests, one hub/settings UI test,
simulator/device compilation, IPA inspection and CI Gate. PR runs do not upload IPA artifacts, so
build 4 below remains the latest downloaded IPA; this UI/permission work is phone-unverified.

Build 6 adds staged opt-in Home selection and Always authorization, one app-lifetime circular region,
protected boundary/event storage, source-aware pause/resume and outside-Home choices, automation
health/edit/delete UI, future-date streak filtering and expanded goal/streak/Home regression tests.
It intentionally omits continuous background-location mode and excludes Home coordinates from backup
exports. Exact source `3037348257938dcd545838a7b54d5bd53dafccd1` passed
[PR #1 run #18](https://github.com/akshatksingh18/akshatos/actions/runs/33972978593): 20-source
boundary checks, 37 domain assertions, 34 integration/persistence tests, one hub/settings UI test,
simulator/device compilation, IPA inspection and CI Gate. PR runs do not upload IPA artifacts, and
the Home geofence remains phone-unverified.

Build 5 adds daily aggregation/history, active/paused timing, foreground calendar-boundary rollover,
versioned JSON export/validated restore, completed-history deletion, and regression coverage. Its
exact source `2ac71a10731a73012a4726bbada4d3609fea93cf` passed
[PR #1 run #14](https://github.com/akshatksingh18/akshatos/actions/runs/33906715819): 16-source
boundary checks, 29 domain assertions, 29 integration/persistence tests, one hub/settings UI test,
simulator/device compilation, IPA inspection and CI Gate. PR runs do not upload IPA artifacts, so
build 4 below remains the latest downloaded IPA; do not attribute build-5 behavior to that artifact.

Build 4 adds notification actions, durable queued commands, receipt persistence and regression tests.
Source `3cfea6176d43e79b8af899b579e0ac602b480715` passed all jobs including `CI Gate` in
[PR #1 run #10](https://github.com/akshatksingh18/akshatos/actions/runs/33897588498): 14-source boundary
checks and six negative fixtures, workflow/inventory checks, 20 domain assertions, 24 integration
tests, one hub/settings UI test, simulator/device compilation and IPA payload inspection.
These changes are included in [PR #1](https://github.com/akshatksingh18/akshatos/pull/1), now merged
into `main`.

PR runs intentionally omit IPA upload. The same application source, on documentation revision
`ede1e492bedf8bfbc8c76fb938a3a0676aa97b32`, passed both
[PR run #11](https://github.com/akshatksingh18/akshatos/actions/runs/33898795994) and
[delivery run #12](https://github.com/akshatksingh18/akshatos/actions/runs/33899343678), including `CI Gate`.
The latter published the downloaded artifact below. No build-4 signing, installation or durable
release-cache promotion has occurred. Test Done/Pause/snooze from expanded and compact
notifications while locked and at the hub, duplicate/Undo behavior, relaunch, queued-action recovery,
and updating an old category-less schedule through Repair reminders. None has phone evidence yet.

### Downloaded Build-15 candidate — paged reader, warm paper, bookmarked place

- Version **0.2.0 (15)**; merge source `e209269967e51762324e8011cbe1b0f780271765` (PR #20).
- Artifact `akshatos-ios-69` from main delivery run
  [34511400591](https://github.com/akshatksingh18/akshatos/actions/runs/34511400591): 79 PageVault
  domain assertions, 85 hosted tests, both builds, IPA inspection and `CI Gate` all passed.
- Cached at `C:\Users\aksha\Downloads\akshatos-build-15\akshatos-ios-69`.
- SHA-256 `c90f5c83ceb22f5ed49d153902e01d2991c182316f98492b136aaa9c92266bed` matches the cloud
  checksum. `validate-ipa.py` passed: structure, identity, metadata and payload.
- Fixes the build-14 defect where reopening a book erased its stored position, replaces continuous
  scrolling with single-page horizontal paging, adds warm paper on by default, makes the bookmark
  the only thing that moves your place, and removes the table-of-contents navigator.
- **Unsigned and not phone-verified.** Install over Build 14 without uninstalling so the existing
  PageVault library and Squats data stay testable. The decisive check is: bookmark a page, browse
  elsewhere, close the app, reopen — it must land on the bookmark and the library bar must not move.

### Build-14 physical test result — large-PDF gate passed

Akshat installed Build 14 over Build 13 without uninstalling and ran the fixture set. Squats was
unaffected: dashboard, settings, history and reminders all intact after the orientation change.

Passed: a 188 MB 120-page scan-like PDF imported and read with all pages loading; a 600-page text
book, a 180-page three-level outline and a 40-page outline-less PDF; corrupt and password-protected
files each rejected with a clear message and no library entry; re-importing an existing book
refused; reader landscape with the rest of the hub staying portrait.

Failed: reopening a book ignored the stored page and started from the beginning. Root cause was a
`go(to:)` issued before PDFKit laid the document out, whose loss then let the debounced write
persist page one over the saved position. Fixed in build 15, unverified on device.

Rejected in use: continuous vertical scrolling (showed two half pages, did not read like a book) and
the table-of-contents navigator (unwanted). Build 15 replaces the former with single-page horizontal
paging plus warm paper, and removes the latter. `../book-reader/features.md` owns that scope change.

No Instruments memory figures were captured, so memory behavior is an observation rather than a
measurement.

### Downloaded Build-14 candidate — PageVault v1 reading loop

- Version **0.2.0 (14)**; merge source `b3ff429be98042b2f99728e7ef95ec7e3022457a` (PR #18).
- Artifact `akshatos-ios-66` from main delivery run
  [34487510067](https://github.com/akshatksingh18/akshatos/actions/runs/34487510067), which passed
  Source checks, 80 PageVault plus 47 Squats domain assertions, 86 hosted tests, both builds, IPA
  inspection and `CI Gate`.
- Cached at `C:\Users\aksha\Downloads\akshatos-build-14\akshatos-ios-66`.
- SHA-256 `64a8c7da2ada589fd02a04de46d38d43ca16c7d6a9d54feacd864b2ef8b35af8` matches the cloud
  checksum. `validate-ipa.py` passed: structure, identity, metadata and payload.
- Contains PageVault's library, reader, reading status, daily-goal streak, bookmarks and covers.
  Adds app-wide landscape support gated to the reader by `OrientationGate`, so the Squats dashboard
  must be re-checked for portrait layout after install.
- **Not yet signed, installed or phone-verified.** Install over Build 13 without uninstalling so
  Squats data preservation stays testable. Build 13 remains the installed accepted build until this
  one passes on the phone.
- Test fixtures for the physical pass are generated locally at
  `C:\Users\aksha\Downloads\pagevault-test-pdfs` (600-page text, 180-page three-level outline,
  40-page outline-less, 188 MB scan-like, password-protected, truncated/corrupt). They are synthetic
  structural fixtures; a real scanned book is still required for the memory-pressure verdict.

### Downloaded Build-13-numbered PageVault spike artifact

- Artifact `akshatos-ios-62` from main delivery run
  [34430943640](https://github.com/akshatksingh18/akshatos/actions/runs/34430943640), merge source
  `e353c8d28edb6e08021f499b970ccb0dbcf78ba5` (PR #17).
- Cached at `C:\Users\aksha\Downloads\akshatos-pagevault-spike\akshatos-ios-62`.
- SHA-256 `e0aa63edf3102a7707d39265b914711976686454956860ca5e3d2c555f372555` matches the cloud
  checksum; `build-info.txt` confirms the hub bundle ID, Xcode 26.6 and XcodeGen 2.46.0.
- It reports version **0.2.0 (13)**, the same number as the installed Squats build despite containing
  PageVault. That is why source moved to build 14. **Do not install this artifact**: prefer a
  build-14 artifact so installed builds stay distinguishable.
- Not signed, not installed, and not phone-verified. Its UI-test screenshot of the empty PageVault
  library was visually inspected.

### Installed and accepted Build-13 current build

- Version: **0.2.0 (13)**; merge source `f484f663647a2be0cad44f3bb1c7fe2671b6572d`.
- Artifact: `akshatos-ios-58`, from main delivery run #58 linked above.
- Verified local directory:
  `C:\Users\aksha\Downloads\akshatos-build-13\akshatos-ios-58`.
- File: `AkshatOS-unsigned.ipa`; keep its checksum, `build-info.txt` and screenshots together.
- SHA-256: `41522db6f8195519e87a8b93064eee60bd344288609db31f2ab64161c73fb1e0`.
- The local checksum matches the cloud checksum. ZIP payload, bundle ID, version/build, executable,
  minimum iOS 17 and absence of test bundles, extensions and provisioning profiles were verified;
  both exported simulator screenshots were visually inspected without clipping or malformed layout.
  Akshat installed this build and reports that its implemented phone workflow, including automatic
  nudges and idle-start behavior, works well in ongoing use. The exact install-over-versus-clean-install
  path was not reported. Build 12 remains the retained accepted predecessor.

### Installed and accepted Build-12 predecessor

- Version: **0.2.0 (12)**; merge source `061272f3781b091360ae47cd4ac2bed983c73ef3`.
- Artifact: `akshatos-ios-53`, from main delivery run #53 linked above.
- Verified local directory:
  `C:\Users\aksha\Downloads\akshatos-build-12\akshatos-ios-53`.
- File: `AkshatOS-unsigned.ipa`; keep its checksum, `build-info.txt` and screenshots together.
- SHA-256: `ce0a2750244a5b31d9047494ec40cf3c7adc45f4e705049c7807eba6b8c6fae3`.
- The local checksum matches the cloud checksum. ZIP payload, bundle ID, version/build, executable,
  minimum iOS 17 and absence of test bundles, extensions and provisioning profiles were verified;
  both exported simulator screenshots were visually inspected without clipping or malformed layout.
  Akshat installed this artifact over Build 11 without uninstalling. Phone testing confirms ordinary
  and snoozed Done start a fresh full interval, the countdown persists across background/force-close,
  button interactions no longer jump vertically, and settings, permissions, Home configuration and
  history survived the same-ID update.

### Phone-installed Build-11 predecessor

- Version: **0.2.0 (11)**; merge source `8b5b8c4c8cba5ef251abe90938fa000f8b4c5f24`.
- Artifact: `akshatos-ios-49`, from main delivery run #49 linked above.
- Verified local directory:
  `C:\Users\aksha\Downloads\akshatos-build-11\akshatos-ios-49`.
- File: `AkshatOS-unsigned.ipa`; keep its checksum, `build-info.txt` and screenshots together.
- SHA-256: `8234d5b8eaa86b4836771e4eae1f2f788f59276fdb455ccc63d3e84b239fae67`.
- The local checksum matches the cloud checksum. ZIP payload, bundle ID, version/build, executable,
  minimum iOS 17 and absence of test bundles, extensions and provisioning profiles were verified;
  both exported simulator screenshots were visually inspected. Phone testing confirms its displayed
  countdown survives leaving and closing the app. Build 12 supersedes it as the installed build.

### Installed Build-10 predecessor

- Version: **0.2.0 (10)**; merge source `e99b7aa0ab2eaa71a583e6abfd42937c4d1d1cd9`.
- Artifact: `akshatos-ios-43`, from main delivery run #43 linked above.
- Verified local directory:
  `C:\Users\aksha\Downloads\akshatos-build-10\akshatos-ios-43`.
- File: `AkshatOS-unsigned.ipa`; keep its checksum, `build-info.txt` and screenshots together.
- SHA-256: `ac727b95d8fa2ee9e1228a4de6cca194471cc626191a1576247ec7088d0ac216`.
- The local checksum matches the cloud checksum. ZIP payload, bundle ID, version/build, executable,
  minimum iOS 17 and absence of test bundles, extensions and provisioning profiles were verified;
  both exported simulator screenshots were visually inspected. Akshat installed this candidate after
  uninstalling Build 9; its snooze defects keep it from becoming the known-good release. The retained
  Build-9 artifact remains an immediate fallback.

### Retained Build-4 fallback

- Version: **0.2.0 (4)**; source `ede1e492bedf8bfbc8c76fb938a3a0676aa97b32`.
- Artifact: `akshatos-ios-12`, from delivery run #12 linked above.
- Verified local directory:
  `C:\Users\aksha\Downloads\akshatos-notification-actions\akshatos-ios-12`.
- File: `AkshatOS-unsigned.ipa`; keep `AkshatOS-unsigned.ipa.sha256` and `build-info.txt` beside it.
- SHA-256: `154677be1c5b70b68cbf3a0b7e5a218409a974ffa006b4d70d7160049d40b114`.
- Local checksum matches the cloud checksum; ZIP integrity, payload, permanent bundle ID,
  version/build and absence of shipped tests/extensions/signing profile are checked. This is an
  unsigned preview for manual Sideloadly testing, not a phone-verified or signing-refresh release.

### Earlier preview evidence

The prior expanded pipeline in `ci.md` passed on source `a31643b2375abcd3e708ca3747c9980b1a3e78b8`,
[run #7](https://github.com/akshatksingh18/akshatos/actions/runs/33820332042): source/workflow checks,
12 domain assertions, three SwiftData tests, hub/settings navigation, simulator/device builds,
IPA inspection and `CI Gate`. It originally produced `akshatos-ios-7` and `test-diagnostics-7-1`;
those and all other retained Actions artifacts were deleted before the repository became public.
That IPA was not downloaded or physically tested; the verified local download below remains run #6.
No production app behavior or version changed in this CI-only task.

Verified preview: **0.2.0 (3)**, [iOS Cloud Build #6](https://github.com/akshatksingh18/akshatos/actions/runs/33818156350),
source `e70740d3af51e5bad288787c99f3a1430103c88e`, artifact `akshatos-ios-6`.
Boundary checks over 11 Swift sources and six negative fixtures, all 12 domain assertions, and
picker → dashboard → back → reopen UI test passed; planned media entries have no navigation buttons.
Both exported simulator
screenshots were visually inspected; this is not physical-phone evidence. Simulator compilation,
unsigned device Release build and IPA packaging passed. The downloaded package contains
`Payload/AkshatOS.app` with the app executable/plist, without a test runner, extension or profile.

The locally verified Build-3 and Build-2 previews were superseded by Builds 4 and 9 and sent to the
Windows Recycle Bin together with their checksum/build metadata. They are recoverable until the bin
is emptied and remain reproducible from Git history. One physical same-ID upgrade with data
preservation and the Build-12 cadence fixes passed; broader reminders, refresh/recovery and soak
edge-case testing remains. Build 13 is now the installed daily-use baseline.

1. The workflow generates the icon/project and runs `ios/scripts/check-boundaries.py` before compilation.
2. Compile/run registered domain sources and `ios/tests/squats/main.swift` (49 assertions).
3. Compile simulator, run the hub → dashboard → back UI test with screenshot attachments, and
   compile the unsigned arm64 device Release build. Simulator test runners are not in the IPA.
4. Inspect bundle/version/executable, package ordinary Payload IPA, generate checksum/build metadata.
5. Upload a 14-day Actions artifact. Download and checksum it before signing. Keep a durable copy
   outside Git after physical acceptance; temporary Actions storage is not the release cache.

No local Mac is available. Windows edits source; macOS/Xcode in the public GitHub build compiles.
Sideloadly locally signs the downloaded unsigned binary; weekly refresh does not require a rebuild.

## Remaining physical acceptance and future replacement flow

1. Build 13 has passed its exact-source `CI Gate`, download, checksum, package identity, screenshot
   checks and reported ongoing phone use. Keep the remaining explicit edge-case and deployment tests
   below separate from that accepted daily-use evidence.
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
   navigation to the hub. Other modules must clearly say they are not available.
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

Wi-Fi/automatic refresh, expiry recovery, in-place upgrades and notification buttons still require
physical verification. Home geofence physical verification, Shortcuts and physical recovery remain unfinished. Keep
irreplaceable history disposable until export/restore is exercised on the phone.

## Previous standalone smoke evidence

The earlier standalone **Squat Reminder 0.1.0 (1)** passed cloud compilation/package/hash and
Sideloadly installation/launch, confirmed by Akshat's screenshot. It was then deleted from the
phone by Akshat, who disconnected USB. Its Downloads files and Sideloadly enrollment/cache were
not reported removed; do not assume either state. Exact profile/expiry metadata was not inspected.

Historical smoke artifact (not AkshatOS):

- source commit: `cc9fe467f6088205b51958c9dea28217ae42a6fe`;
- successful workflow: **iOS Cloud Build #3** with no annotations;
- GitHub artifact: `squat-reminder-ios-3`;
- downloaded ZIP SHA-256: `ad659e00a7556018df9ff1345bb21d2d53d3438405d4b275a3baad3981d3e8f3`;
- unsigned IPA SHA-256: `fab363737fdd48d95872138ddde3ae7028fcdbaef89f276a19dbbd7caf997f07`.

This old artifact passed the physical smoke open test. It is not a functional product release;
promotion to a stable local release cache remains pending.

The obsolete standalone artifact folder was sent to the Windows Recycle Bin after Build 9 became
the checksum-verified AkshatOS candidate. It is recoverable until the bin is emptied and its source
remains in Git history; it is not part of the current/fallback AkshatOS pair.



## Failure handling

- No device: check unlocked phone, data-capable USB cable/port, trust and official Apple Windows
  components; do not change the IPA to fix detection.
- Failed CI or missing artifact: inspect the failing step; do not sideload an unverified package.
- Hash mismatch: redownload and compare; do not install.
- Signing error: preserve non-secret error text; do not share password, 2FA, session/profile data.
- Launch crash or storage failure: keep the app installed and report iOS version and behavior.
  Never reset/delete its container as a first repair.
- Check official [Sideloadly setup](https://sideloadly.io/faq.html) when installer requirements change.
