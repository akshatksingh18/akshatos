# AkshatOS and Squats architecture

**State:** Native hub/Squats lifecycle, actions, history, Home automation, foreground
reconciliation, chosen defaults and the expanded native-v1 regression suite are implemented.
Exact Build-9 verification passed in PR #4 run #37. Build-10 source implements snooze-first countdown
priority and a completion-only dashboard timeline. It also persists a cadence anchor after phone
testing showed Build 9 resetting the displayed countdown on close/reopen. PR #7 and main delivery
run #43 passed the Build-10 cloud gate; physical acceptance remains in `cloud-build.md`.
The remaining full-product contract below is not all implemented, and cloud checks cannot establish
real device behavior.

## Current implementation

- Canonical owner: `personal-project/akshatos`, temporarily public `akshatksingh18/akshatos`; repository
  history and the untouched Android fallback are preserved. Target/identity: AkshatOS,
  `com.akshatksingh18.akshatos`, working source version 0.2.0 (10); Build 9 remains the installed artifact.
- `app/AkshatOSApp.swift` creates `AppServices` through the application delegate before launch
  completes, including background launches. It owns one `SquatStore` and the sole
  `AppNotificationCoordinator` and one app-lifetime Core Location region adapter across navigation.
  `HubRootView` adapts observed Squats state into
  display-only `HubEntry` values, injects destinations, and reconciles foreground entry.
  `app/hub/HubView.swift` is the picker; `SquatDashboard.swift` opens only after choosing Squats.
  PageVault/ReelVault are noninteractive planned cards. WHOOP remains separate.
- `SquatSession.swift` is a pure Codable event/session model and calendar-day streak calculation.
  `SquatStore.swift` persists encoded sessions in the versioned SwiftData V1 schema. The feature's
  `ReminderService` schedules/cancels only its namespaced requests; the app owns the delegate.
  Only interval/goal preferences use UserDefaults.
  Store errors fail closed and preserve data rather than silently replacing the database.
- Implemented: Start/Pause/Resume/End, dashboard Done/Undo, notification Done/Pause/ten-minute snooze,
  one recurring local request and one replaceable snooze, permission/request reconciliation, daily
  overview/history with same-date aggregation and active/paused duration, configurable eight-set
  initial goal, current/best streak, versioned JSON export/validated restore, and completed-
  history deletion that preserves an active day.
- Changes to interval/goal are locked while active; the first session's goal governs that date.
  Foreground reconciliation closes a stale prior-day session at that date's next local calendar
  boundary and cancels its schedule. Calendar-day arithmetic handles DST; no background midnight
  launch is required or promised. Countdown is display-only;
  UserNotifications schedules delivery without relying on the dashboard or its timer. Future-dated
  clock artifacts are excluded from current/best streaks until their local date arrives.
- Foreground reconciliation canonicalizes out-of-range idle interval/goal preferences, drains both
  durable inboxes, validates the current recurring request and any one-off snooze against the active
  session/category/deadline, and removes stale snoozes without moving a healthy cadence.
- Home auto-pause source now includes staged When In Use/Always setup, map/radius confirmation, one
  stable circular region, protected local config/event files, launch/foreground reconciliation,
  debounce, pause-reason guards, outside-Home choices, degraded health, and boundary deletion.
  Reconciliation compares the actual monitored circle with the protected expected boundary;
  missing/mismatched registration invalidates stale presence and is replaced before health can be
  shown as known. It declares location usage strings without continuous background-location mode.
- Build-7 source completes the dashboard/Settings UI: `SquatStore` now tracks the real
  `NotificationAuthorization` (not-determined/authorized/provisional/ephemeral/denied) and
  `HomeAuthorization` (not-determined/when-in-use/always/denied/restricted) rather than a boolean or
  fragile status-string match, and blocking messages carry an explicit `SettingsRoute` so an alert
  can offer a direct one-tap route to the correct iOS Settings screen. Settings shows a dedicated
  Notifications section (status, Focus/Scheduled Summary/banner caveats, Settings link) alongside
  the existing Home auto-pause section, and the Home section now gives denied/restricted/when-in-use
  distinct explanations. The dashboard groups per-state hero/countdown text into one VoiceOver
  summary (a stable "next reminder around HH:MM" rather than a ticking announcement), combines
  decorative icons out of VoiceOver traversal, labels/values the goal progress bar, scales the three
  fixed-size hero numerals with `@ScaledMetric` for Dynamic Type, slows the countdown tick under
  Reduce Motion, and raises `Surface`'s border contrast under Increased Contrast.
- Build-8 source introduced three remaining improvements in that same task. `SquatStore` persists a
  monotonic `notificationEverAuthorized`/`homeEverAuthorized` flag (UserDefaults-backed, set once
  and never cleared) so a later denial can be phrased as a revocation ("turned off") instead of
  reusing first-request wording; `start()`/`resume()` and the Settings/Home sections all read it.
  The main dashboard's Home automation-health line is now an icon+text row (`house`/`house.fill`/
  `exclamationmark.triangle` for off/healthy/degraded) instead of a plain muted `Text`, matching the
  hero's per-state icon treatment. A new shared `AdaptiveRow` component (in `shared/design-system/`)
  stacks label/value rows vertically at accessibility Dynamic Type sizes instead of squeezing them
  into a fixed-width `HStack` + `Spacer`; it replaces every such row across the dashboard and daily
  summary except the one row (current/best streak) that intentionally has no `Spacer` in its
  compact layout, which instead switches to a `VStack` inline via `dynamicTypeSize.isAccessibilitySize`.
  Post-review source `d80653d` makes the remembered notification grant independent of alert
  availability, counts When In Use as a prior location grant, proves both flags persist across store
  recreation, and marks Home state/event storage excluded from device backup; PR run #27 passed.
- Build-9 source expands lifecycle/idempotency, preference/default, permission-transition,
  reconciliation/repair, snooze cleanup, Home-health/disable, DST/time-zone, summary/recovery,
  legacy-payload and Settings UI coverage. It also requires a non-nil next fire date before Resume
  treats an existing repeating request as healthy.
- Deferred: App Intents and physical/refresh acceptance. The notification category
  exposes Done, Pause, then Remind me in 10 min without requiring foreground launch.
- Review the intended contract below before extending these areas. Do not label cloud- or device-
  unverified behavior as accepted.

## Target iPhone architecture

### Implemented source-module boundaries

- `ios/AkshatOS/app/`: composition root and process-wide services; the only layer allowed to wire
  multiple features together. `app/hub/` takes metadata and a destination builder, not stores,
  database access, permissions or lifecycle commands.
- `ios/AkshatOS/shared/design-system/`: UI tokens/components, without app or feature dependencies.
- `ios/AkshatOS/features/squats/`: store plus `domain/` (Foundation-only), `data/` (SwiftData schema),
  `services/` (Squats scheduling) and `ui/` (dashboard/settings/summary). Features may use shared
  components, never the host or another feature's concrete types.
- `ios/tests/squats/`: feature domain assertions; `ios/UITests/`: app navigation tests.
- `ios/UnitTests/`: hosted SwiftData integration tests. The test inventory, CI gate, diagnostics,
  and merge-enforcement limitations are defined in `ci.md`; tests do not ship in the IPA.
- Future PageVault/ReelVault source belongs in sibling `features/pagevault/` and `features/reelvault/`
  areas with their own stores/tests. They are not created or implemented by this refactor.

All sources still compile into the existing AkshatOS module/application target. These are logical
source boundaries, not independently compiled packages or OS security isolation.
`python ios/scripts/check-boundaries.py` guards top-level type dependencies, pure-domain imports,
presentation/service separation and sole delegate ownership; six negative fixtures test the guard.
It is a lightweight source scan, not a full Swift parser; compiler and review still matter.

Existing schema/model names, the `Squats` store configuration, preference keys, notification request
IDs and Swift compilation module are unchanged. Optional payload fields add receipts and action
sources without a SwiftData schema migration or reset.
Same-ID physical upgrade remains an acceptance gate. The central coordinator owns foreground
presentation and action routing into Squats commands; never register competing delegates from feature constructors. Retain
background-capable services at app lifetime; load future media views/resources only on demand.

### Stack and source boundary

- Swift/SwiftUI modules in `ios/AkshatOS/`; extend the existing hub rather than creating separate apps.
- XcodeGen owns the versioned `ios/project.yml`; GitHub's macOS runner generates the disposable
  `.xcodeproj`. Do not hand-maintain or commit generated project internals from Windows.
- UserNotifications for ordinary local reminders and actionable notification categories.
- Core Location geographic-region monitoring for the optional Home boundary and a one-shot
  foreground location only while the user sets or edits Home. Use MapKit/SwiftUI Map for boundary
  confirmation; do not run continuous GPS or retain a movement trail.
- `UserDefaults` for settings, stable identifiers, daily-goal configuration (eight sets by default,
  with zero as explicit opt-out),
  geofence enablement/health and a small schema/version key. Pending actions use the atomic file inbox
  described below, not UserDefaults. Keep the Home coordinate/radius in protected, this-device-only local
  storage suitable after first unlock and marked excluded from device backup, never in logs,
  analytics, or Git.
- SwiftData for versioned day sessions, completion events, pause segments, snoozes, and finalized
  summaries—including each day's goal snapshot and qualification—when targeting iOS 17 or later.
  Derive current/best streak from those records instead of treating mutable counters as truth. Core
  Data or SQLite is the fallback only if the final device/toolchain makes SwiftData unsuitable.
- App Intents for optional Siri/Shortcuts commands after the same native domain commands are proven.
- One application target only: no widget, Watch app, App Group, notification-service extension,
  backend, analytics, or remote push. Add the honest location usage descriptions and only the
  location/background configuration proven necessary for region delivery on the selected target;
  do not enable continuous background-location updates as a substitute for region monitoring.

### Scheduling and action model

- Keep one stable recurring-request identifier and one stable one-off snooze identifier.
- Persist the first deadline of each Start/Resume cadence in the active session. Derive later regular
  deadlines from that anchor; use the system trigger's next date only once to migrate an active
  Build-9 session. Foreground reconciliation must never restart the displayed interval.
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

### Implemented notification durability

- The coordinator registers the namespaced category before launch completes. Default open/dismiss,
  unrelated requests, incorrect categories and malformed session IDs cannot log a set.
- A command receipt combines session ID, stable request ID, notification delivery timestamp and
  action ID; successive deliveries of the same repeating request remain distinct. The receipt is
  saved with the event in the session payload and survives Undo. Optional receipt/source/pause-reason
  fields decode existing V1 payloads without changing SwiftData model identity or resetting data.
- Every notification callback writes its command to `Application Support/squats-actions/inbox.json`
  before awaiting service work or checking the store's busy state. Atomic replacement and
  `completeUntilFirstUserAuthentication` protection retain commands while locked after first unlock.
  Main-actor serialization prevents competing inbox writers. Commit session data before removing a
  command; replay after a crash between those steps is a no-op. Corrupt inboxes are preserved.
- Foreground, protected-data-available and normal command completion drain the inbox. Failed loads
  retry without deleting/replacing the database. A queued Pause cancels the matching schedule even
  if the primary store is unavailable or an earlier Done save failed. Done waits for durable merge.
- Snooze keeps its original tap-time-plus-ten-minute deadline during retries, leaves the normal
  cadence unchanged, and is discarded with a visible message if expired or permission/cadence is
  unusable. A failed snooze save cancels its one-off request and retains the queued command.
- Old category-less recurring requests show repair-required until explicitly re-armed. A healthy
  repeated Resume leaves the existing cadence alone. New/old-session callbacks cannot revive End.
- The system callback completes after inbox persistence and attempted processing; callbacks arriving
  while busy may finish with their command durably queued. Pending count and retry UI explain this.
  Before the first unlock after reboot, or when the inbox itself cannot be written, persistence is
  not guaranteed: no completion is claimed and the next visible UI reports the failure. Physical
  lock/force-quit/callback-deadline tests remain mandatory; simulator faults only test the logic.

### Foreground state reconciliation

On launch, every foreground return, and after a user-visible domain action, merge pending locked
actions and inspect both notification settings and pending requests:

- desired running + correct request + usable permission = Running;
- desired running + missing/wrong request = repair-required state with explicit re-arm (or a later
  carefully tested foreground repair);
- desired paused/ended/not-started + unexpected recurring request = cancel stale request;
- disabled/revoked permission = blocked state even if a request remains pending.

The implementation also rejects a recurring request without a usable next trigger, removes a
snooze for another session or with the wrong category/deadline, and canonicalizes invalid idle
preferences. Home reconciliation compares the registered circular region's center/radius with the
protected saved boundary. A missing or mismatched registration resets presence to Unknown and
re-registers the saved boundary; permission, monitoring, background-refresh, or repair failures stay
visibly degraded.

The SwiftData session records lifecycle intent, not system truth. Interval edits remain unavailable while Running or
Paused so one active day keeps one interval. If that decision changes, replace the active request and
update stored state only after replacement succeeds.

### Domain state and data ownership

- Model Not started, Running, Paused, Ended, Blocked, and Repair required explicitly. Blocked and
  Repair required are observable operational states layered over the persisted day lifecycle.
- A day session owns a stable ID, local-day label, interval, daily-goal snapshot, start/end
  timestamps, lifecycle state, and ordered events. Events cover completed set, undo, pause, resume,
  and snooze with timestamp, source (dashboard/notification/native geofence/Shortcut), a distinct
  pause reason (`manual`, `notification`, `homeAwayAutomation`, or another accepted automation), and
  an idempotency ID.
- Notification and region callbacks may arrive while protected files are inaccessible. Persist a
  minimal event command in storage available for the intended locked-device use, acknowledge the
  system callback, and merge it transactionally later. Test data-protection behavior rather than
  assuming it.
- Daily summaries are derived locally from explicit stored events. Never infer a
  completed set or actual notification delivery. A date qualifies at most once when its non-undone
  completed-set total reaches that date's goal. Recompute summary and current/best streak data
  idempotently after Undo, migration, repair, or a past-day edit rather than maintaining conflicting
  counters.
- Anchor a session to its start local day and handle crossing midnight explicitly. On the next
  launch/foreground reconciliation, close a stale prior-day session at that date's next local
  calendar boundary before allowing a new day. Use calendar arithmetic so DST can produce a 23- or
  25-hour date; never start a second overlapping day.
- Store the goal with each local date and apply configuration changes only to later dates. Streak
  tracking begins when the goal is first enabled; dates before that are neutral. The current date is
  at risk rather than failed until local-date rollover, including after its active session is ended.
  Missing dates after tracking begins count as failures, and multiple sessions cannot award the same
  date twice.

### UI architecture

- Keep view state derived from a central app/session model rather than letting buttons directly edit
  preferences or notifications. Views issue domain commands and render reconciled state.
- Build reusable visual tokens and components for the state hero, scheduled countdown, completed-set
  count, daily-goal progress, current/best streak, lifecycle controls, completion timeline, automation
  health, and daily summary. Respect Dynamic Type, VoiceOver, Reduce Motion, contrast, and non-color
  state indicators from the first scaffold.
- Label countdowns as **scheduled** because Focus, Scheduled Summary, and system/user settings mean
  the app cannot promise exact visible delivery. Normally the persisted regular cadence owns the
  prominent countdown. While a one-off snooze is pending, its earlier deadline replaces that clock;
  do not render a competing secondary countdown.
- Keep the dashboard's **Your day so far** list completion-only: one row per non-undone Done event
  with its time. Continue persisting pause/resume/snooze events for lifecycle reconciliation,
  durations and summaries, but do not render them in this at-a-glance list.
- End requires confirmation; Done offers Undo; paused/blocked/repair states present the one relevant
  recovery action without clutter.

### iOS delivery limits

Focus, Scheduled Summary, sound/banner settings, permission revocation, and user actions can delay or
silence ordinary notifications. The UI should explain observable state and route to Settings; it
cannot promise interruption. Critical Alerts and Time Sensitive delivery are not product dependencies.
Compact notification interfaces may show only the first two category actions, which is why Done and
Pause come before the expanded-only 10-minute action; verify this on the actual iPhone.

### Home geofence and optional Shortcuts automation

- Put Home setup behind an explicit opt-in explanation. Request When In Use access to obtain and
  confirm a one-shot current location, then request Always access for region events when the app is
  backgrounded or terminated. Denial, revocation, insufficient authorization, unavailable region
  monitoring, Background App Refresh restrictions, reboot-before-first-unlock, force-quit behavior,
  and missed events must appear as degraded/unknown—not silently healthy.
- Monitor one circular Home condition with one stable identifier through a small location-service
  adapter. Recreate/reconcile it at launch, debounce boundary jitter and duplicate callbacks, and
  persist only the boundary plus last observed state/health. Disabling the feature unregisters the
  condition and deletes its coordinate/radius.
- A Home exit invokes the shared Pause command only from Running and records `homeAwayAutomation`. A Home
  entry invokes Resume only for the same active day still paused for that exact reason. It never
  starts a day, revives an Ended day, or overrides a dashboard, notification, Siri, or Shortcut
  pause. Resume starts a fresh reminder interval.
- A deliberate Pause received while already Home-auto-paused promotes the pause reason to the
  deliberate source. When Start occurs while the reconciled Home state is Outside, offer start-paused
  or an explicit run-anyway choice. A manual Resume confirmed while Outside sets a temporary
  automation override until the next Home entry or End so a jitter/duplicate exit cannot immediately
  pause again.
- Expose Start, Pause, Resume, Log completed set, and End as App Intents only after their native
  domain commands and persistence pass. Optional Leave/Arrive or Focus automations are backup or
  alternate triggers. Native and Shortcut Home callbacks share `homeAwayAutomation`; either matching
  entry can resume either exit. Both may arrive, so every command validates state, reason,
  idempotency, and the temporary override before changing anything.

### Build/deployment boundary

The workflow now builds AkshatOS from this repository. Its IPA contains the hub and the first
Squats slice, not PageVault/ReelVault implementations. Keep
Squats handlers at host scope, namespace requests, and test notifications while other modules are
foregrounded. One hub refresh must preserve all three modules' state.


The primary compiler is the public repository's GitHub Actions macOS runner because no local Mac
is available.
It selects a documented Xcode image, generates the project from `ios/project.yml`, compiles simulator
and generic-device builds, packages a standard unsigned IPA, verifies bundle metadata/architecture,
and publishes the IPA plus SHA-256/build metadata as a temporary artifact. The build has no Apple
credentials or signing material. This cloud side has passed for smoke build `0.1.0 (1)` at source
commit `cc9fe467f6088205b51958c9dea28217ae42a6fe`; Akshat subsequently confirmed Sideloadly installation
and physical launch with the matching smoke-version screen. This is not hub or feature acceptance.

Trusted Windows verifies and caches a physically proven artifact, then Sideloadly signs/installs it
using the same Apple Account and permanent bundle ID. Same-bundle overwrite, state/request
reconciliation, expiry recovery, and USB fallback must pass on the physical iPhone; routine refresh
never uninstalls the app. The release target includes accurate notification and location usage strings
and no unnecessary continuous-location configuration. Streak/date logic and Home-region behavior
must pass tests plus the physical matrix in `CLAUDE.md`; simulator or green CI alone is insufficient.
The XcodeGen source remains portable to a borrowed/rented Mac or another compatible macOS builder.
Detailed artifact/install steps live in `cloud-build.md`.

Sideloadly is present at its standard per-user Windows installation path. Akshat reports successful
Local Anisette initialization followed by USB device detection; `cloud-build.md` records the working
startup sequence. Signing, installation, and first launch passed. Wi-Fi pairing, same-ID upgrades,
background refresh, and expiry recovery remain unverified.

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
  lightweight local summaries, a configurable daily-goal streak, and optional native Home
  auto-pause. The Android scaffold does not have these yet and remains a fallback without parity
  claims.
- “Running” must reflect actual platform scheduling/permission capability, not preferences alone.
- Lifecycle commands must not create duplicates; Pause/End must make future reminders cease as far
  as the platform permits and report any unavoidable delivery race honestly.
- Only explicit Done actions count as completion. Scheduled or apparently delivered reminders do not.
- Streak qualification is deterministic per local calendar date and uses the goal stored for that
  date; location data remains on-device and is never a completion signal.
- Platform scheduling implementations remain separate. Do not port Android exact-alarm assumptions
  to iOS or claim parity without physical tests on both devices.

## Documentation synchronization

Any material scheduling, notification/location permission, streak, persistence, platform, build/
signing, status, or recovery change must update this file, `features.md`, `README.md`, `todo.md`, and
`CLAUDE.md` in the same change. Record planned, implemented, and physically verified state separately.
