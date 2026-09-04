# TODO / known gaps

This is current-state work, not a claim that either platform is already usable. The iPhone path is
primary; Android remains a separate fallback scaffold.

## iPhone-primary work

- [x] **Verify the expanded CI pipeline on main.** Source checks, workflow lint, feature domains,
      three SwiftData tests, hub/settings navigation, package inspection and `CI Gate` passed in
      run #7. PR/failure-path configuration still needs its first real exercise (see `ci.md`).
      Server-enforced private-repo protections
      are blocked by the current GitHub plan (HTTP 403); no upgrade or visibility change authorized.
- [x] **Separate source-module responsibilities.** App composition/sole notification delegate,
      metadata-only hub, shared design system, and isolated Squats source/test areas are implemented.
      Boundary checks, domain/navigation tests and both builds pass; build 3 IPA is downloaded and
      hash-verified. Physical verification remains pending in `cloud-build.md`.
      These remain logical modules in one target; future media implementations are not included.

Current focus: AkshatOS opens to the hub picker, then Squats. Source implementation is underway;
cloud/device evidence lives in `cloud-build.md`. Other modules stay deferred.

- [x] **Select and implement hub identity/source transition.** Evolve the existing Git repository
      into private `akshatksingh18/akshatos`; keep history and Android. AkshatOS uses
      `com.akshatksingh18.akshatos`. Physical provisioning of this identity is still a gate.
- [ ] **Accept the first hub build.** Cloud compile/tests, IPA inspection/hash, and physical
      picker → Squats → back navigation; verify reminders continue while the picker is shown.
      Cloud domain/navigation tests, both builds and downloaded IPA inspection/hash have passed;
      first physical AkshatOS install and behavior are still pending (see `cloud-build.md`).

- [x] **Prove the no-local-Mac smoke pipeline.** Cloud simulator/device compilation, packaging,
      download, and checksum passed at commit `cc9fe46`; Sideloadly signing/install and physical
      launch passed, with Akshat's screenshot showing smoke build `0.1.0 (1)`. This does not
      verify reminders, a combined hub, same-ID upgrades, or automatic refresh.
- [ ] **Promote the verified smoke artifact to a durable cache.** Preserve the Downloads IPA,
      checksum, and build metadata outside Git; choose the stable cache location before moving
      or deleting that download. No stable-cache copy has been verified yet.
- [ ] **Choose the deferred product constants before behavior acceptance.** Set the initial daily
      completed-set goal and validate a practical default Home-boundary radius on the actual phone;
      keep both configurable and do not block the initial scaffold on choosing the numbers now.
- [ ] **Build the native hub host and Squats module.** After resolving source/identity ownership,
      the target/workflow and picker/dashboard now exist in source, with reserved later modules and
      Android preserved. Finish and physically verify the hub IPA. Keep notifications/geofences at host
      scope; test actions while PDFs/reels are visible and namespace all module data/requests.

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
- [ ] **Implement foreground reconciliation.** Compare persisted SwiftData session intent, idle
      `UserDefaults` preferences, actual notification settings,
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

## First-slice source coverage (not acceptance)

Implemented source covers visual dashboard, permission/reconciliation, lifecycle, Done/Undo,
dashboard snooze, SwiftData session storage/recent session overview, and configurable goals/streaks.
The unchecked items above describe remaining full-contract implementation and acceptance, not an
instruction to create second copies of those systems. Cloud domain assertions cover event dedup,
round-trip encoding, streak threshold/aggregation/Undo/skipped dates and DST. Add service/persistence
integration tests plus physical evidence before closing the larger gates. The cloud UI test covers
picker → dashboard → back navigation and captures both screens; it does not test reminder delivery.

## Documentation synchronization

When an item changes product/platform behavior, notification/location permissions, streak rules, or
becomes implemented/verified, update `features.md`, `README.md`, `architecture.md`, and `CLAUDE.md`
in the same change; remove or rewrite the item rather than appending a dated progress log.
