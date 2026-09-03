# Squat Reminder

Personal, local-only interval reminders with one daily Start/Stop control. The accepted primary
target is iPhone; the existing Android Kotlin/Compose source remains an unverified fallback.

**Current state:** the iPhone app has not been scaffolded or built. The Android scaffold exists but
has never completed a clean build or physical-device run. Nothing in this README is a claim that
either platform is verified.

Source and planning are backed up in the private
[`akshatksingh18/squat-reminder`](https://github.com/akshatksingh18/squat-reminder) repository.
Private hosting does not change the app's local-only runtime design.

## Intended daily behavior

- Set a whole-minute reminder interval while stopped (default currently planned as 45 minutes).
- Tap **Start my day**; the first reminder is one interval later.
- Receive ordinary local notifications until tapping **Stop for the night**.
- Stop cancels the active schedule. Starting again creates one new schedule; repeated taps must not
  accumulate duplicate reminders.
- No account, backend, analytics, remote push, history, multiple schedules, or cloud dependency.

## Primary iPhone plan

Build a separate native SwiftUI target in this repository. It uses one repeating
`UNTimeIntervalNotificationTrigger` with a stable request identifier; iOS schedules delivery, so
the app does not need to remain running and must not use a background timer, Shortcut, PWA, or push
server. Repeating intervals must be at least 60 seconds.

The app stores only selected interval and desired state in `UserDefaults`. On launch and foreground
return it must query actual notification permission and pending requests, reconcile them with stored
intent, and show Running only when the system state supports that claim. Interval editing remains
disabled while running.

### iPhone caveats

- Denied/revoked notification permission, disabled banners/sounds, Focus modes, and Scheduled
  Summary can silence or delay an accepted request. The app must explain these states and link to
  Settings; it cannot override them.
- Use ordinary notifications. Critical Alerts need special Apple approval, and Time Sensitive
  delivery is user-controlled; neither is required for the product.
- Force-quit, reboot, Low Power Mode, permission changes, and signing refresh/expiry behavior must
  be tested on the actual iPhone before calling reminders dependable.
- Same-bundle refresh should preserve the app container, but it must be proven. Never uninstall as
  part of routine refresh because uninstall removes preferences and pending requests.

## iPhone build and installation

The detailed end-to-end build/signing/refresh/recovery plan is in `CLAUDE.md` and the shared
three-app portfolio is in `../CLAUDE.md`. In short:

- a compatible Mac/Xcode environment creates the standard release IPA when code changes;
- Windows uses Sideloadly/Local Anisette to sign and refresh the cached IPA;
- the permanent bundle ID, same Apple Account/team, early health checks, alerts, backup, and USB
  recovery rules must be preserved;
- Squat Reminder occupies one of the three slots alongside PageVault and WHOOP.

The iPhone path becomes usable only after the physical-device and multiple-refresh-cycle gates in
`CLAUDE.md` pass.

## Current Android fallback

The checked-in Android scaffold uses Kotlin/Compose and exact alarms. To evaluate it:

1. Open this folder in Android Studio and let Gradle sync.
2. Add and commit a Gradle wrapper before relying on command-line builds; none is stored yet.
3. Enable Developer Options/USB debugging on the fallback phone and run a physical-device build.
4. Verify Android 13+ notification permission and Android 12+ exact-alarm access.

Android intends to self-reschedule one exact alarm and re-arm after reboot when stored state is
running. This remains unverified, and OEM battery restrictions may interfere. Android details and
source ownership are in `architecture.md`; open work is in `todo.md`.

## Documentation synchronization

When product behavior, platform priority, scheduling, permission handling, persistence, build/
signing, status, or recovery changes, update this README, `architecture.md`, `todo.md`, and
`CLAUDE.md` together. Keep accepted plan, present source, and physically verified behavior separate.
