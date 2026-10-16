# Personal hub implementation

**Status:** Native source candidate 0.14.0 (38), PR #67. Compilation and domain checks have passed
an intermediate revision; the final commit still needs its complete CI Gate, native review and
testing artifact. Physical-device acceptance is separate.

## Navigation and presentation

Four persistent tabs: Today, To-do, Journal, Apps. Today owns the study countdown, selected
priorities, Park a thought and the weekly block graphic. History is one closable sheet containing
week/month inspection, block corrections, topic/time distributions, motivation and weekly review.
Apps contains PageVault, Watchlist, Spending and settings/recovery. No fitness cards or requirements
appear in the daily hub. The shared style is graphite, copper, sage and native system typography.

The dial switches remaining/studied on tap. Charts support touch selection, not hover-only access.
No demo values ship. Missing stores are unavailable, not zero. Future calendar cells are upcoming.

## Day, completion and motivation

- Activity days roll over at 03:00, weeks start Monday. Date-only task deadlines and Spending months
  use calendar dates. New study blocks retain their originating zone; old blocks retain the
  previous local-time interpretation. The activity date is explicit after midnight.
- The first study block fixes the day's aim and marks. Changes are prospective. Corrections edit
  the whole original block and its day pieces; overlaps and future durations are refused. Ten-second
  Undo stops if intervening changes would make it unsafe.
- Priorities are one to three selected unfinished tasks. All selected complete qualifies; no
  selection is unplanned. Completion and the next repeat commit together; Undo reverses both.
  Archived rows remain for historical references and never award a completion.
- A nonempty Journal entry qualifies only after an explicit successful Done save. Removing its
  writing withdraws completion. Its factual snapshot changes only on explicit refresh.
- Independent progress is the default. The optional full-day challenge combines the study mark,
  chosen priorities and Journal Done, beginning at its recorded activation day. Fitness is excluded.
  Incomplete today does not break a current streak before the day closes.
- Personal bests, prior-seven-day colours, fourteen-day momentum, study-day milestones and an
  optional twenty-more-minutes challenge use recorded time. They do not measure learning quality.

## Feature ownership

Each new feature has a versioned SwiftData schema containing one validated JSON snapshot. A mutation
updates related records in one save; failure rolls back the context and keeps the previous state.
Normal mutations refuse an unavailable store. Explicit validated restore can replace one.

- `features/todo/`: tasks, recurrence, area/note/deadline, selected priority plans, parked thoughts,
  ten-second completion Undo, local quick-date grammar, CSV and JSON recovery.
- `features/journal/`: activity-day writing/prompts, optional ratings/photos, immutable facts,
  history/search/On this day, week notes, Markdown/photo export and Journal backup.
- `features/watchlist/`: phone-created titles, imported metadata and a separate watched-event stream.
- `features/spending/`: exact integer cents, separate currencies, calendar-month totals, user-entered
  budgets, expense editing/deletion, formula-safe CSV and JSON recovery. No account integration.

Shared code owns value types, protocols, date/CSV helpers and presentation. It does not own feature
stores. App composition consumes `HubDayPart` summaries and provides cross-feature callbacks.

## Journal privacy and recovery

Journal defaults to unlocked by the confirmed user choice. Settings offers an optional lock using
device-owner authentication with device-passcode fallback. Changing that privacy setting requires
authentication; an unavailable device passcode cannot accidentally leave the Journal locked.
Writing, history, search, ratings, photos, weekly excerpts and exports all use the same access gate.
Only completion facts may leave it while locked. Inactive previews are concealed; backgrounding
relocks and invalidates an outstanding authentication attempt. Without a device passcode, the
Journal stays locked and explains recovery through device settings.

With the lock enabled, exports require authentication. Export actions warn that files are not encrypted by the screen
lock. Cancelling Journal authentication stops a full export. Missing photos stop export/restore.
Restore stages validated photo bytes locally while provider access is active, then installs them
with a recovery preimage and rolls back on save failure. Draft-save errors remain visible and
cannot mark an entry Done. Journal is never automatically sent to a linked folder.

## Full backup and notifications

The full-backup registry includes the original five modules, four new modules and personal
settings. Older backups remain valid; absent new parts leave their existing phone stores alone.
Personal settings restore keeps device-specific folder/fitness/privacy choices and disables
personal reminder opt-ins until deliberately re-enabled. A restored running study block requires
an explicit actual end before application; it cannot silently accumulate offline hours.

Personal notification reconciliation is serialized under its own namespace. It considers the actual
pending count, reserves two spare slots and schedules at most fifteen timed tasks, one running-study
check, one break reminder and one generic Journal invitation and one upcoming eligible Morning plan invitation. It preserves unrelated requests and
reports denied permission/capacity/failure. Study actions carry the running block ID, so an old
delivered notification cannot pause a newer block. The optional badge is remaining priorities.

Legacy Pushups uses 39 nudges plus its normal reminder; cancellation still cleans all 59 historical
nudge IDs. Settings provides an explicit WHOOP handover after import/photo/reminder/recovery phone
checks and no open Lift workout. It stops the old reminders/Home boundary without deleting stores.
This source path is not evidence that phone migration or WHOOP acceptance has happened.

## Shortcuts and file hand-offs

App Intents start/pause study, return today's study minutes, add a task, park a thought and open Journal. They open the ordinary
app and retain Journal authentication. No extension, App Group or cloud container is added.

An explicitly selected Files folder is a transport adapter, with manual import/export fallback.
Study exports are versioned complete snapshots of finished segments, permanent segment/source IDs,
revision/hash, originating zone, all day pieces and one whole-block rounding policy. Running IDs and explicitly already-logged DSA solve IDs
are excluded from timed imports. A per-block/default roadmap type is editable after study; receiver
review is still required, because a type label cannot deduplicate manual/problem-log time. Source identity/revision travel in Study backup. Exports never mark
curriculum complete. The roadmap receiver remains a separate, unimplemented integration.

Watchlist import previews a single writer's newer revision; replay/older/different-writer conflicts
are refused. Metadata does not overwrite phone watched events. Removal requires a tombstone;
absence never deletes. A fixed local pre-import snapshot permits metadata rollback while preserving
later watched events and phone titles. Optional checksum mismatches stop import.

Provider latency, offline/revocation/re-signing behaviour and actual laptop delivery require device
tests. File presence is not a receipt. The implementation creates no workspace data-egress exception.

## Verification boundary

`ios/tests/feature-tests.json` registers domain, persistence/recovery and UI coverage for all nine
features. Native rendering fixtures use synthetic records. GitHub Actions owns full compilation,
tests and IPA validation; no full local build is required. Face ID, notifications while locked,
upgrade preservation, Files providers and signing need the physical-device pass in `todo.md`.
