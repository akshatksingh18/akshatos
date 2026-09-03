# Squat Reminder

Personal, local-only interval reminders with a polished daily dashboard, Pause/Resume controls,
actionable notifications, completed-set tracking, and an end-of-day overview. The accepted primary
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
- Receive ordinary local notifications until pausing or tapping **End my day**.
- Tap **Done +1** in the dashboard or notification after a squat break; v1 counts completed sets,
  not unrecorded individual repetitions.
- Use **Pause** while away and **Resume** when ready. Resume begins a fresh 45-minute interval.
- Use **Remind me in 10 min** for a short interruption such as dinner without pausing the day.
- End finalizes the day and shows completed sets, timing, pauses, snoozes, and a completion timeline.
- Keep lightweight daily summaries locally. There is no account, cloud sync, remote analytics,
  multiple schedule engine, or backend.

The accepted feature scope and dashboard behavior are in [`features.md`](features.md).

## Primary iPhone plan

Build a separate native SwiftUI target in this repository. It uses one repeating
`UNTimeIntervalNotificationTrigger` for the normal cadence plus at most one one-off snooze request;
iOS schedules delivery, so the app does not need a background timer, PWA, or push server. Repeating
intervals must be at least 60 seconds.

An actionable reminder category exposes Done, Pause, and Remind me in 10 min. Compact notification
space may show only Done and Pause; expand the notification for the third action. Dashboard and
notification controls use the same idempotent lifecycle commands.

Settings and current intent live in `UserDefaults`; versioned local session/event storage owns
completion timestamps, pause segments, and daily summaries. On launch and foreground return the app
must query actual notification permission and pending requests, merge any locked-device actions,
reconcile them with stored intent, and show Running only when system state supports that claim.

After the native core works, App Intents can expose Start, Pause, Resume, Done, and End to optional
Siri/Shortcuts automations. The recommended forgotten-away convenience is Leave Home → Pause and
Arrive Home → Resume, guarded so arrival cannot restart an ended or manually paused day. The app
itself does not request always-on location access and does not depend on automation.

### iPhone caveats

- Denied/revoked notification permission, disabled banners/sounds, Focus modes, and Scheduled
  Summary can silence or delay an accepted request. The app must explain these states and link to
  Settings; it cannot override them.
- Use ordinary notifications. Critical Alerts need special Apple approval, and Time Sensitive
  delivery is user-controlled; neither is required for the product.
- Force-quit, reboot, Low Power Mode, permission changes, and signing refresh/expiry behavior must
  be tested on the actual iPhone before calling reminders dependable.
- Notification actions must be tested locked/backgrounded, including duplicate callbacks, action
  order, Pause/End races, and persistence before the system background callback expires.
- Same-bundle refresh should preserve the app container, but it must be proven. Never uninstall as
  part of routine refresh because uninstall removes preferences, history, and pending requests.

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
signing, status, or recovery changes, update this README, `features.md`, `architecture.md`, `todo.md`,
and `CLAUDE.md` together. Keep accepted plan, present source, and physically verified behavior
separate.
