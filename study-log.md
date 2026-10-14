# Study Log (planned module)

**Status:** Build 1 is implemented in working source 0.13.0 (37), not yet built by CI or
phone-tested; Build 2 is planned. Akshat asked for the decisions on the agent's judgment (he will
change anything he wants later) and then for the build. `hub-plan.md` records the module; this file
is its contract, like `lift-log.md`.

## Why

Akshat measures study time with the default Windows Clock countdown set to 6:00:00 each morning. He
starts it when he sits down and pauses whenever he is not actually studying, so only real study time
counts. Six hours is an aim, not a pass/fail line. The clock keeps no record: no daily total, no
history, no way to compare days or see a week, and a forgotten pause cannot be recovered. The phone
module keeps the same feel and adds a record. The goal is more real study time, so every choice
below favours less friction while studying and an honest record afterwards.

## Decisions

1. **Main number: countdown.** Remaining time against the day's target (default 6:00:00) is the big
   number, exactly like the Windows Clock; studied time is smaller beneath it. No count-up setting
   in v1 (one fewer choice; add it only if asked). Past zero the main number reads "6:00 reached"
   and the studied time keeps counting.
2. **Forgotten pauses are the real risk, so the nudge repeats.** "Still studying?" arrives 45
   minutes after the last confirmation (Start, Resume or Keep going) and again every 45 minutes
   while the block runs, one pending request at a time. Actions:
   - **Keep going** — confirms now and re-arms the next nudge.
   - **Pause** — ends the block now.
   - **I stopped earlier** — opens Study Log on an end-time sheet, prefilled with the last
     confirmation time (the last moment known to be true) and adjustable between that and now.
   On opening the app with a block running more than 90 minutes past its last confirmation, the
   same sheet appears first, so a forgotten pause never silently inflates the day.
3. **Marks stay at 2 h and 4 h**, editable, as quiet ticks on the progress bar toward the target.
   Passing one is shown as progress only. No streaks, points, badges or completion verdicts; zero
   is a valid day.
4. **No energy tap.** It costs a tap during study, competes for the notification budget (see
   Constraints) and has no clear use for study time. Dropped from the plan; revisit only if Akshat
   asks.
5. **Study Log owns the study clock and daily totals.** The roadmap tracker keeps owning *what* was
   studied (topics, evidence, its own Record study time entries). To stop double logging, a later
   build adds a CSV of daily totals the roadmap can import; until then the roadmap's time entries
   are optional. Wiring the roadmap side is a separate roadmap change.
6. **Topic note: optional, never prompted.** A segment can carry a short free-text note, added from
   the day view afterwards; nothing asks for it during study.
7. **Day starts at 3:00 AM local.** A late session stays with its day; a segment crossing 3:00 AM is
   split there. Each day keeps the target it had, so changing the target never rewrites history.

## Screens

- **Today:** the countdown, studied time, a progress bar with the two marks and the target at its
  end, one large Start/Pause button, the current block's length, and today's blocks (start–end,
  length, note). Plain words, one accent, the shared flat cards.
- **History:** a week view (one bar per day with the marks, the week's total and daily average) and
  days grouped by month with the shared month dropdown (`shared/design-system/MonthGroup.swift`).
  Tap a day for its blocks; edit or delete a block there; Add block for study done away from the
  phone.
- **Settings:** daily target, the two marks, nudge on/off and interval, backup and restore, CSV
  export.

## Builds

- **Build 1 (implemented in 0.13.0 (37)):** the module, hub entry ("Study Log", Ready/Studying
  and today's time) and route; Start/Pause (Resume once the day has a block) with the countdown;
  today's total, the current block and today's blocks; the progress bar with the 2 h and 4 h ticks;
  history (a Monday-to-Sunday week of bars with total and average per day so far, earlier weeks by
  arrow, month-grouped days, a day's blocks); the 3:00 AM day; restoring a running block after
  relaunch or force-quit; JSON backup/restore and the hub's full backup. Target and marks are the
  defaults until Build 2 makes them editable.
- **Build 2:** the repeating nudge with its three actions and the open-app check; add, edit and
  delete blocks; editable target and marks; optional notes; CSV export.
- **Later, only if wanted:** the daily-totals CSV for the roadmap tracker; a count-up option.

## Data and edge cases

- `StudySegment`: id, start, end (nil while running), source (timer or manual), optional note, and
  `dayTarget` (the target in force when it began; the day's first block sets the day's target).
  Build 2 adds the last confirmation time for the nudge. Settings (target, marks) are one JSON value
  in the app's preferences, `studylog.settings`.
- A feature-owned, versioned SwiftData store like Lift Log and Body. The running state is the open
  segment's start timestamp, never a ticking counter, so suspension, relaunch or a killed app
  cannot lose or inflate time.
- One running block at most; Start and Pause are idempotent (double taps and duplicate notification
  callbacks change nothing). A Start never begins inside an earlier block, even with the clock set
  back. A block under five seconds is an accidental tap and is dropped on Pause. A block is stored
  whole and split at 3:00 AM when days are counted. Manual blocks (Build 2) cannot overlap other
  blocks or run into the future.
- Daylight saving and time-zone changes: totals come from absolute timestamps; only the day a block
  belongs to uses local time. Tests cover a block across 3:00 AM on a daylight-saving night.
- Backup: `study-log.json` (version 1, ISO dates, the blocks and the settings; whole-file validation
  — unique ids, no overlaps, at most one running block and it the latest — before a confirmed
  restore replaces everything). A block running at backup time comes back running. Notification
  permission is never carried.

## Constraints

- **Notification budget.** iOS keeps at most 64 pending local notifications per app and drops the
  rest silently. An active Pushups day holds 60 (`features.md`), Body's weekly reminder and Lift
  Log's inactivity reminder one each: 62. Study Log's single rolling nudge makes 63. It must never
  hold more than one pending request.
- **No app extension and no Live Activity** (free signing cannot provision them; `hub-plan.md`).
  The timer lives in the app plus local notifications; the lock screen shows only the nudge.
- **Local only:** no network, account, sync with the Windows Clock, or roadmap integration in v1.
- **Plumbing, the same as Body:** `StudyLogBackupPart` with the permanent `backupID` `studyLog`, listed
  in `FullBackupService(parts:)`; the `.studyLog` hub route and picker card; the `akshatos.study.`
  namespace mapped in `AppNotificationCoordinator` with its category (Build 2, when the nudge first
  registers one; Build 1 sends no notifications); no dependency on another
  feature (a pushup break does not pause study unless Akshat taps Pause). `check-backup-coverage.py`
  and `check-boundaries.py` must pass. Notification permission is asked only when the nudge is
  first turned on.

## Acceptance gates

- Registered domain tests (totals, countdown, 3:00 AM split including daylight saving, idempotent
  Start/Pause, restored running block, per-day target, nudge re-arm and retroactive end, manual
  edits and overlap refusal), persistence and backup/restore tests, `FullBackupTests` extended,
  and UI navigation tests, all in `ios/tests/feature-tests.json`.
- Built and tested on GitHub Actions, not locally; the usual unsigned-IPA checks apply.
- Phone acceptance by Akshat: a real study block with pause/resume, a force-quit while running, the
  locked-screen nudge and its actions (Build 2), a day rollover, and a backup restored.
- On acceptance, update `hub-plan.md`, this folder's `CLAUDE.md`, `README.md`, `handoff.md` and
  `todo.md` in place.

## For the next session

Read `CLAUDE.md`, `hub-plan.md` (module boundaries, notifications, full backup), `features.md` and
`lift-log.md` (the closest contracts) and this file. Build 2 waits on Build 1's phone pass.
