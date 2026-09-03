# Squat Reminder architecture

**State:** The iPhone-first architecture is accepted but unimplemented. The Android source tree is
an existing, never-verified fallback scaffold. Track the two platforms separately.

## Primary iPhone architecture

### Stack and source boundary

- Swift and SwiftUI in a separate iOS target/source area within this repository.
- UserNotifications for ordinary local reminders.
- `UserDefaults` for selected interval, desired running state, and a small schema/version key.
- One application target only: no widget, Watch app, App Group, notification-service extension,
  backend, analytics, remote push, or background mode.

### Scheduling model

- Keep one stable notification request identifier.
- Start validates a whole-minute interval, requests authorization when undetermined, removes any
  stale request with that identifier, and adds exactly one repeating
  `UNTimeIntervalNotificationTrigger`. The repeating interval is at least 60 seconds.
- Store/display Running only after the request is accepted and permission remains usable. The first
  reminder occurs one interval after Start.
- Stop removes the pending request by identifier, clears desired running state, and may remove
  already-delivered Squat Reminder notifications after physical testing establishes the least
  surprising behavior.
- Do not use an in-process timer, background loop, unbounded list of future notifications, Web Push,
  a Shortcut/Personal Automation, or a server.

### State reconciliation

On launch and every foreground return, inspect both notification settings and pending requests:

- desired running + correct request + usable permission = Running;
- desired running + missing/wrong request = repair-required state with explicit re-arm (or a later
  carefully tested foreground repair);
- desired stopped + unexpected request = cancel stale request;
- disabled/revoked permission = blocked state even if a request remains pending.

`UserDefaults` records intent, not system truth. Interval edits remain stopped-only. If that product
decision changes, replace the active request and update stored state only after replacement succeeds.

### iOS delivery limits

Focus, Scheduled Summary, sound/banner settings, permission revocation, and user actions can delay or
silence ordinary notifications. The UI should explain observable state and route to Settings; it
cannot promise interruption. Critical Alerts and Time Sensitive delivery are not product dependencies.

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

- One local user, one interval, one Start/Stop schedule, no history or service dependency.
- “Running” must reflect actual platform scheduling/permission capability, not preferences alone.
- Start must not create duplicates; Stop must make future reminders cease as far as the platform
  permits and report any unavoidable delivery race honestly.
- Platform scheduling implementations remain separate. Do not port Android exact-alarm assumptions
  to iOS or claim parity without physical tests on both devices.

## Documentation synchronization

Any material scheduling, permission, persistence, platform, build/signing, status, or recovery
change must update this file, `README.md`, `todo.md`, and `CLAUDE.md` in the same change. Record planned,
implemented, and physically verified state separately.
