# Squat Reminder architecture

**State:** The iPhone-first architecture is accepted but unimplemented. The Android source tree is
an existing, never-verified fallback scaffold. Track the two platforms separately.

## Primary iPhone architecture

### Stack and source boundary

- Swift and SwiftUI in a separate iOS target/source area within this repository.
- UserNotifications for ordinary local reminders and actionable notification categories.
- `UserDefaults` for settings, lifecycle intent, stable identifiers, a small schema/version key, and
  a lock-safe pending-action inbox when primary data is inaccessible.
- SwiftData for versioned day sessions, completion events, pause segments, snoozes, and finalized
  summaries when targeting iOS 17 or later. Core Data or SQLite is the fallback only if the final
  device/toolchain makes SwiftData unsuitable.
- App Intents for optional Siri/Shortcuts commands after the same native domain commands are proven.
- One application target only: no widget, Watch app, App Group, notification-service extension,
  native location/geofencing, backend, analytics, remote push, or background mode.

### Scheduling and action model

- Keep one stable recurring-request identifier and one stable one-off snooze identifier.
- Start validates a whole-minute interval (45 minutes by default), requests authorization when
  undetermined, creates an active day, removes stale project requests, and adds exactly one repeating
  `UNTimeIntervalNotificationTrigger`. The repeating interval is at least 60 seconds. Store/display
  Running only after the request is accepted; its first reminder occurs one interval after Start.
- Pause removes the recurring request and any pending snooze while keeping the day open. Resume
  replaces the recurring request and begins a fresh interval. End removes recurring/snooze requests
  and finalizes the active day.
- Register a reminder category with actions ordered Done, Pause, and Remind me in 10 min. Done records
  one set without changing the cadence. Pause calls the same idempotent pause command as the UI.
  Snooze replaces one one-off request for ten minutes later while the regular request continues.
- `UNUserNotificationCenterDelegate` routes responses by category/action identifier and always calls
  its completion handler after durable/idempotent processing. The normal app, notification handler,
  and App Intents never implement separate state-transition logic.
- Do not use an in-process timer, background loop, unbounded list of future notifications, Web Push,
  a Shortcut/Personal Automation as the reminder engine, or a server.

### State reconciliation

On launch, every foreground return, and after a user-visible domain action, merge pending locked
actions and inspect both notification settings and pending requests:

- desired running + correct request + usable permission = Running;
- desired running + missing/wrong request = repair-required state with explicit re-arm (or a later
  carefully tested foreground repair);
- desired paused/ended/not-started + unexpected recurring request = cancel stale request;
- disabled/revoked permission = blocked state even if a request remains pending.

`UserDefaults` records intent, not system truth. Interval edits remain unavailable while Running or
Paused so one active day keeps one interval. If that decision changes, replace the active request and
update stored state only after replacement succeeds.

### Domain state and data ownership

- Model Not started, Running, Paused, Ended, Blocked, and Repair required explicitly. Blocked and
  Repair required are observable operational states layered over the persisted day lifecycle.
- A day session owns a stable ID, local-day label, interval, start/end timestamps, lifecycle state,
  and ordered events. Events cover completed set, undo, pause, resume, and snooze with timestamp,
  source (dashboard/notification/Shortcut), and idempotency ID.
- Notification actions may arrive while protected files are inaccessible. Persist a minimal event
  command in storage available for the intended locked-device use, acknowledge the system callback,
  and merge it transactionally later. Test data-protection behavior rather than assuming it.
- Finalized daily summaries are derived from explicit events and stored locally. Never infer a
  completed set or actual notification delivery. Recompute summary data idempotently after migration
  or repair rather than maintaining conflicting counters.
- Anchor a session to its start local day and handle crossing midnight explicitly. A stale prior-day
  Running session must be surfaced for resolution; do not silently fabricate an end time or start a
  second overlapping day.

### UI architecture

- Keep view state derived from a central app/session model rather than letting buttons directly edit
  preferences or notifications. Views issue domain commands and render reconciled state.
- Build reusable visual tokens and components for the state hero, scheduled countdown, completed-set
  count, lifecycle controls, event timeline, and daily summary. Respect Dynamic Type, VoiceOver,
  Reduce Motion, contrast, and non-color state indicators from the first scaffold.
- Label the countdown as the next **scheduled** reminder. Focus, Scheduled Summary, and system/user
  settings mean the app cannot promise the exact visible delivery time.
- End requires confirmation; Done offers Undo; paused/blocked/repair states present the one relevant
  recovery action without clutter.

### iOS delivery limits

Focus, Scheduled Summary, sound/banner settings, permission revocation, and user actions can delay or
silence ordinary notifications. The UI should explain observable state and route to Settings; it
cannot promise interruption. Critical Alerts and Time Sensitive delivery are not product dependencies.
Compact notification interfaces may show only the first two category actions, which is why Done and
Pause come before the expanded-only 10-minute action; verify this on the actual iPhone.

### Optional Shortcuts automation boundary

Expose Start, Pause, Resume, Log completed set, and End as App Intents only after their native domain
commands and persistence pass. Optional Leave Home/Arrive Home or Focus automations may invoke them,
but the app itself requests no location permission and owns no geofence. Record pause source/reason;
an arrival automation resumes only a session paused by the matching away automation, never one ended
or deliberately paused another way. Disabled, delayed, duplicated, or failed automations must be safe
because every command validates current state and is idempotent.

### Build/deployment boundary

A compatible Mac/Xcode environment produces a conventional release IPA with one permanent bundle
ID. Windows refreshes the cached IPA through the shared Sideloadly portfolio. Same-bundle overwrite,
state/request reconciliation, expiry recovery, and USB fallback must pass on the physical iPhone;
routine refresh never uninstalls the app. Detailed gates live in `CLAUDE.md` and `../CLAUDE.md`.

## Current Android fallback architecture

### Stack

- Kotlin 2.2.20 and Jetpack Compose with Material3.
- AGP 9.2.1, compileSdk/targetSdk 36, minSdk 26.
- `AlarmManager.setExactAndAllowWhileIdle` for reminder scheduling.
- SharedPreferences for running state, interval, and next trigger time.
- No database, navigation framework, backend, or analytics.

These are scaffold selections, not verified build results. Re-check compatibility on activation.

### Source layout

```text
app/src/main/java/com/akshat/squatreminder/
├── MainActivity.kt        # Interval field, Start/Stop, and next-reminder display
├── ReminderScheduler.kt   # Starts, stops, schedules, and cancels alarms
├── ReminderReceiver.kt    # Shows a notification and schedules the next alarm
├── BootReceiver.kt        # Re-arms the chain after reboot when marked running
└── ReminderPrefs.kt       # SharedPreferences wrapper
```

### Android scheduling decisions

- The interval is editable only while stopped and is read when starting the next chain.
- Exact alarms were selected over periodic WorkManager or a foreground service for closer interval
  timing, subject to exact-alarm permission and OEM behavior.
- Each receiver invocation schedules the next alarm only while stored running state is true, so one
  alarm remains in flight.
- Manifest declarations are not enough: notification permission and exact-alarm access must be
  reflected in truthful UI state.
- Exact alarms disappear on reboot; `BootReceiver` intends to re-arm from stored state. This has not
  been proven on hardware.

## Cross-platform product invariants

- One local user, one interval, one active daily session, and no service dependency.
- The accepted iPhone product includes Start/Pause/Resume/End, completed-set events, a daily overview,
  and lightweight local summaries. The Android scaffold does not have these yet and remains a
  fallback without parity claims.
- “Running” must reflect actual platform scheduling/permission capability, not preferences alone.
- Lifecycle commands must not create duplicates; Pause/End must make future reminders cease as far
  as the platform permits and report any unavoidable delivery race honestly.
- Only explicit Done actions count as completion. Scheduled or apparently delivered reminders do not.
- Platform scheduling implementations remain separate. Do not port Android exact-alarm assumptions
  to iOS or claim parity without physical tests on both devices.

## Documentation synchronization

Any material scheduling, permission, persistence, platform, build/signing, status, or recovery
change must update this file, `features.md`, `README.md`, `todo.md`, and `CLAUDE.md` in the same
change. Record planned, implemented, and physically verified state separately.
