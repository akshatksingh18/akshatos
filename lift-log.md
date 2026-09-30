# Lift Log feature

Local-only strength-session logging inside AkshatOS. This module replaces the need to calculate a
machine's invented total or ask an agent to transcribe each session: Akshat records exercises and
working sets directly on the phone, using the measurement convention that matches the equipment.

**Status:** Version 0.4.0 (27) adds concise definitions/examples for every load mode,
hard-coded Upper/Lower templates in the confirmed priority order, same-mode last-performance
references on exercise cards and set entry, and active-set editing. PR #54 merged at `ebb44d3`;
main run `35925770220` passed boundary checks, registered domain/hosted tests, simulator UI coverage,
simulator/device compilation and IPA inspection. Artifact `akshatos-ios-133` passed local checksum
and IPA validation. Akshat installed Build 27 and reports that it works well end-to-end, closing the
focused physical-phone behavior pass. Sideloadly confirms current-version automatic-refresh
enrollment at the expected final identity in automatic mode, with no error and a seven-day expiry;
Build 27 is promoted to the accepted backup slot. Build 26 implemented the core feature and is
superseded. Working source 0.5.1 (29) moves history to its own screen holding every finished
workout and shows every set of the last performance instead of "+N more"; it awaits CI and a
phone pass. No
private workout history is bundled in source or authorized for the repository's current public
remote.

## Product contract

- One active workout at a time. Start asks for Upper or Lower and immediately creates a durable
  session containing every exercise in the confirmed highest-to-lowest priority order. Exercises
  left empty because time ran out disappear when the session finishes; every performed set remains.
  Each mutation saves the full workout before the UI claims success, so relaunch can recover an
  unfinished session.
- **Plates per side** is the default measurement. A recorded `42.5 lb/side` remains exactly that. The
  UI may show `85 lb added plates`, but it never silently adds a bar, machine resistance,
  sled, lever arm or cable ratio.
- Each exercise chooses and retains one explicit load meaning: plates per side, weight per hand,
  stack setting, added bodyweight load, or known total weight. An optional equipment note identifies
  the actual machine or records that its base resistance is unknown.
- Each working set records its load, repetitions and completion time. Any active set can be edited;
  the active session also supports undoing the most recent set per exercise, finishing after at
  least one set, or discarding the entire active workout with confirmation.
- Finished history shows every exercise and set using its original measurement meaning. Deleting a
  finished workout requires confirmation. The Lift Log screen carries one **History** row with the
  session count; it opens its own screen listing **every** finished workout by month, newest first,
  in a lazy list. (Until 0.5.1 (29) the main screen listed only the latest 12, which left older
  workouts unreachable in the app.) History is kept indefinitely: a workout's record is estimated at a
  few kilobytes from its shape (not measured), so years of sessions stay small, and nothing is pruned
  automatically.
- The Upper and Lower routine names, order and default measurement modes are deliberately bundled
  in source at Akshat's explicit request. No historical performance, body measurement or private
  workout row is bundled. The most recent finished occurrence with the same normalized exercise
  name and load mode supplies a read-only last-performance reference on the active card and set form.
  It lists every set of that performance (`S1 50 lb/hand × 10 · … · S4 55 lb/hand × 6`), wrapping
  as needed; the card no longer truncates to three sets with "+N more".
- Data stays in a feature-owned, versioned SwiftData store. There is no account, HealthKit write,
  analytics, cloud sync or server.
- JSON export is the restorable full backup. Restore validates the complete versioned payload and
  asks before replacing current Lift Log data. CSV export provides a transparent row per set for
  personal analysis or later workspace import; it includes the load mode so `42.5 lb/side` cannot
  be mistaken for a 42.5 lb total.

## Current source layout

- `ios/AkshatOS/features/liftlog/domain/LiftWorkout.swift` — pure workout, exercise, set, load-mode,
  Upper/Lower template, validation and backup contract.
- `ios/AkshatOS/features/liftlog/data/` — feature-owned SwiftData schema and repository.
- `ios/AkshatOS/features/liftlog/LiftLogStore.swift` — save-before-publish commands, active-session
  recovery, JSON backup/restore and CSV export.
- `ios/AkshatOS/features/liftlog/ui/` — hub destination, active workout, set entry and
  recovery controls (`LiftLogView.swift`), and the month-grouped history screen with workout detail
  (`LiftLogHistoryView.swift`).
- `ios/tests/liftlog/main.swift`, `ios/UnitTests/LiftLogPersistenceTests.swift`, and
  `ios/UITests/LiftLogUITests.swift` — registered domain, persistence and hub-navigation coverage.

## Acceptance gates

- The exact Build-27 source passed its complete PR and clean-main `CI Gate`, including domain tests,
  hosted SwiftData tests, simulator UI navigation, device compilation and IPA inspection. Its local
  artifact also passed checksum and IPA validation.
- Akshat reports the installed Build 27 works well end-to-end on the physical phone. This closes the
  focused Lift Log behavior pass without inventing a more granular checklist than was reported.
- Current-version automatic-refresh enrollment for the expected signed identity and automatic mode
  is confirmed; Build 27 is the accepted backup artifact.
- Until Akshat explicitly activates the source-of-truth switch, `health/fitness/data/lift-log.csv`
  remains the coaching source of truth.
  After activation, phone entries become primary for new sessions only when Akshat explicitly
  confirms the switch; CSV export is the bridge back to workspace analysis. Existing private rows
  are not copied into a public source repository.

## Deliberately deferred

- Importing the historical workspace CSV, because older rows mix true totals, plate loads and
  unknown machine resistance; automatic conversion would fabricate precision.
- Editing finished sets, customizable templates/programming, rest timers, RIR/RPE, automatic
  progression advice, personal records, charts, HealthKit, social/sharing features and cloud sync.
  These require separate product decisions after the core logger and recovery path pass on-device.

## Working agreement

- Preserve the recorded load mode as data, not display formatting. Never rewrite per-side entries
  into guessed totals.
- Keep real workout performance data out of source, fixtures, logs, screenshots and the public
  repository. The explicitly authorized routine definition contains names/order/modes only; tests
  use synthetic performance values.
- Every schema change after the first installed Lift Log build requires an explicit migration and
  same-ID upgrade test. Never reset the store to make a migration pass.
- Update this file, the hub contract, architecture, README, TODO and build evidence when implemented
  or verified state changes.
