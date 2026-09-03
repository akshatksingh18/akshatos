# TODO / known gaps

This is current-state work, not a claim that either platform is already usable. The iPhone path is
primary; Android remains a separate fallback scaffold.

## iPhone-primary work

- [ ] **Finish activation inputs.** The candidate bundle ID is
      `com.akshatksingh18.squatreminder` and GitHub Actions macOS/Xcode is the accepted primary build
      path. Confirm the signing Apple Account/team, stable Windows IPA-cache/backup locations, and
      refresh-alert method before the smoke artifact becomes a daily-use app.
- [ ] **Prove the no-local-Mac smoke pipeline.** Regenerate the Xcode project from `ios/project.yml`,
      pass simulator and unsigned-device builds, download and verify the SHA-256 artifact, sign/install
      over USB with Sideloadly, and open smoke build `0.1.0 (1)` on the physical iPhone. The cloud,
      packaging, download, and checksum stages pass at commit `cc9fe46`, and Sideloadly is installed;
      Apple personal signing, USB installation, and physical launch remain. Preserve failure logs
      rather than treating a green compile alone as success.
- [ ] **Choose the deferred product constants before behavior acceptance.** Set the initial daily
      completed-set goal and validate a practical default Home-boundary radius on the actual phone;
      keep both configurable and do not block the initial scaffold on choosing the numbers now.
- [ ] **Promote the SwiftUI smoke target into the product target.** After the cloud/phone proof,
      preserve the Android module and permanent iOS identity while replacing the static screen with
      the real app. Keep one target with no extensions or unnecessary entitlements; add honest
      notification and location usage descriptions only when their setup flows exist.
- [ ] **Build the visual dashboard foundation.** Add reusable colors/type/spacing/components, the
      state hero and scheduled countdown, sets-completed card, daily-goal progress/current/best streak
      card, contextual lifecycle controls, Today timeline, automation-health surface, accessibility
      labels, Dynamic Type, contrast, and Reduce Motion behavior.
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
- [ ] **Implement the daily goal and streak engine.** Store the goal used for each local date, qualify
      at most once from explicit non-undone Done events, derive current/best streak, keep the current
      date at risk until rollover, treat skipped post-activation dates as missed, apply goal changes
      prospectively, and recompute safely after Undo or past-day edits.
- [ ] **Implement opt-in Home auto-pause.** Add explanatory staged When In Use → Always authorization,
      one-shot Home selection plus map/radius confirmation, one stable monitored circular region,
      protected this-device-only boundary storage, pause-reason guards, duplicate/jitter handling,
      deliberate-pause precedence, outside-Home Start/Resume handling, launch reconciliation, visible
      automation health, and edit/disable/delete. Never continuously track location or persist a
      movement trail.
- [ ] **Implement foreground reconciliation.** Compare `UserDefaults`, actual notification settings,
      recurring/snooze requests, pending action inbox, day data, and Home-region configuration on
      launch/foreground return; cancel stale requests and expose reminder or geofence repair/degraded
      states.
- [ ] **Add logic and persistence tests.** Cover lifecycle transitions, interval validation, state
      reconciliation, action deduplication, permission transitions, snooze replacement, summary
      derivation, goal/streak boundaries, skipped dates, same-day sessions, Undo/past edits,
      prospective goal changes, day/DST/time-zone boundaries, geofence pause-source guards and
      duplicate events, migrations, and protected-data fallback. Simulator tests do not replace
      hardware tests.
- [ ] **Run the physical-iPhone matrix.** Permission allow/deny/revoke, one-minute test interval,
      dashboard/notification actions while locked and backgrounded, Start/Pause/Resume/End, snooze,
      foreground/background, explicit force-quit, reboot, Low Power Mode, Focus, Scheduled Summary,
      external notification-setting changes, delivery-boundary races, day summary, streak rollover,
      Home setup/entry/exit, region jitter, Background App Refresh off/on, reboot/first-unlock, missed
      event recovery, proof of no stored movement trail, and relaunch.
- [ ] **Add optional App Intents and automation guide.** Expose Start, Pause, Resume, Log set, and
      End only after the core works; prove Leave/Arrive or Focus automations, pause-source guards,
      duplicate native-plus-Shortcut callbacks, and disabled/failure behavior as backup/alternate
      triggers.
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
- Streak freezes/grace days, broader achievements, deeper charts, or shareable summaries.
- More snooze durations, an optional end-of-day prompt, or scheduled quiet window.
- Multiple saved places/geofences, multiple profiles/schedules, HealthKit, or a widget remain out of
  scope unless Akshat explicitly expands the one-purpose product after the core is reliable.

## Documentation synchronization

When an item changes product/platform behavior, notification/location permissions, streak rules, or
becomes implemented/verified, update `features.md`, `README.md`, `architecture.md`, and `CLAUDE.md`
in the same change; remove or rewrite the item rather than appending a dated progress log.
