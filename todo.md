# TODO / known gaps

This is current-state work, not a claim that either platform is already usable. The iPhone path is
primary; Android remains a separate fallback scaffold. PageVault's gates live in
`pagevault/CLAUDE.md`; this file owns Pushups and hub-wide gates.

**Current focus:** User-operated signing/install and physical acceptance of delivered Build 39
(0.14.1), study-live-activity variant at `8342d0e`. Manual run `38975509228`, local checksum/payload/
version checks and delivery to the one-slot testing cache pass. The draft branch remains unmerged;
installed signing/refresh ownership is unchanged.
Build 40 (0.15.0) implements the requested Daily routine in source; exact-source CI Gate passes at
`18a59b1` (run `39122553639`), and both native accessibility fixes are scored resolved.
Phone acceptance remains open. `daily-routine-plan.md` owns the grouped default, daily snapshots, scope
and recovery contract. No Build-40 IPA is requested; the Build-39 testing cache stays intact.
Rotating desk Focus, keep-awake, quiet study notifications and the optional SideStore Live Activity
candidate are tracked in `study-display.md`; exact-source CI passes at `8342d0e`. Native inspection
at `86c4367` remains applicable to the unchanged UI source.
Build 38 (0.14.0), PR #67 at `b573ecc`, and its native accessibility fixes are included in Build 39;
the never-installed Build-38 candidate was removed from testing. Build 37 remains installed/enrolled; Build 31 remains
accepted recovery. `implementation-plan.md` owns local coverage and `cloud-build.md` exact evidence.

- [x] Build 39: exact-source cloud tests, native Focus/lock-screen content inspection and optional extension compile.
      Current full CI: run `38971711206` at `8342d0e`; native inspection at `86c4367` applies to
      the unchanged UI source. The subsequent requested release below delivers the IPA.
- [ ] SideStore/Build 39: same-ID data-preserving install, separate extension profile/launch, DND/AOD/StandBy matrix and renewals.
- [x] Windows Study Desk and additive phone exchange implemented in source: resizable countdown,
      manual Resume, lock/sleep/minimize/X pause, explicit file transport and overlap refusal.
- [x] Windows core/native/package checks at `cd17eef` (run `39412889714`): 37 core assertions,
      Pause/X/date-heading smoke and five layouts; fresh native finish review returned `ship`.
      Portable candidate hash/version checked locally. `cloud-build.md` owns its path and checksum.
- [ ] iOS CI Gate and native exchange preview/conflict finish review for the exchange addition.
      `windows/README.md` owns operation and first-version limits.
- [ ] Physical Windows/iPhone/iCloud round trip, lifecycle, same-ID re-sign and duplicate/conflict
      acceptance. No live distributed lock, cross-device edits/deletions or Build-40 IPA is implied.
- [x] Build-40 routine source: Today checklist, user-authored day groups/times/weekdays, Done/Skip,
      reversal, pause/reorder and seven-day history, in To-do's atomic snapshot and JSON recovery.
- [x] Build-40 exact-source CI, native routine/manager/editor/history inspection and finish review;
      run `39122553639` at `18a59b1`, 197 hosted and 15 UI tests, both device variants; no IPA created.
- [ ] Future Build-40 phone acceptance after a requested release: check-offs/day rollover, native
      form editing, accessibility/VoiceOver and backup restoration.
- [x] Build-39 release preparation: explicit variant selection and strict single-study-extension
      validation pass exact-source CI at `8342d0e` (run `38971711206`), with both complete built
      .app directories, arm64 checks and matching generated versions. All 18 contract tests pass.
- [x] Requested release: manual run `38975509228` passed with the study-live-activity variant;
      published checksum/payload/version were verified locally and the IPA delivered to testing.
      Keep PR #68 draft/unmerged and leave signing/installation to the user.

- [x] Final exact-commit PR/main CI Gates, native accessibility-fix review and validated Build-38 testing IPA.
- [ ] Phone: all four tabs, study Start/Pause/Focus/corrections/Undo and actual 03:00 rollover.
- [ ] Phone: tasks/repeats/priorities/Undo/parked thoughts; Journal lock/passcode, background privacy,
      photos, failed/cancelled save/export and full recovery into disposable data.
- [ ] Phone: optional reminders/badge while locked, stale actions and finite scheduling windows.
- [ ] Phone: Files linking, offline/revoked provider, stale/replayed/conflict exports and same-ID re-sign.
- [ ] User: benchmark iCloud latency and retain the standing workspace data policy; agent uploads
      remain disallowed. Build the roadmap receiver only in its separately authorized maintenance scope.
- [ ] User: verify WHOOP imports/photos/reminders/recovery, then use Settings handover to stop the
      old fitness owner. Do not delete legacy stores, assume cutover or promote an unaccepted IPA.

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

- [x] **Authorize the personal hub and selected features.** The graphite/copper four-tab design,
      day/completion defaults and reminder trim are accepted. Source 0.14.0 implements them;
      `implementation-plan.md` and `personal-hub.md` own coverage and remaining verification.
- [ ] **Phone-check retained Build-37 changes on Build 39.** Build 37 is installed/enrolled;
      Build 39 awaits signing/installation and its own enrollment. Prior feature acceptance remains open. (1) Speed menu: one Voice list, one tick; picking a
      natural speaker reads with Kokoro, picking an iPhone voice switches back; Choose voices…
      ticks natural speakers into the menu and plays their samples. (2) PageVault: hold a Want to
      read cover and drag it onto another; Move to top/bottom; the order survives relaunch.
      (3) Study Log Build 1: a real study block with Pause/Resume, the countdown and studied time,
      force-quit while running and reopen (time kept), the week view and a day's blocks, a day
      rollover at 3:00 AM, and its backup in the hub's Back up everything.
- [ ] **Verify Study Log Build 2 on the phone.** Source 0.14.0 adds the repeating study check,
      corrections/Undo, editable target/marks, topics, break clock/nudge, Focus, Shortcuts, CSV and
      versioned study export. The roadmap receiving importer remains separately unimplemented.
- [ ] **Test the natural voice (Build 36).** Akshat chose Kokoro after listening.
      The unpacked voice is already in OneDrive at `Backups\AkshatOS Voice\kokoro-int8-multi-lang-v1_0`
      (182 MB, from sherpa-onnx's `tts-models` release; outside both backup-sync pairs, so the sync
      engine leaves it alone). In PageVault's speed menu → Choose voices… → Import voice folder…,
      pick that folder in Files → OneDrive. Run **Speed test** and report the line it prints; play a sample;
      turn on **Read with the natural voice** and read a few pages: gaps between sentences, page
      turns, skip, pause, speed changes, the lock screen, battery and heat over 30 minutes. Also
      say which iPhone model it is. If it keeps up, the next step is polishing it into the default
      engine (`pagevault/neural-voice-audit.md` § Recommended path).
- [ ] **Phone-check read aloud on Build 34.** With Ava (Premium) on Build 33, Akshat found it
      good except that `genius!” This pronouncement` ran on without a pause, and the voice menu
      listed every installed voice. Build 34 drops quotation marks from what the voice is given
      (so `genius! This`), makes a long dash a comma's pause, skips footnote numbers stuck to a
      sentence's end, and lists only the voices ticked in **Choose voices…** (Enhanced and Premium
      until he chooses). Check the Grit preface line, a passage with dashes and quotes, the
      shortened menu, ticking/unticking a voice with its sample, and that report any other spot
      where the voice runs on or stumbles, with the page and sentence.
- [ ] **Phone-check flexible Lift Log workouts (Build 34).** Start a split; Add exercise and
      confirm it appears in that split; add one on the Splits screen and confirm it appears in the
      open workout; log exercises out of order and confirm each moves up in the order done; Reorder
      and drag; swipe an exercise both ways and try Remove from today versus from the split; delete
      a set from its editor; search for an exercise and log it; finish and confirm unlogged
      exercises are not saved.
- [ ] **Phone-check Lift Log's Build 33 changes.** The seated calf raise in Lower day now shows
      **Weight loaded** (all plates added together, machine excluded); its earlier plates-per-side
      sets stay in history but are not offered as its last performance. Start a workout, log a set,
      leave it an hour and confirm "Still working out?" arrives; tap it (opens Lift Log) and try
      **Finish workout** from the notification (ends the workout at its last set). It is never
      sent without notification permission, which the Pushup reminders already hold.
- [ ] **Confirm ReelVault is gone (Build 33).** The hub no longer lists ReelVault, and the space its
      videos used is freed on first launch (Settings → General → iPhone Storage → AkshatOS gets
      smaller). Pushups, PageVault, Lift Log and Body data stay as they were.
- [ ] **Watch the daemon restart path once.** The false startup warning came from the health task's
      logon run checking before the daemon had started (it starts about 40 seconds after sign-in);
      the logon trigger now waits two minutes. If the daemon is found stopped, the check now starts it
      and logs `WARN` instead of alerting. The daemon has since refreshed WHOOP unattended. Still open:
      see one real `WARN` restart in the health log, and why it stopped around 2026-09-18 is unknown.
      `setup.md` owns the detail.
- [ ] **Verify Body media completeness before authoritative migration.** `body-log.md` owns the
      current export/restore exception: unreadable JPEGs can be omitted/skipped, and the full-hub
      adapter does not forward the standalone skipped-photo warning. Confirm changed-library
      recovery and explicit missing-media handling; do not treat hub success as all photos recovered.
      The proposed WHOOP import must preview/block or obtain partial-import approval. This records
      a recovery gate, not authorization to change AkshatOS or remove Body.
- [ ] **Complete the fitness import/removal cutover separately.** WHOOP implements Pushups,
      Lift Log and Body in its installed build; its fitness/integration plans and TODO own the
      outstanding phone and recovery checks. `hub-plan.md` owns cross-project entry/reminder
      ownership. The future AkshatOS design excludes fitness features, but preserve this installed
      hub's modules, history and schedules until the import, acceptance and removal gates pass.
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
- **Selected features:** `todo-journal-plan.md` is the accepted local plan, not an ideas backlog.
  Source 0.14.0 implements its four-tab design and selected features. iCloud/provider timing,
  workspace data policy, the roadmap receiver and physical acceptance remain separate gates.
- **Unpicked ideas:** self-care checklist, interview flashcards and deadline countdowns remain
  outside the selected plan and are revisited only if asked. Do not infer their selection from
  their presence in this list or add new reminders without an approved shared budget.

## Documentation synchronization

When an item changes product/platform behavior, notification/location permissions, streak rules, or
becomes implemented/verified, update `features.md`, `README.md`, `architecture.md`, and `CLAUDE.md`
in the same change; rewrite the item rather than appending a dated progress log.
