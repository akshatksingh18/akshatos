# AkshatOS cloud build and iPhone installation

**State:** Build-4 notification actions passed PR cloud checks, domain/integration/UI tests,
simulator/device compilation and package inspection. The downloaded build-3 preview remains the
hash-verified local artifact; PR runs do not upload a new IPA. First AkshatOS physical installation,
reminder behavior and refresh acceptance remain pending. This file owns the build evidence.

## Current identity and artifact

- Private source: https://github.com/akshatksingh18/akshatos (renamed with history preserved).
- Local source: `D:\AI Important Files\personal-project\akshatos`.
- XcodeGen target/scheme: `AkshatOS`; display name: **AkshatOS**.
- Bundle ID: `com.akshatksingh18.akshatos`; source version/build: **0.2.0 (4)**; minimum iOS 17.
- Workflow: `.github/workflows/ios-build.yml`, macOS 26/Xcode 26.6/XcodeGen 2.46.0.
- Output: `AkshatOS-unsigned.ipa`, checksum and `build-info.txt` in `akshatos-ios-<run>`.
- Content: hub picker → Squats dashboard/core; PageVault/ReelVault are planned cards only.
- Credentials, profiles, keys, device IDs, Anisette data, and IPAs never enter Git.

The hub is a fresh identity, not an in-place upgrade of the former standalone smoke app.
Akshat removed that disposable app after its successful launch. No activity/history feature existed
in it; no migration is implemented. Do not reuse deletion as the workflow for future data-bearing
AkshatOS updates. Same-ID refresh/data preservation is still unverified.

## Cloud validation and delivery

Build 4 adds notification actions, durable queued commands, receipt persistence and regression tests.
Source `3cfea6176d43e79b8af899b579e0ac602b480715` passed all jobs including `CI Gate` in
[PR #1 run #10](https://github.com/akshatksingh18/akshatos/actions/runs/33897588498): 14-source boundary
checks and six negative fixtures, workflow/inventory checks, 20 domain assertions, 24 integration
tests, one hub/settings UI test, simulator/device compilation and IPA payload inspection.
The feature is published on `feature/squats-notification-actions` in
[PR #1](https://github.com/akshatksingh18/akshatos/pull/1); it is not merged into main.

PR runs intentionally omit IPA upload. A successful non-PR workflow dispatch or main source build
and checksum verification are required before installing build 4. No build-4 IPA was downloaded,
signed, installed or promoted to a release cache. The existing downloaded build 3 below remains
the selected historical preview. After a successful build-4 artifact is available, test Done/Pause/snooze from expanded and compact
notifications while locked and at the hub, duplicate/Undo behavior, relaunch, queued-action recovery,
and updating an old category-less schedule through Repair reminders. None has phone evidence yet.

The prior expanded pipeline in `ci.md` passed on source `a31643b2375abcd3e708ca3747c9980b1a3e78b8`,
[run #7](https://github.com/akshatksingh18/akshatos/actions/runs/33820332042): source/workflow checks,
12 domain assertions, three SwiftData tests, hub/settings navigation, simulator/device builds,
IPA inspection and `CI Gate`. It produced `akshatos-ios-7` and `test-diagnostics-7-1` in Actions.
That new artifact was not downloaded or physically tested; the verified local download below
remains run #6. No production app behavior or version changed in this CI-only task.

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

No local Mac is available. Windows edits source; macOS/Xcode in the private cloud build compiles.
Sideloadly locally signs the downloaded unsigned binary; weekly refresh does not require a rebuild.

## First AkshatOS install (manual steps; no computer control)

1. Use the verified **AkshatOS** download above, not the old smoke download; download a newer
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
   lock the phone, receive an alert, open Squats and Done +1, Undo, Pause, Resume, snooze, End, and
   reopen the app. Test 45 minutes too. No notification-action buttons exist in this slice.
8. Test goal setup, same-day sessions, yesterday unfinished, history, and save-failure handling.
   Record outcomes before calling features phone-verified; full matrix remains in `CLAUDE.md`.

Wi-Fi/automatic refresh, expiry recovery, in-place upgrades, full daily summary, notification
buttons, Home geofence, Shortcuts, and export/restore are not verified/completed by this first slice.
Keep real irreplaceable history out until recovery is implemented.

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
