# Lift Log feature

Local-only strength-session logging inside AkshatOS. This module replaces the need to calculate a
machine's invented total or ask an agent to transcribe each session: Akshat records exercises and
working sets directly on the phone, using the measurement convention that matches the equipment.

**Status:** Working source version 0.4.0 (27) adds concise definitions/examples for every load mode,
hard-coded Upper/Lower templates in the confirmed priority order, same-mode last-performance
references on exercise cards and set entry, and active-set editing. It is not yet pushed,
Swift-compiled or cloud-verified.
Build 26 implemented the core feature. PR #52 is merged at `7a4f639`; main run
`35870794873` passed boundary checks, registered domain/hosted tests, simulator UI coverage,
simulator/device compilation and IPA inspection. Artifact `akshatos-ios-129` passed local checksum
and IPA validation. Same-ID installation, data preservation, backup/restore and physical-phone
usability remain unverified. No
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
  finished workout requires confirmation.
- The Upper and Lower routine names, order and default measurement modes are deliberately bundled
  in source at Akshat's explicit request. No historical performance, body measurement or private
  workout row is bundled. The most recent finished occurrence with the same normalized exercise
  name and load mode supplies a read-only last-performance reference on the active card and set form.
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
- `ios/AkshatOS/features/liftlog/ui/` — Homebase destination, active workout, set entry, history and
  recovery controls.
- `ios/tests/liftlog/main.swift`, `ios/UnitTests/LiftLogPersistenceTests.swift`, and
  `ios/UITests/LiftLogUITests.swift` — registered domain, persistence and hub-navigation coverage.

## Acceptance gates

- The exact Build-26 source passed its complete `CI Gate`, including domain tests, hosted SwiftData
  tests, simulator UI navigation, device compilation and IPA inspection. Build 27 must repeat that
  gate for measurement guidance, template order/preloading, empty-exercise cleanup, last-performance
  lookup and set editing before it replaces the retained candidate.
- On the physical phone, start a disposable workout, create exercises in every relevant load mode,
  log/undo sets, force-close and recover an active workout, finish it, reopen history, and confirm
  Dynamic Type plus keyboard behavior.
- Export JSON and CSV, inspect that per-side values remain per-side, delete disposable data, restore
  the JSON backup and confirm the complete workout returns without duplication.
- Install over the accepted same-bundle app without uninstalling. Confirm existing Pushups and
  PageVault data remain intact and Lift Log data survives a later same-ID update/refresh.
- Until those gates pass, `health/fitness/data/lift-log.csv` remains the coaching source of truth.
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
