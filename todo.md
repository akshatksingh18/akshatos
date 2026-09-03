# TODO / known gaps

This is current-state work, not a claim that either platform is already usable. The iPhone path is
primary; Android remains a separate fallback scaffold.

## iPhone-primary work

- [ ] **Choose activation inputs.** Confirm the permanent unique bundle ID, Apple Account/team,
      compatible Mac/Xcode build path, Windows IPA-cache/backup locations, and refresh-alert method.
- [ ] **Create the separate SwiftUI target.** Keep the Android module intact and add one minimal iOS
      application target with no extensions or unnecessary entitlements.
- [ ] **Build the visual dashboard foundation.** Add reusable colors/type/spacing/components, the
      state hero and scheduled countdown, sets-completed card, contextual lifecycle controls, Today
      timeline, accessibility labels, Dynamic Type, contrast, and Reduce Motion behavior.
- [ ] **Implement permission/status UI.** Cover not-determined, authorized, denied, later-revoked,
      Focus/Summary caveats, and the Settings route without displaying a false Running state.
- [ ] **Implement the daily lifecycle.** Validate whole minutes (default 45, minimum one), use one
      stable recurring request ID, and make Start/Pause/Resume/End idempotent. Pause keeps the active
      day, Resume starts a fresh interval, and End cancels all project requests and finalizes it.
- [ ] **Implement actionable notifications and snooze.** Register Done, Pause, and Remind me in 10
      min in that priority order; route them through shared commands; allow only one stable one-off
      snooze; and handle locked-device persistence and callback deadlines safely.
- [ ] **Implement completed-set tracking.** Record one timestamped set per explicit Done action,
      deduplicate callbacks, offer Undo, and never infer reps or notification-delivery counts.
- [ ] **Implement local day data and overview.** Add versioned session/event persistence, pause
      segments, snooze events, Today timeline, End-my-day summary, lightweight daily history, local
      midnight/time-zone handling, migration coverage, and explicit history deletion.
- [ ] **Implement foreground reconciliation.** Compare `UserDefaults`, actual notification settings,
      recurring/snooze requests, pending action inbox, and day data on launch/foreground return;
      cancel stale requests and expose missing/wrong-request repair.
- [ ] **Add logic and persistence tests.** Cover lifecycle transitions, interval validation, state
      reconciliation, action deduplication, permission transitions, snooze replacement, summary
      derivation, day boundaries, migrations, and protected-data fallback. Simulator tests do not
      replace hardware tests.
- [ ] **Run the physical-iPhone matrix.** Permission allow/deny/revoke, one-minute test interval,
      dashboard/notification actions while locked and backgrounded, Start/Pause/Resume/End, snooze,
      foreground/background, explicit force-quit, reboot, Low Power Mode, Focus, Scheduled Summary,
      external notification-setting changes, delivery-boundary races, day summary, and relaunch.
- [ ] **Add optional App Intents and automation guide.** Expose Start, Pause, Resume, Log set, and
      End only after the core works; prove Leave/Arrive or Focus automations, pause-source guards,
      disabled/failure behavior, and no native location permission.
- [ ] **Produce a portable release IPA.** Build on Mac/Xcode, inspect minimal capabilities, record
      version/source/hash, and cache current plus previous known-good artifacts on Windows.
- [ ] **Prove refresh and recovery.** Install with Sideloadly/Local Anisette, verify same-bundle Wi-Fi
      and USB refresh preserves state/reconciliation, exercise early alerts and expired-profile
      recovery, and pass multiple cycles without uninstalling.

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
- Daily set goals, streaks, achievements, deeper charts, or shareable summaries.
- More snooze durations, an optional end-of-day prompt, or scheduled quiet window.
- Native geofencing, multiple profiles/schedules, HealthKit, or a widget remain out of scope unless
  Akshat explicitly expands the one-purpose product after the core is reliable.

## Documentation synchronization

When an item changes product/platform behavior or becomes implemented/verified, update
`features.md`, `README.md`, `architecture.md`, and `CLAUDE.md` in the same change; remove or rewrite
the item rather than appending a dated progress log.
