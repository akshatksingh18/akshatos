# AkshatOS

A native personal iPhone hub. Open AkshatOS and select **Pushup Reminder** for its movement dashboard,
**PageVault** for its PDF library, or **Lift Log** to record strength sessions. ReelVault is reserved
for later and WHOOP stays a separate app.

**Current state:** Candidate 0.4.0 (26) adds Lift Log with per-side plate measurement, durable
active sessions, finished history, JSON backup/restore and CSV export. PR #52 is merged at
`7a4f639`; main run `35870794873` passed the complete CI Gate, including registered domain and
hosted simulator tests, simulator/device compilation and IPA inspection. Artifact `akshatos-ios-129`
also passed local checksum/IPA validation and is retained for its physical-phone pass; installation,
data preservation and phone behavior are not yet verified. The proven movement engine has
been repurposed from squats to **Pushup Reminder**
without changing its stored sessions, preference keys, backup schema or pending-notification identity.
Accepted 0.3.0 (25) also introduces a quirky Homebase/quest presentation across the hub,
Pushup Reminder and PageVault. Retained-candidate commit `4253311` passed complete macOS CI, including
tests, simulator/device compilation and IPA inspection; artifact `akshatos-ios-123` also passed local
checksum/IPA validation. Its Wi-Fi install reached 100%, and Sideloadly records version 0.3.0 with
the expected signed identity and automatic-refresh enrollment. Akshat then reported that Build 25
works perfectly, so its focused launch/presentation pass is accepted and its artifact is the current
recovery/refresh copy. Build 13 remains the detailed legacy evidence for lifecycle behavior, while
the broader edge-case, refresh/recovery and soak matrix remains open. PageVault's v1 reading and
recovery loop is accepted on the phone through Build 24, and Build 25's refreshed presentation is
accepted too; reading streaks were built and then removed at Akshat's request. Bundle ID
`com.akshatksingh18.akshatos`.
The working source version, build evidence and install steps live in [cloud-build.md](cloud-build.md);
open gates live in [todo.md](todo.md), and PageVault's in `../book-reader/CLAUDE.md`.

This repository evolved from Squat Reminder and now presents that feature as Pushup Reminder,
retaining Git history and the unverified legacy Android Squats fallback. Source is temporarily public at
[akshatksingh18/akshatos](https://github.com/akshatksingh18/akshatos) for hosted macOS CI capacity.

## First slice

GitHub Actions checks feature boundaries, registered domain tests, simulator persistence/navigation,
device compilation and IPA integrity. [CI contract](ci.md) defines coverage, documentation-only PR
build skipping, and the server-enforced `main` protection. Green CI is not physical acceptance.

App composition, display-only hub, shared styling and the Pushup Reminder feature are separated;
[architecture.md](architecture.md) defines dependencies and the boundary-check command.

- Playful Homebase hub, Pushup Reminder power-up dashboard and PageVault story-quest library;
  Lift Log is an available gold-accent strength portal and ReelVault is a visibly locked future portal.
- Lift Log records one active workout at a time, defaults each new exercise to plates per side,
  preserves alternate per-hand/stack/added/total measurement modes, saves after every mutation,
  recovers unfinished sessions, and exports a restorable JSON backup or reviewable CSV. It never
  guesses bar, sled or machine resistance; [lift-log.md](lift-log.md) owns the contract and gates.
- Start/Pause/Resume/End and Done +1/Undo from dashboard or notification.
- Notification actions ordered Done then Pause; ignored reminders automatically nudge every ten
  minutes within a bounded pre-scheduled horizon; durable inbox, replay protection after Undo,
  and queued-action retry UI. Locked-device behavior still needs physical verification.
- One bounded normal-plus-nudge schedule while active and one 9:00 AM start invitation while idle;
  local versioned SwiftData sessions and daily summaries.
- Configurable daily goal (eight sets initially; zero turns it off), current/best streak and
  today's progress.
- Same-date daily overview with active/paused duration, event/pause detail, local-midnight rollover,
  versioned JSON export/restore, and confirmed deletion of completed history.
- Optional staged Home setup with one protected local geofence, pause-source guards, outside-Home
  Start/Resume choices, visible health, and edit/disable/delete. No route history is retained.
- No server, telemetry, account, or embedded WHOOP.

**Still deferred:** Shortcuts and the remaining physical, refresh and recovery testing. The full
intended scope below remains the target, not a list of completed features. Until recovery and device tests pass, use
disposable test activity only.

## Intended daily behavior

- Set a whole-minute reminder interval while stopped (default currently planned as 45 minutes).
- Tap **Start my day**; the first reminder is one interval later.
- Receive ordinary local notifications until pausing or tapping **End my day**.
- Tap **Set crushed +1** in the dashboard or **Done** in the notification after a pushup break; v1 counts completed sets,
  not unrecorded individual repetitions. Done dismisses any unresolved nudge and restarts the full
  regular interval from that completed set, including when the ordinary 45-minute countdown was
  active.
- Reach the configurable daily set goal to qualify that local date for the streak. New installs
  start at eight completed sets; setting the goal to zero turns streak tracking off. The dashboard
  shows today's progress plus current and personal-best streak.
- Use **Pause** while away and **Resume** when ready. Resume begins a fresh 45-minute interval.
- Optionally configure Home once so a system geofence pauses a Running day after leaving and resumes
  only that same day if the geofence caused the pause. Manual controls remain available at all times.
- If a normal reminder is ignored, the main clock advances to the next automatic ten-minute nudge
  and iOS continues those nudges until Done or Pause. Done begins a fresh full interval. The app
  pre-schedules a bounded horizon and replenishes it when it returns to the foreground.
- While no day is active and notification access exists, a repeating 9:00 AM local notification
  invites you to open AkshatOS. Tapping it opens the app but does not start the timer automatically.
- **Your day so far** shows only completed sets and their times, not pause/resume bookkeeping.
- End finalizes the session and shows completed sets, goal/streak status, timing, pauses and a
  completion timeline. A below-goal current date stays marked at risk until that date ends.
- Keep lightweight daily summaries locally. There is no account, cloud sync, remote analytics,
  movement history, multiple schedules, second reminder engine, or backend.

The accepted feature scope and dashboard behavior are in [`features.md`](features.md).

## Primary iPhone plan

The `ios/` source opens the Homebase hub, a separate Pushup Reminder dashboard, the PageVault library,
and Lift Log. The build path is
Windows → GitHub macOS runner → unsigned IPA → Sideloadly → physical iPhone. It uses a bounded batch
of one-off `UNTimeIntervalNotificationTrigger` requests for the normal reminder and automatic nudges,
plus one repeating 9:00 AM calendar request while idle. iOS schedules delivery, so the app does not
need a background timer, PWA, or push server.

The notification category exposes Done and Pause. Dashboard and notification controls use the same
idempotent lifecycle commands. Legacy Build-12 snooze actions remain decode-safe but do nothing.
An old preview's schedule may show Repair reminders after update; re-arm it once to attach the
current buttons. Actions are queued before processing and receipts survive Undo. If protected
session data is unavailable, logging waits for unlock and merge; a matching Pause can still cancel
the schedule. Before first unlock after reboot or on inbox-write failure, saving an action cannot be
guaranteed; check the visible error and your count after opening Pushups. These conditions still need
physical-phone acceptance.

Interval/goal settings live in `UserDefaults`; the current session also persists the regular cadence
anchor so closing or foregrounding the app cannot restart the displayed interval. Session intent and events live in the
versioned SwiftData store. Versioned local session/event storage owns
completion timestamps, pause segments, each date's goal snapshot/qualification, and daily summaries.
Current and best streak are derived from those records. On launch and foreground return the app must
query actual notification permission and pending requests, merge any locked-device actions,
reconcile them with stored intent, and show Running only when system state supports that claim.
An unended earlier local date is closed at its next local calendar boundary during that reconciliation;
the boundary uses calendar arithmetic for DST and does not require a background timer. Settings can
export a versioned JSON backup, validate and restore it before replacing current Pushups data, or
delete completed history while retaining the active day and preferences.

The implemented forgotten-away convenience is an opt-in native Home geofence. Setup uses one foreground
location to choose/confirm a circular Home boundary with a configurable 150-meter initial radius,
then requests the authorization needed for iOS
to deliver region entry/exit events while the app is not open. Only the coordinate/radius and health
state stay in protected local storage excluded from both device backups and Pushups backup exports;
the app never continuously tracks location or saves a route. Physical geofence behavior remains
unverified.
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
Pushups, PageVault, Lift Log, and ReelVault plus standalone WHOOP (two slots), detailed in `hub-plan.md`.
The current target is AkshatOS; old downloaded standalone smoke files are not hub builds. In short:

- source is authored on Windows and a public-repository GitHub Actions macOS/Xcode runner generates
  the Xcode project, compiles it, and uploads an unsigned IPA plus checksum/build metadata;
- GitHub receives no Apple credentials or signing material; Windows verifies the artifact and uses
  Sideloadly for personal signing and installation;
- Windows uses Sideloadly/Local Anisette to sign and refresh the cached IPA;
- the permanent bundle ID, same Apple Account/team, early health checks, alerts, backup, and USB
  recovery rules must be preserved;
- all four native feature modules will share one hub identity, IPA, permissions, and update; WHOOP
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
source, and physically verified behavior separate. Build-by-build evidence belongs only in
`cloud-build.md`.
