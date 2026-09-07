# TODO / known gaps

This is current-state work, not a claim that either platform is already usable. The iPhone path is
primary; Android remains a separate fallback scaffold.

## iPhone-primary work

- [x] **Verify the expanded CI pipeline on main.** Source checks, workflow lint, feature domains,
      three SwiftData tests, hub/settings navigation, package inspection and `CI Gate` passed in
      run #7; notification-action PR #1 also passed run #10. Real PR triggering and failure-diagnostic
      download/correction are exercised (see `ci.md`).
      The repository is temporarily public for hosted macOS CI capacity. GitHub confirms `main`
      protection requiring strict/up-to-date `CI Gate`, including administrators, with force pushes
      and deletion disabled. Docs-only PRs retain the gate and skip the macOS job; see `ci.md`.
- [x] **Separate source-module responsibilities.** App composition/sole notification delegate,
      metadata-only hub, shared design system, and isolated Squats source/test areas are implemented.
      Boundary checks, domain/navigation tests and both builds pass; Build 9 is downloaded and
      hash-verified. Physical verification remains pending in `cloud-build.md`.
      These remain logical modules in one target; future media implementations are not included.

Current focus: Build 10 phone testing exposed a ten-minute countdown reset after backgrounding plus
Done leaving the unresolved nudge active. Build 11 is now on the phone, persists the snooze deadline,
makes snooze-related Done cancel it and start a fresh full interval, and adds SwiftData recreation
plus failure/retry regressions. PR #10 and main delivery run #49 passed; the downloaded Build-11 IPA
also passed local checksum/package inspection, and its countdown survives leaving and closing the app.
Finish phone acceptance and refresh/recovery; whether Build 11 was installed over Build 10 without an
uninstall has not been explicitly reported. Build 12 source now makes every successful Done restart
the full regular interval and stabilizes transient button/card geometry; PR #12 run #34073932922
passed 49 domain assertions, 63 integration/persistence tests, the UI test, both builds, IPA
inspection and `CI Gate`. PR #12 merged as `061272f`; main delivery run #53 repeated the complete
gate and its downloaded Build-12 IPA passed local checksum/package/screenshot inspection. Akshat
installed it over Build 11 without uninstalling and passed the requested cadence reset, countdown
persistence, smooth-interaction and state-preservation phone checks. The broader physical and
refresh/recovery matrix remains. Optional
Shortcuts remain follow-on work. Cloud/device evidence lives in
`cloud-build.md`; other modules stay deferred.
Build 13 source now implements the next accepted behavior: the manual snooze control/action is
removed, an ignored normal reminder is followed by 59 pre-scheduled ten-minute nudges, foreground
reconciliation replenishes the bounded batch without moving its anchor, and idle authorized state
owns one repeating 9:00 AM start invitation. PR #15 run #57 and main run #58 passed the complete
gate; the downloaded IPA passed checksum/package/screenshot inspection. Phone acceptance remains
open; Build 12 stays the installed known-good build until that gate passes.

- [x] **Select and implement hub identity/source transition.** Evolve the existing Git repository
      into `akshatksingh18/akshatos`; keep history and Android. The source is temporarily public for
      CI capacity. AkshatOS uses
      `com.akshatksingh18.akshatos`. Physical provisioning of this identity is still a gate.
- [ ] **Accept the first hub build.** Cloud compile/tests, IPA inspection/hash, and physical
      picker → Squats → back navigation; verify reminders continue while the picker is shown.
      Cloud domain/navigation tests, both builds and downloaded IPA inspection/hash have passed;
      Build 9 installation and permission prompts are confirmed, while picker/back continuity and
      the rest of the physical behavior remain pending (see `cloud-build.md`).

- [x] **Prove the no-local-Mac smoke pipeline.** Cloud simulator/device compilation, packaging,
      download, and checksum passed at commit `cc9fe46`; Sideloadly signing/install and physical
      launch passed, with Akshat's screenshot showing smoke build `0.1.0 (1)`. This does not
      verify reminders, a combined hub, same-ID upgrades, or automatic refresh.
- [x] **Retire obsolete preview artifacts.** Build 12 plus its checksum, metadata and screenshots is
      the installed current build; Build 11 is its retained predecessor and retained Builds 9 and
      4 are fallbacks. Builds 2 and 3 and the
      separate standalone smoke artifact were sent to the Windows Recycle Bin. A durable release
      cache remains part of deployment acceptance after phone verification.
- [x] **Choose the product constants before behavior acceptance.** New installs start with an
      eight-completed-set daily goal and a configurable 150-meter Home boundary. Goal zero remains
      an explicit opt-out and existing saved choices survive relaunch. Automated default/range tests
      pass; physical Home-radius suitability remains part of the phone matrix rather than the choice.
- [x] **Build the native hub host and Squats module in source.** The target/workflow and
      picker/dashboard exist with reserved later modules and Android preserved. Notifications and
      geofences remain at host scope and module data/requests are namespaced. Physical verification
      remains in the first-hub-build and device-matrix gates.

- [x] **Build the visual dashboard foundation.** Reusable colors/type/spacing/components, the state
      hero and scheduled countdown, sets-completed card, daily-goal progress/current/best streak card,
      contextual lifecycle controls, and Today timeline were already implemented. Build-7 source adds
      per-state hero icons, an automation-health-aware Home settings section, VoiceOver labels/values
      (a stable "next reminder around HH:MM" summary instead of a per-second announcement, combined
      decorative icons hidden from the accessibility tree), `@ScaledMetric` Dynamic Type scaling for
      the three fixed-size hero numerals, a Reduce-Motion-aware slower countdown tick, and an
      Increased-Contrast-aware `Surface` border. Exact source `995e11f` passed PR run #22. Build-8
      source adds an icon-based Home automation-health row on the main dashboard itself (previously a
      plain muted line) and a shared `AdaptiveRow` component that stacks every remaining label/value
      row vertically at accessibility Dynamic Type sizes instead of squeezing them; exact source
      `81bc36b` passed PR run #24.
- [x] **Deliver and physically verify the countdown-persistence correction.** Build 10 was installed
      after uninstalling Build 9, so it did not prove same-ID data preservation. It correctly makes a
      pending ten-minute deadline the main countdown and keeps **Your day so far** completion-only,
      but phone testing found that foregrounding restarts that snooze clock and Done leaves it active.
      Build 11 source persists both deadlines and makes snooze-related Done start a fresh full interval.
      PR #10 run #34067380053 and main delivery run #49 passed 49 domain assertions, 61 XCTest cases,
      the UI test, both builds, IPA inspection and `CI Gate`. Artifact `akshatos-ios-49` is downloaded
      and checksum/package-verified. Phone testing confirms the displayed countdown survives leaving
      and closing the app. Build 12 was installed over Build 11 without uninstalling; its phone tests
      confirm the snooze countdown remains persistent and Done during a snooze begins a fresh full
      interval while app state survives the same-ID update.
- [x] **Cloud- and phone-verify regular cadence reset after every completed set.** Phone testing confirms that Build 11
      leaves the existing 45-minute countdown running when Done +1 is tapped without a snooze. The
      accepted behavior is that dashboard Done and notification Done both represent a set completed
      now: record exactly one set, cancel any unresolved snooze, replace the recurring request, persist
      a new cadence anchor, and show one full configured interval (45 minutes by default). Preserve
      idempotency and retry safety; add tests for ordinary and snoozed Done, dashboard/notification
      sources, persistence failure, duplicate callbacks and foreground/relaunch. This is an accepted
      behavior change. Build 12 source `c5f787e` implements it; PR #12 run #34073932922 passed the
      complete cloud gate. PR #12 merged as `061272f`; main delivery run #53 repeated the full gate,
      and its downloaded IPA passed local inspection. Build 12 phone testing confirms Done during
      both the ordinary cadence and a pending ten-minute nudge logs the set and starts a fresh full
      interval; countdown persistence across background/force-close also remains intact.
- [x] **Cloud- and phone-verify smooth button interactions without behavior changes.** Phone testing
      reports a small vertical jump when buttons are tapped. Apply this polish consistently to every
      interactive button on the dashboard, Settings, summaries and confirmation flows—not only Done,
      snooze or lifecycle controls. The current views change several published values asynchronously
      and conditionally insert/remove the busy indicator, helper/Undo row, countdown text and controls,
      so SwiftUI recalculates card heights and the surrounding `ScrollView` shifts. Preserve stable
      card/control geometry and scroll position, and use deliberate transitions where appropriate.
      Acceptance requires no visible up/down jump for tap, working, success, failure or disabled-state
      changes. Do not alter reminder cadence, action semantics, persistence, navigation, permissions,
      accessibility behavior or any other functionality while making this presentation-only change.
      Build 12 source `c5f787e` reserves stable busy/reminder/control/helper geometry, animates state
      transitions with Reduce Motion respected, and keeps hidden controls out of hit testing and
      accessibility. PR #12 run #34073932922 and main delivery run #53 passed compilation and UI
      evidence, and the downloaded IPA screenshots passed visual inspection. Build 12 phone testing
      confirms button interactions are smooth without the reported vertical jump and the associated
      cadence/persistence behavior remains correct.
- [x] **Implement permission/status UI.** Build-7 source replaces the boolean notification-allowed
      flag and fragile Home-health string matching with authoritative `NotificationAuthorization`
      (not-determined/authorized/provisional/ephemeral/denied) and `HomeAuthorization` (not-determined/
      when-in-use/always/denied/restricted) enums tracked on `SquatStore`, adds a dedicated Settings
      "Notifications" section covering every status plus Focus/Scheduled Summary/banner caveats, gives
      Home auto-pause distinct denied/restricted/when-in-use explanations, and routes blocking alerts
      to the correct Settings screen via a `SettingsRoute` rather than showing a bare OK button. Never
      displays a false Running state. Exact source `995e11f` passed PR run #22. Build-8 source adds a
      monotonic, UserDefaults-backed `notificationEverAuthorized`/`homeEverAuthorized` flag so a later
      denial is phrased as a revocation ("turned off") instead of reusing first-request wording.
      Correction source `d80653d` records provisional/alerts-disabled notification grants and When
      In Use location grants, and proves both flags plus wording survive store recreation; run #27 passed.
- [ ] **Verify Build 13 automatic overdue nudges end to end.** Source schedules one normal reminder
      followed by 59 ten-minute nudges, shows the nudge as the single main countdown after the normal
      deadline, replenishes a low/drained batch from the persisted anchor, and makes Done/Pause/End
      cancel the old batch. Done starts a fresh full interval. The manual snooze UI/category is gone;
      legacy snooze payloads remain decode-safe no-ops. Pass PR/main CI, inspect the IPA/screenshots,
      then verify ignored delivery, repeated delivery, Done and Pause on the physical phone. PR/main
      CI and IPA/screenshot inspection are complete; only the phone portion remains.
- [ ] **Verify the idle 9:00 AM start invitation end to end.** Source schedules exactly one repeating
      local 9:00 AM notification while no day is active and access exists, cancels it on Start, restores
      it after End, and never auto-starts from a tap. Pass automated/cloud checks, then verify actual
      delivery, tap-to-open, active-day suppression and time-zone behavior on the phone. Automated/
      cloud and artifact checks are complete; physical delivery behavior remains.
- [x] **Implement the daily lifecycle.** Validate whole minutes (default 45, minimum one), use a
      bounded normal-plus-nudge batch, and make Start/Pause/Resume/End idempotent. Pause keeps the active
      day, Resume starts a fresh interval, and End cancels active requests and finalizes it.
- [x] **Implement actionable notifications and legacy-safe migration.** Register Done then Pause,
      route them through shared commands, retire manual snooze without breaking old payload decoding,
      and handle locked-device persistence and callback deadlines safely.
      Source now includes ordered categories, a shared command path, after-first-unlock atomic inbox,
      delivery receipts that survive Undo, busy-action draining, protected-store retry and matching
      Pause cancellation. The action suite passed exact-source CI in run #10; physical
      locked/force-quit/deadline acceptance remains open in `ci.md` and `cloud-build.md`.
- [x] **Implement completed-set tracking.** Record one timestamped set per explicit Done action,
      deduplicate callbacks, offer Undo, and never infer reps or notification-delivery counts.
- [x] **Implement local day data and overview.** Add versioned session/event persistence, pause
      segments, snooze events, Today timeline, End-my-day summary, lightweight daily history, local
      midnight/time-zone handling, migration coverage, and explicit history deletion.
      Build-5 source now groups same-date sessions, derives active/paused duration and event detail,
      closes stale days at the next local calendar boundary on foreground, and provides versioned
      JSON export/validated restore plus completed-history deletion. Exact-source CI passed in
      PR run #14; physical recovery acceptance remains open.
- [x] **Implement the daily goal and streak engine.** Store the goal used for each local date, qualify
      at most once from explicit non-undone Done events, derive current/best streak, keep the current
      date at risk until rollover, treat skipped post-activation dates as missed, apply goal changes
      prospectively, and recompute safely after Undo or past-day edits.
      Build-6 source adds same-day goal-change, pre-activation neutral-date, future-clock-date and
      Home-independent streak regression cases; exact-source cloud tests pass and physical calendar
      acceptance remains open.
- [x] **Implement opt-in Home auto-pause.** Add explanatory staged When In Use → Always authorization,
      one-shot Home selection plus map/radius confirmation, one stable monitored circular region,
      protected this-device-only boundary storage, pause-reason guards, duplicate/jitter handling,
      deliberate-pause precedence, outside-Home Start/Resume handling, launch reconciliation, visible
      automation health, and edit/disable/delete. Never continuously track location or persist a
      movement trail.
      Build-6 source implements this contract without continuous background-location mode and keeps
      Home coordinates out of device backups and backup exports. Exact-source cloud tests pass; physical geofence
      acceptance remains open.
- [x] **Implement foreground reconciliation.** Compare persisted SwiftData session intent, idle
      `UserDefaults` preferences, actual notification settings,
      recurring/snooze requests, pending action inbox, day data, and Home-region configuration on
      launch/foreground return; cancel stale requests and expose reminder or geofence repair/degraded
      states. Exact source `8c1cc96` canonicalizes invalid idle settings, removes foreign/malformed
      snoozes without moving a healthy cadence, requires a usable matching recurring request, and
      compares/replaces the actual system Home circle while resetting stale presence. Run #32 passed
      37 domain assertions, 45 integration/persistence tests, one UI test, both builds, IPA inspection
      and `CI Gate`; PR #1 merged it to `main`.
- [x] **Add logic and persistence tests.** Cover lifecycle transitions, interval validation, state
      reconciliation, action deduplication, permission transitions, snooze replacement, summary
      derivation, goal/streak boundaries, skipped dates, same-day sessions, Undo/past edits,
      prospective goal changes, day/DST/time-zone boundaries, geofence pause-source guards and
      duplicate events, migrations, and protected-data fallback. Simulator tests do not replace
      hardware tests. Build-9 source expands the suite to 47 domain assertions, 55 integration/
      persistence tests and one UI test, including chosen defaults, idempotent lifecycle, schedule-
      failure recovery, exact request repair, stale-request/snooze cleanup, alerts-disabled handling,
      Home degraded/disable paths, spring/fall DST and time-zone ownership. Current-schema legacy
      decoding, malformed payloads, atomic replacement and protected-data fallbacks remain covered;
      any future schema version must add its own migration tests. Exact Build-9 source/documentation
      head passed PR #4 run #37; physical acceptance remains pending.
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
      Build 10 passed main delivery run #43, is downloaded with matching checksum/package checks and
      is installed; retained Builds 9 and 4 are fallbacks. Its phone-reported snooze defects require
      Build 11 before physical acceptance and durable current/previous release-cache promotion, so
      Build 10 is not a known-good release.
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
dashboard/notification snooze, durable notification Done/Pause actions, SwiftData session storage/recent session overview, and configurable goals/streaks.
The unchecked items above describe remaining full-contract implementation and acceptance, not an
instruction to create second copies of those systems. Cloud domain assertions cover event dedup,
round-trip encoding, streak threshold/aggregation/Undo/skipped dates and DST. Action service/persistence
integration tests now pass; remaining full-contract scenarios and physical evidence are required
before closing the larger gates. The cloud UI test covers
picker → dashboard → back navigation and captures both screens; it does not test reminder delivery.
Build-7 source adds five integration tests covering notification/Home authorization tracking and
`SettingsRoute` message routing (37 domain assertions, 39 integration/persistence tests, one UI test
in the registered suite) plus one new UI-test assertion for the Notifications settings section;
exact source `995e11fd64e074eb7810f0ab1b8acfe47eee9866` passed PR run #22. Build-8 source adds two
more integration tests covering the revoked-vs-denied wording for both notification and Home
authorization (37 domain assertions, 41 integration/persistence tests, one UI test). Correction source
`d80653da39433815c1d12fb9470adb9417a6f819` strengthens those same tests across store recreation,
fixes their grant semantics, and verifies Home backup exclusion; PR run #27 passed.
Foreground-reconciliation source `8c1cc96` adds four integration tests for persisted preference
repair, valid/foreign snooze handling, and mismatched Home-boundary replacement. PR run #32 passed
37 domain assertions, 45 integration/persistence tests and one UI test before PR #1 merged.
Build-9 application source `e999ed2` adds ten integration tests and ten domain assertions across
defaults, lifecycle, repair, permissions, snooze cleanup, Home degradation/disable, DST/time-zone
and recovery behavior; it also extends the UI test over the chosen goal and permission/Home status.

## Documentation synchronization

When an item changes product/platform behavior, notification/location permissions, streak rules, or
becomes implemented/verified, update `features.md`, `README.md`, `architecture.md`, and `CLAUDE.md`
in the same change; remove or rewrite the item rather than appending a dated progress log.
