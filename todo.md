# TODO / known gaps

This is current-state work, not a claim that either platform is already usable. The iPhone path is
primary; Android remains a separate fallback scaffold. PageVault's gates live in
`pagevault/CLAUDE.md`; this file owns Pushups and hub-wide gates.

**Current focus:** Build 31 (0.8.0, PR #60 at `46445c5`) is the accepted recovery/refresh build in
`../final-ipas/akshatos/backup/`. Akshat accepted the redesign, Body, full backup, month dropdowns,
editable Lift Log splits and read-aloud controls; the voice sounded robotic.
Build 32 (0.9.0, PR #61 at `eab351e`) passed PR/main CI and local artifact validation and is
installed with current-version automatic-refresh enrollment in automatic bundle-ID mode and no
error. It remains in `testing/` pending the ReelVault phone pass; its read-aloud voice is still
reported robotic. Working source 0.9.0 (33) fixes Best available to prefer voice quality across
regional variants, using the exact locale only to break a quality tie. Build 33 has not passed
cloud CI, produced an IPA or been tested on the phone.
Wait for Akshat's named Enhanced/Premium voice result, ReelVault phone findings and silent-switch
preference. Build 32 is not ready for promotion. Detailed build history belongs in `cloud-build.md`.

## iPhone-primary work

### Done

- [x] **Lift Log MVP in local source.** The hub exposes a separate local-only strength logger
      with one durable active session, editable splits in priority order (from Build 31),
      plates-per-side/per-hand/stack/added/total meanings and examples, same-mode last-performance
      references, active-set edit/undo, finished history, destructive confirmations, validated JSON
      backup/restore and load-mode-preserving CSV export. Its domain, persistence and UI suites are
      registered, and Build 27 passed complete PR and clean-main macOS CI plus local artifact
      validation. Automated verification alone did not establish phone behavior; the separate
      acceptance item below records Akshat's device result. `lift-log.md` owns the contract.

- [x] **Focused Build-27 Lift Log phone acceptance.** Akshat installed Build 27 and reports that it
      works well end-to-end. Sideloadly's database confirms its current-version enrollment at the
      expected final identity in automatic mode, and the exact artifact is promoted to backup.

- [x] **Focused Build-25 phone acceptance.** Complete macOS CI, package inspection, checksum/local
      IPA validation, same-ID Wi-Fi installation and current-version automatic-refresh enrollment
      passed. Akshat reports the installed Pushup/Homebase/PageVault presentation works perfectly;
      Build 25 is promoted to the accepted recovery/refresh slot. The broader physical matrix below
      remains separate and is not implied by this focused acceptance.

- [x] **Pushup product shift in source.** Visible Squats copy is now Pushup Reminder across the hub,
      dashboard, notifications, settings, Home permission text and backups. Legacy `Squat*`
      code/storage and `squats.*` identifiers stay unchanged to preserve upgrades. The playful
      "quest" presentation Build 25 added alongside it is superseded by 0.6.0 (29)'s minimal design.

- [x] **Cloud pipeline and repository controls.** Source, inventory and workflow checks, registered
      domain suites, hosted persistence tests, UI navigation, device build, IPA inspection and
      `CI Gate` run on every PR; real PR triggering and failure diagnostics have been exercised. The
      repository is temporarily public with strict `main` protection; `ci.md` owns the contract.
- [x] **No-local-Mac smoke pipeline.** Cloud compile, package and checksum at `cc9fe46`, then
      Sideloadly signing and physical launch of smoke build `0.1.0 (1)`. Not evidence for reminders,
      same-ID upgrades or automatic refresh.
- [x] **Hub identity and first hub build.** `akshatksingh18/akshatos` with the permanent
      `com.akshatksingh18.akshatos`, history and Android preserved. Build 13 installs under that
      identity, and its picker → Pushups → back navigation is in daily use.
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

- [ ] **Read-aloud voice still robotic on Build 32.** Build 31's voice sounded robotic and restarted
      its pitch every few words; Build 32 speaks a page as one passage. Akshat reports Build 32 still
      sounds robotic. He was told to download a Premium or Enhanced voice (Settings → Accessibility →
      Spoken Content → Voices → English) and pick it by name under Voice in the bar's speed menu.
      Next: hear back whether a Premium voice chosen by name fixes it; if not, get which voice and
      what it does (odd pauses, flat tone) before changing code. The Best available locale-selection gap is fixed in local Build 33 source: the highest
      quality across language variants wins, with the exact locale breaking a quality tie.
      Nine synthetic domain regressions are added; cloud CI, a new IPA and a phone pass remain
      pending. This does not establish that the reported robotic sound is resolved.
- [ ] **Phone-check ReelVault (Build 32).** Add videos from Photos and from Files (small and
      large, portrait and landscape), write and edit headlines in the feed and the library, swipe
      through at least two full rounds (every video once a round, never twice in a row), the video
      looping until swiped, tap to pause and resume, sound only from the video on screen and how it
      behaves with the ring switch on silent, leaving and returning to the app, removing a video,
      airplane mode after import, a ReelVault backup and restore, and Back up everything including
      it. Note memory or stutter with large videos and fast swipes.
- [ ] **Watch the daemon restart path once.** The false startup warning came from the health task's
      logon run checking before the daemon had started (it starts about 40 seconds after sign-in);
      the logon trigger now waits two minutes. If the daemon is found stopped, the check now starts it
      and logs `WARN` instead of alerting. The daemon has since refreshed WHOOP unattended. Still open:
      see one real `WARN` restart in the health log, and why it stopped around 2026-09-18 is unknown.
      `setup.md` owns the detail.
- [ ] **Move signing to a separate Apple Account.** Planned in
      `apple-account-switch.md`: new account (Akshat creates it), backups of every module and WHOOP,
      one app at a time into the new team with restore before removing the old install, then the
      health-check records and one unattended refresh. Waits for Akshat's go-ahead.
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
- [x] **Produce a portable release IPA.** Build on Mac/Xcode, inspect minimal capabilities, record
      version/source/hash — all in place via `cloud-build.md`'s workflow and `validate-ipa.py`.
      **Durable release-cache promotion is now in place too**: `../final-ipas/akshatos/backup/`
      holds the current accepted build outside Downloads, with `../testing/` for a new candidate
      awaiting its device pass; see `../final-ipas/README.md`. This is a single-current-build cache,
      not current-plus-previous — a few older builds remain as extra fallbacks in `Downloads` per
      `cloud-build.md`, kept manually rather than by this mechanism.
- [ ] **Prove refresh and recovery.** The health check is installed and watching (`setup.md`), and
      wireless refresh is now proven working once — WHOOP, 2026-09-13, unattended and corroborated,
      after fixing Bonjour and the iPhone's Private Wi-Fi Address setting; `setup.md` has the fix and
      the finding. Remaining before this gate closes: one more unattended `REFRESHED` cycle (a
      `RECORD-CHANGED` line or a fixture-run line never counts — `setup.md` explains why), one
      rehearsed USB recovery, one forced failure confirmed to alert rather than pass quietly, and
      same-bundle Wi-Fi/USB refresh preserving state — none of it by uninstalling.

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
