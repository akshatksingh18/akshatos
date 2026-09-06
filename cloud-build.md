# AkshatOS cloud build and iPhone installation

**State:** Build-9 application source `e999ed282392abb0cc0f3f230e794aa79a26c12c` chooses the
eight-set/150-meter defaults, expands regression coverage and fixes missing-next-trigger repair.
Its app-logic parent passed PR #4 run #36; exact build-9 verification is pending after the version/
documentation update. Build-4 remains the latest downloaded, hash-verified IPA and older local
previews are preserved. First AkshatOS physical installation, reminder behavior and refresh
acceptance remain pending. This file owns the build evidence.

Akshat reports that sideloading is working perfectly. Treat the installation workflow as working
for continued development; do not require another baseline installation before finishing code.
No specific new AkshatOS build/feature test or automated-refresh result was supplied with that
report, so it does not close those acceptance gates. Akshat will test the complete native v1 after
implementation and automated checks; the manual steps below are for that acceptance phase.

## Current identity and artifact

- Temporarily public source: https://github.com/akshatksingh18/akshatos (renamed with history preserved).
- Local source: `D:\AI Important Files\personal-project\akshatos`.
- XcodeGen target/scheme: `AkshatOS`; display name: **AkshatOS**.
- Bundle ID: `com.akshatksingh18.akshatos`; current source version/build: **0.2.0 (9)**; minimum iOS 17.
- Workflow: `.github/workflows/ios-build.yml`, macOS 26/Xcode 26.6/XcodeGen 2.46.0.
- Output: `AkshatOS-unsigned.ipa`, checksum and `build-info.txt` in `akshatos-ios-<run>`.
- Content: hub picker → Squats dashboard/core; PageVault/ReelVault are planned cards only.
- Credentials, profiles, keys, device IDs, Anisette data, and IPAs never enter Git.

The hub is a fresh identity, not an in-place upgrade of the former standalone smoke app.
Akshat removed that disposable app after its successful launch. No activity/history feature existed
in it; no migration is implemented. Do not reuse deletion as the workflow for future data-bearing
AkshatOS updates. Same-ID refresh/data preservation is still unverified.

## Cloud validation and delivery

Build-9 application source `e999ed282392abb0cc0f3f230e794aa79a26c12c` selects a configurable
eight-set daily goal and 150-meter Home radius, expands the registered suite to 47 domain assertions,
55 integration/persistence tests and one UI test, and fixes repair of a repeating request without a
next fire date. The app-logic parent passed
[PR #4 run #36](https://github.com/akshatksingh18/akshatos/actions/runs/34002015676), including both
builds and IPA inspection; exact build-9 verification is pending.

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

### Selected build-4 download

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

Verified extracted download: `C:\Users\aksha\Downloads\akshatos-module-boundaries\akshatos-ios-6`.
`AkshatOS-unsigned.ipa` SHA-256:
`add44c15fc4a7ba03b0b0f3bc0f6bf524da5ecac4879ab4d3f3248253eae3631`.
The local hash matches the cloud checksum. Keep the IPA, checksum and `build-info.txt` together.
Screenshots are in its `screenshots/` directory. No durable release-cache promotion or signing
has been performed for this preview.
The prior build-2 preview remains in `C:\Users\aksha\Downloads\akshatos-ios-5` as a previous
artifact; it was not deleted or relabeled. This refactor preserves the schema, store name, keys,
and bundle ID. Physical same-ID upgrade/data preservation and reminders still need testing.

1. The workflow generates the icon/project and runs `ios/scripts/check-boundaries.py` before compilation.
2. Compile/run registered domain sources and `ios/tests/squats/main.swift` (20 assertions).
3. Compile simulator, run the hub → dashboard → back UI test with screenshot attachments, and
   compile the unsigned arm64 device Release build. Simulator test runners are not in the IPA.
4. Inspect bundle/version/executable, package ordinary Payload IPA, generate checksum/build metadata.
5. Upload a 14-day Actions artifact. Download and checksum it before signing. Keep a durable copy
   outside Git after physical acceptance; temporary Actions storage is not the release cache.

No local Mac is available. Windows edits source; macOS/Xcode in the public GitHub build compiles.
Sideloadly locally signs the downloaded unsigned binary; weekly refresh does not require a rebuild.

## First AkshatOS install (manual steps; no computer control)

1. Use the selected **AkshatOS 0.2.0 (4)** download above, not an older preview or smoke download; download a newer
   successful artifact only when its source/build is intentionally selected.
2. Verify `Get-FileHash -Algorithm SHA256 .\AkshatOS-unsigned.ipa` against its checksum file.
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
   test notification Pause, dashboard Resume, expanded-notification ten-minute snooze, End, and
   relaunch. Repeat with 45 minutes. Confirm action ordering and that returning to the picker does
   not stop reminders. A build-3 schedule may need one explicit Repair reminders to add the category.
8. Test goal setup, same-day sessions, yesterday unfinished, history, and save-failure handling.
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

The verified extracted files are kept together at
`C:\Users\aksha\Downloads\squat-reminder-ios-3`; redundant downloaded ZIPs have been removed. Keep
the IPA, its checksum, and `build-info.txt` together as the verified smoke artifact; do not delete
the download before a stable cache copy is chosen and verified.



## Failure handling

- No device: check unlocked phone, data-capable USB cable/port, trust and official Apple Windows
  components; do not change the IPA to fix detection.
- Failed CI or missing artifact: inspect the failing step; do not sideload an unverified package.
- Hash mismatch: redownload and compare; do not install.
- Signing error: preserve non-secret error text; do not share password, 2FA, session/profile data.
- Launch crash or storage failure: keep the app installed and report iOS version and behavior.
  Never reset/delete its container as a first repair.
- Check official [Sideloadly setup](https://sideloadly.io/faq.html) when installer requirements change.
