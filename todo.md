# TODO / known gaps

This is current-state work, not a claim that either platform is already usable. The iPhone path is
primary; Android remains a separate fallback scaffold. PageVault's gates live in
`../book-reader/CLAUDE.md`; this file owns Squats and hub-wide gates.

**Current focus:** Build 13 is accepted in ongoing daily phone use for Squats. The unchecked physical,
release-cache and refresh items below stay open regardless of PageVault progress. Akshat deferred
PageVault's physical testing to one end-of-implementation pass. Build evidence lives in `cloud-build.md`.

## iPhone-primary work

### Done

- [x] **Cloud pipeline and repository controls.** Source, inventory and workflow checks, registered
      domain suites, hosted persistence tests, UI navigation, device build, IPA inspection and
      `CI Gate` run on every PR; real PR triggering and failure diagnostics have been exercised. The
      repository is temporarily public with strict `main` protection; `ci.md` owns the contract.
- [x] **No-local-Mac smoke pipeline.** Cloud compile, package and checksum at `cc9fe46`, then
      Sideloadly signing and physical launch of smoke build `0.1.0 (1)`. Not evidence for reminders,
      same-ID upgrades or automatic refresh.
- [x] **Hub identity and first hub build.** `akshatksingh18/akshatos` with the permanent
      `com.akshatksingh18.akshatos`, history and Android preserved. Build 13 installs under that
      identity, and its picker → Squats → back navigation is in daily use.
- [x] **Module boundaries and host.** App composition owns the sole notification delegate, the hub is
      display-only, and the shared design system and feature folders are isolated and enforced by
      `check-boundaries.py`. Notifications and geofences stay at host scope with namespaced requests.
- [x] **Product constants.** New installs start with an eight-set goal (zero opts out) and a
      configurable 150-meter Home boundary; saved choices survive relaunch. Physical Home-radius
      suitability stays in the phone matrix.
- [x] **Dashboard, permissions and accessibility.** State hero with one countdown, sets and
      goal/streak cards, contextual controls and a completion-only **Your day so far**. Authoritative
      notification and location authorization with revoked-versus-denied wording, Settings routing,
      Focus/Scheduled Summary caveats, VoiceOver, Dynamic Type, Reduce Motion and Increased Contrast.
      Button interactions without vertical jumps are phone-confirmed.
- [x] **Daily lifecycle and cadence.** Validated whole-minute interval, idempotent
      Start/Pause/Resume/End, a persisted cadence anchor, and every Done — dashboard or notification —
      starting a fresh full interval. Countdown persistence across background/force-close and the
      Done reset are phone-confirmed.
- [x] **Automatic overdue nudges and idle start invitation.** One normal reminder then 59 ten-minute
      nudges with foreground replenishment, a Done/Pause category with legacy snooze payloads as
      no-ops, and one repeating 9:00 AM invitation that never auto-starts. Akshat reports both working
      in ongoing Build-13 use.
- [x] **Actions, completed sets and local day data.** After-first-unlock atomic inbox, receipts that
      survive Undo, one set per explicit Done, same-date daily history with durations and rollover,
      versioned JSON export with validated restore, and completed-history deletion. Locked-device and
      recovery acceptance stay in the matrix below.
- [x] **Goal and streak engine.** Per-date goal snapshots, at-most-once qualification, an at-risk
      current date, skipped dates as misses, prospective goal changes and deterministic
      recomputation after Undo or past-day edits.
- [x] **Opt-in Home auto-pause.** Staged authorization, one monitored circular region in protected
      storage excluded from backups, pause-source guards, outside-Home choices, visible health and
      edit/disable/delete, with no continuous tracking or movement trail.
- [x] **Foreground reconciliation.** Preferences, notification settings, pending requests, the action
      inbox, day data and the actual Home region are reconciled on launch and foreground return,
      exposing repair or degraded states instead of a false Running state.
- [x] **Logic and persistence tests.** Lifecycle, reconciliation, actions, permissions, summaries,
      goal/streak boundaries, DST and time zones, Home guards, legacy decoding and protected-data
      fallbacks are covered; `ci.md` owns the coverage description. Any future schema version must add
      its own migration tests. Simulator tests do not replace hardware tests.

### Open

- [ ] **Run the physical-iPhone matrix.** Permission allow/deny/revoke, one-minute test interval,
      dashboard/notification actions while locked and backgrounded, Start/Pause/Resume/End,
      automatic overdue nudges and legacy-snooze migration,
      foreground/background, explicit force-quit, reboot, Low Power Mode, Focus, Scheduled Summary,
      external notification-setting changes, delivery-boundary races, day summary, streak rollover,
      Home setup/entry/exit, region jitter, Background App Refresh off/on, reboot/first-unlock, missed
      event recovery, proof of no stored movement trail, and relaunch.
- [ ] **Add optional App Intents and automation guide.** Expose Start, Pause, Resume, Log set, and
      End only after the core works; prove Leave/Arrive or Focus automations, pause-source guards,
      duplicate native-plus-Shortcut callbacks, and disabled/failure behavior as backup/alternate
      triggers.
- [ ] **Produce a portable release IPA.** Build on Mac/Xcode, inspect minimal capabilities, record
      version/source/hash, and cache current plus previous known-good artifacts on Windows. Verified
      builds currently sit in per-build `Downloads` folders listed in `cloud-build.md`; durable
      current/previous release-cache promotion is still required before closing this gate.
- [ ] **Prove refresh and recovery.** The health check is installed and watching (`setup.md`); the
      refreshing itself is still unproven. Sideloadly's daemon has never been observed to refresh
      anything, so this gate needs: two unattended cycles each logged as `REFRESHED` with a new
      expiry — `setup.md` says which of the log's existing `REFRESHED` lines are test artifacts and
      must not be counted — one rehearsed USB recovery, one forced failure confirmed to alert rather than pass
      quietly, and same-bundle Wi-Fi/USB refresh preserving state — none of it by uninstalling.

## Current Android fallback gaps

- [ ] **Never built or run.** Add a Gradle wrapper, complete a clean build, and run on the fallback
      Android phone before trusting any intended behavior.
- [ ] **Running UI ignores actual delivery capability.** It reads `isRunning` without reconciling
      `POST_NOTIFICATIONS` or exact-alarm access; surface a blocked/warning state.
- [ ] **Input validation is silent.** Blank or zero input currently falls back/clamps without a
      visible error; add explicit validation feedback.
- [ ] **No verified launcher icon.** Add a proper `ic_launcher` resource if the scaffold lacks one.
- [ ] **Reboot and OEM behavior unverified.** Test exact-alarm re-arm after reboot and battery-policy
      behavior on the actual fallback device; document any required settings honestly.

## Optional ideas (not committed scope)

- Configurable repetitions per set and actual total-rep tracking.
- Streak freezes/grace days, broader achievements, deeper charts, or shareable summaries.
- Configurable nudge spacing, an optional end-of-day prompt, or a scheduled quiet window.
- Multiple saved places/geofences, multiple profiles/schedules, HealthKit, or a widget remain out of
  scope unless Akshat explicitly expands the one-purpose product after the core is reliable.

## Documentation synchronization

When an item changes product/platform behavior, notification/location permissions, streak rules, or
becomes implemented/verified, update `features.md`, `README.md`, `architecture.md`, and `CLAUDE.md`
in the same change; rewrite the item rather than appending a dated progress log.
