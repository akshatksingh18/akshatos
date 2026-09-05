# AkshatOS

A private, native iPhone hub. Open AkshatOS, select **Squat Reminder**, and enter its movement
dashboard. PageVault and ReelVault are reserved for later; WHOOP stays a separate app.

**Current state:** hub/Squats implementation with notification actions, daily history, local
recovery, Home auto-pause and expanded goal/streak edge handling, source version **0.2.0 (6)**,
bundle ID `com.akshatksingh18.akshatos`. Build/device evidence lives in
[cloud-build.md](cloud-build.md). The old standalone smoke successfully launched and was removed
by Akshat; that is not evidence that this new hub build works on the phone.
The build-4 unsigned IPA is downloaded and hash-verified after passing cloud tests; the build guide
contains its exact path and manual Sideloadly steps. Physical acceptance remains pending.
The accepted order is to finish native Squats v1 and its automated tests first, then have Akshat
test the complete feature on the phone. Sideloading is reported working; continued implementation
does not wait for another installation exercise.

This repository evolved from Squat Reminder, retaining Git history and the unverified Android
fallback. Source is private at [akshatksingh18/akshatos](https://github.com/akshatksingh18/akshatos).

## First slice

GitHub Actions checks feature boundaries, registered domain tests, simulator persistence/navigation,
device compilation and IPA integrity. [CI contract](ci.md) defines coverage and the current lack of
server-enforced branch protection on the private repository. Green CI is not physical acceptance.

App composition, display-only hub, shared styling and Squats feature are separated;
[architecture.md](architecture.md) defines dependencies and the boundary-check command.

- Hub app picker; Squats dashboard; visibly planned PageVault/ReelVault entries.
- Start/Pause/Resume/End, Done +1/Undo and ten-minute snooze from dashboard or notification.
- Notification actions ordered Done, Pause, then snooze; durable inbox, replay protection after Undo,
  and queued-action retry UI. Locked-device behavior still needs physical verification.
- One system-scheduled recurring reminder; local versioned SwiftData sessions and daily summaries.
- Configurable daily goal (unset initially), current/best streak and today's progress.
- Same-date daily overview with active/paused duration, event/pause detail, local-midnight rollover,
  versioned JSON export/restore, and confirmed deletion of completed history.
- Optional staged Home setup with one protected local geofence, pause-source guards, outside-Home
  Start/Resume choices, visible health, and edit/disable/delete. No route history is retained.
- No server, telemetry, account, or embedded WHOOP.

**Still deferred:** Shortcuts, remaining v1 UI/reliability work and physical
acceptance testing. The full intended scope below remains the
target, not a list of completed features. Until recovery and device tests pass, use disposable
test activity only.

## Intended daily behavior

- Set a whole-minute reminder interval while stopped (default currently planned as 45 minutes).
- Tap **Start my day**; the first reminder is one interval later.
- Receive ordinary local notifications until pausing or tapping **End my day**.
- Tap **Done +1** in the dashboard or notification after a squat break; v1 counts completed sets,
  not unrecorded individual repetitions.
- Reach the configurable daily set goal to qualify that local date for the streak. The dashboard
  shows today's progress plus current and personal-best streak; the initial goal number remains to
  be chosen later rather than hard-coded now.
- Use **Pause** while away and **Resume** when ready. Resume begins a fresh 45-minute interval.
- Optionally configure Home once so a system geofence pauses a Running day after leaving and resumes
  only that same day if the geofence caused the pause. Manual controls remain available at all times.
- Use **Remind me in 10 min** for a short interruption such as dinner without pausing the day.
- End finalizes the session and shows completed sets, goal/streak status, timing, pauses, snoozes, and
  a completion timeline. A below-goal current date stays marked at risk until that date ends.
- Keep lightweight daily summaries locally. There is no account, cloud sync, remote analytics,
  movement history, multiple schedules, second reminder engine, or backend.

The accepted feature scope and dashboard behavior are in [`features.md`](features.md).

## Primary iPhone plan

The `ios/` source now opens the hub picker and a separate Squats dashboard. The build path is
Windows → GitHub macOS runner → unsigned IPA → Sideloadly → physical iPhone. It uses one repeating
`UNTimeIntervalNotificationTrigger` for the normal cadence plus at most one one-off snooze request;
iOS schedules delivery, so the app does not need a background timer, PWA, or push server. Repeating
intervals must be at least 60 seconds.

The notification category exposes Done, Pause, and Remind me in 10 min. Compact notification
space may show only Done and Pause; expand the notification for the third action. Dashboard and
notification controls use the same idempotent lifecycle commands.
An old preview's schedule may show Repair reminders after update; re-arm it once to attach the
current buttons. Actions are queued before processing and receipts survive Undo. If protected
session data is unavailable, logging waits for unlock and merge; a matching Pause can still cancel
the schedule. Snooze expires ten minutes from its tap, even during recovery. Before first unlock
after reboot or on inbox-write failure, saving an action cannot be guaranteed; check the visible
error and your count after opening Squats. These conditions still need physical-phone acceptance.

Interval/goal settings live in `UserDefaults`; current session intent and events live in the
versioned SwiftData store. Versioned local session/event storage owns
completion timestamps, pause segments, each date's goal snapshot/qualification, and daily summaries.
Current and best streak are derived from those records. On launch and foreground return the app must
query actual notification permission and pending requests, merge any locked-device actions,
reconcile them with stored intent, and show Running only when system state supports that claim.
An unended earlier local date is closed at its next local calendar boundary during that reconciliation;
the boundary uses calendar arithmetic for DST and does not require a background timer. Settings can
export a versioned JSON backup, validate and restore it before replacing current Squats data, or
delete completed history while retaining the active day and preferences.

The implemented forgotten-away convenience is an opt-in native Home geofence. Setup uses one foreground
location to choose/confirm a circular Home boundary, then requests the authorization needed for iOS
to deliver region entry/exit events while the app is not open. Only the coordinate/radius and health
state stay in protected local storage and are excluded from Squats backup exports; the app never
continuously tracks location or saves a route. Build-6 cloud and physical behavior remain unverified.
Leaving pauses only a Running day, and returning resumes only a still-active day whose pause reason
is Home-away automation. A deliberate pause always wins; an explicit run-anyway choice while outside
temporarily suppresses repeat exit events.

After the native commands work, App Intents expose Start, Pause, Resume, Done, and End to optional
Siri/Shortcuts Leave/Arrive or Focus automations. They are backup/alternate triggers, not the reminder
engine. Native and Shortcut events share idempotent, pause-source-aware commands so duplicates are
safe.

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
- Home entry/exit is a system convenience, not precise real-time tracking. Authorization changes,
  Background App Refresh restrictions, boundary jitter, reboot-before-first-unlock, force-quit, or a
  missed region event can degrade it; the app must report that status and retain manual/notification
  controls rather than silently claiming success.
- Streak qualification uses explicit non-undone Done events and the goal stored for each local date.
  Test skipped days, multiple same-day sessions, Undo, goal changes, midnight, daylight-saving, and
  time-zone changes before trusting current/best totals.
- Same-bundle refresh should preserve the app container, but it must be proven. Never uninstall as
  part of routine refresh because uninstall removes preferences, history, and pending requests.

## iPhone build and installation

The AkshatOS build/download/install procedure is in [`cloud-build.md`](cloud-build.md). The broader
build/signing/refresh/recovery plan is in `CLAUDE.md`. The selected package is one native hub for
Squats, PageVault, and ReelVault plus standalone WHOOP (two slots), detailed in `hub-plan.md`.
The current target is AkshatOS; old downloaded standalone smoke files are not hub builds. In short:

- source is authored on Windows and a private GitHub Actions macOS/Xcode runner generates the Xcode
  project, compiles it, and uploads an unsigned IPA plus checksum/build metadata;
- GitHub receives no Apple credentials or signing material; Windows verifies the artifact and uses
  Sideloadly for personal signing and installation;
- Windows uses Sideloadly/Local Anisette to sign and refresh the cached IPA;
- the permanent bundle ID, same Apple Account/team, early health checks, alerts, backup, and USB
  recovery rules must be preserved;
- all three native feature modules will share one hub identity, IPA, permissions, and update; WHOOP
  keeps a separate identity/process. No paid membership or rotation is needed for two slots.

The AkshatOS bundle ID is `com.akshatksingh18.akshatos`. Preserve it and the same Apple Account
on updates. Do not uninstall a data-bearing app to repair signing. See the complete feature and
refresh acceptance gates in `CLAUDE.md`.

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

When product behavior, platform priority, scheduling, notification/location permission handling,
streak rules, persistence, build/signing, status, or recovery changes, update this README,
`features.md`, `architecture.md`, `todo.md`, and `CLAUDE.md` together. Keep accepted plan, present
source, and physically verified behavior separate.
