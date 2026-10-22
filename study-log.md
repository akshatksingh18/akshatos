# Study Log

Build 39 (0.14.1) is delivered as the requested combined Live Activity testing IPA;
manual release run `38975509228` at `8342d0e` and local checksum/payload/version checks pass. Rotating desk Focus,
scoped keep-awake, quiet study notifications and the optional SideStore Live Activity candidate are
implemented with full cloud verification at `8342d0e` (draft PR #68). Native inspection at
`86c4367` remains applicable to the unchanged UI source; release selection/validation is also complete.
`study-display.md` owns exact evidence and the DND/signing/device gates.
Build 39 includes the Build-38 personal-hub scope below and replaces its testing candidate.

**Status:** Build 39 (0.14.1), Live Activity variant at `8342d0e`, is validated in `testing/` after
manual release CI and local artifact checks. It includes the authorized Build-2
scope on Today: Focus, corrections/Undo, topics, target/marks, history, motivation, optional reminders
and versioned exports. Build 37 remains installed/enrolled. Study/provider/Shortcuts phone checks
and the separately unimplemented roadmap receiver remain open (`personal-hub.md`, `todo.md`).

## Why

Akshat measures study time with the default Windows Clock countdown set to 6:00:00 each morning. He
starts it when he sits down and pauses whenever he is not actually studying, so only real study time
counts. Six hours is an aim, not a pass/fail line. The clock keeps no record: no daily total, no
history, no way to compare days or see a week, and a forgotten pause cannot be recovered. The phone
module keeps the same feel and adds a record. The goal is more real study time, so every choice
below favours less friction while studying and an honest record afterwards.

## Decisions

The laptop companion is implemented in source under `windows/`, with remaining time primary,
studied time below, readable resizable text and optional pinning. Lock/sleep/minimize/X pause;
resume is manual. The confirmed decisions and physical gates are in local `desktop-study-plan.md`;
`windows/README.md` owns the technical operation/exchange contract. Build-40 source imports closed
laptop sessions through an additive preview and exports phone-owned sessions in a separate format.
The Windows candidate passes cloud checks and native finish review; current full iOS CI passes at
`c798a2c` and the phone's requested conflict-copy fix is scored resolved (`cloud-build.md`). Physical
Windows/iPhone/provider acceptance remains open. Existing roadmap export remains separate; backup restore still
replaces data and must never be used as a merge. The delivered Build-39 IPA lacks the new importer.

1. **Main number: countdown.** Remaining time against the day's target (default 6:00:00) is the big
   number, exactly like the Windows Clock; studied time is smaller beneath it. No count-up setting
   in v1 (one fewer choice; add it only if asked). Past zero the main number reads "6:00 reached"
   and the studied time keeps counting.
2. **Forgotten pauses are the real risk, so the nudge repeats.** "Still studying?" arrives 45
   minutes after the last confirmation (Start, Resume or Keep going) and again every 45 minutes
   while the block runs, using one repeating interval request reset by those actions. Delivery
   alone is not a background callback to re-arm a one-shot request. Actions:
   - **Keep going** — confirms now and re-arms the next nudge.
   - **Pause** — ends the block now.
   - **I stopped earlier** — opens Study Log on an end-time sheet, prefilled with the last
     confirmation time as a suggestion, adjustable back to the block's start and forward to now.
     A confirmation records a tap, not proof of uninterrupted studying or the true stop time.
   On opening the app with a block running more than 90 minutes past its last confirmation, the
   same sheet appears first, so an unresolved long block is visible for correction rather than
   presented as independently verified effective study time.
3. **Marks stay at 2 h and 4 h**, editable, as ticks on the progress bar toward the target. Zero is
   a valid day, never shown as a failure. Akshat welcomes motivating mechanics that help him study
   more (he rejected themed decoration, not game-like motivation), so Build 3 candidates include a
   study streak and personal bests; they are shown plainly, in the hub's normal style.
4. **No energy tap.** It costs a tap during study, competes for the notification budget (see
   Constraints) and has no clear use for study time. Dropped from the plan; revisit only if Akshat
   asks.
5. **Study Log owns how long; the roadmap owns what.** Akshat agreed: the timer is the honest
   record of hours, and the AI/ML roadmap tracker (`../../roadmap/`) keeps its study types, notes,
   weekly budget bars and review. Build 2 prepares a one-way file hand-off (the phone has no network and the roadmap is a local
   laptop app): blocks carry an optional roadmap type and Study Log exports a sessions file. The
   roadmap receiving importer is separately unimplemented; it must reconcile without duplicates. The
   roadmap's own Record study time stays for anything not timed on the phone. Until Build 2,
   entering time in the roadmap is optional.
6. **Topic note: optional, never prompted.** A segment can carry a short free-text note, added from
   the day view afterwards; nothing asks for it during study.
7. **Day starts at 3:00 AM local.** A late session stays with its day; a segment crossing 3:00 AM is
   split there. Each day keeps the target it had, so changing the target never rewrites history.

The accepted day is 03:00 for Study and priorities. Calendar deadlines remain distinct.
New blocks retain their originating zone and saved aim/marks; older blocks retain their previous
local-time interpretation. A historical attribution migration would require a separate preview.

## Screens

Source 0.14.0 puts study on Today, with an optional Focus screen and one closable History sheet.
Week/month inspection, corrections, topics, recorded time distribution, momentum, milestones and
weekly review live there. Settings owns target/marks, default roadmap type, CSV and backup. The
approved graphite/copper design is in `todo-journal-plan.md`; native details are in `personal-hub.md`.

## Builds

- **Build 1 (implemented in 0.13.0 (37)):** the module, hub entry ("Study Log", Ready/Studying
  and today's time) and route; Start/Pause (Resume once the day has a block) with the countdown;
  today's total, the current block and today's blocks; the progress bar with the 2 h and 4 h ticks;
  history (a Monday-to-Sunday week of bars with total and average per day so far, earlier weeks by
  arrow, month-grouped days, a day's blocks); the 3:00 AM day; restoring a running block after
  relaunch or force-quit; JSON backup/restore and the hub's full backup. Target and marks were fixed defaults in Build 1; source 0.14.0 makes them prospectively editable.
- **Build 2 (implemented in source 0.14.0, cloud verified; phone acceptance pending):**
  - **Forgotten pauses:** the repeating "Still studying?" nudge with Keep going and Pause; the app provides Stopped earlier and the open-app check (Decision 2).
  - **Corrections:** add, edit and delete blocks (manual blocks for laptop study; no overlaps, none
    in the future); **Undo** for ten seconds after Start or Pause, so a mistaken tap is one tap to
    reverse.
  - **Settings:** editable daily target and marks; nudge on/off and interval.
  - **Roadmap bridge** (Decision 5):
    - Each block can carry a roadmap type, matching the roadmap's recorder: main/project, SQL, DSA
      lesson/Mixed practice, or other. It is set afterwards from the day view (with the optional
      note) and never asked for on Pause; legacy untagged blocks need receiver review. Settings has a default type
      (main/project to start with) applied to new blocks.
    - **Export for roadmap** writes `study-sessions.json`: version, and per block its permanent id,
      study date, start, whole minutes, type and note. A file picked/moved by Akshat is the baseline;
      an explicit Files-folder export is implemented, with provider measurement and device proof still
      open (`laptop-phone-sync.md`). No automatic Journal export or agent cloud write is enabled.
    - The separately gated roadmap receiver must gain **Import study sessions** (a roadmap change, `roadmap/support/roadmap-guide.md`):
      preview, then ordinary study entries; a block already imported is skipped by its id, and an
      edited block updates its entry rather than adding another.
    - **No double DSA time:** the roadmap counts solve time from its problem logs. Only actual DSA
      lesson/Mixed time may become separate study entries; a solve block must not be relabelled
      as a lesson to import it. Preview already-recorded/problem-linked time and exclude it or
      reconcile it explicitly before accepting the bridge. A type label alone cannot deduplicate
      manually entered time; `laptop-phone-sync.md` owns the proposed reconciliation contract.
  - **Breaks:** while paused on a day that has study, Today shows how long the break has run
    ("Break 0:12"). An optional **Back to it?** reminder (off by default; 15 minutes initially) fires
    once per break, only before the day's target is reached.
  - **Morning start (optional, off by default):** one upcoming eligible invitation at a chosen time when that study day has not started, refreshed
    on app activity. It is a finite next-occurrence schedule, not an unlimited closed-app promise.
  - **Shortcuts:** App Intents in the app itself (no extension) for Start studying, Pause studying
    and Study time today, so the Action Button, Siri or a Focus automation ("when the Study Focus
    turns on, start") can drive the timer. They use the same idempotent commands as the button.
  - **Notes and CSV:** optional per-block notes; a plain CSV export of blocks.
- **Wanted by Akshat for Build 2/3** (`todo-journal-plan.md` §7): a **Focus screen** while a block
  runs, **study topics** per block with weekly hours per topic, and **When you study** (picked as
  "When you study best"; timing records establish distribution, not learning quality).
- **Build 3 (candidates, only if Akshat wants them after using Build 2):** a **study streak**
  (consecutive days reaching the 2 h mark, with current and best, like Pushups' goal streak) and
  **personal bests** (longest day, longest block, best week); a weekday target (for example lighter
  weekends); this week against last week; a count-up option. Study-by-hour over four weeks is
  already wanted above, not an unselected candidate. Comparison baseline and insufficient-history
  rules are reviewed in `todo-journal-plan.md` §10.

## Data and edge cases

- `StudySegment`: id, start, end (nil while running), source (timer or manual), optional note, and
  `dayTarget` (the target in force when it began; the day's first block sets the day's target).
  Source 0.14.0 adds optional topic, originating zone, saved marks and roadmap type; Build 1 payloads
  still decode. Last study confirmation belongs to app preferences, not the duration record. Settings (target, marks) are one JSON value
  in the app's preferences, `studylog.settings`.
- A feature-owned, versioned SwiftData store like Lift Log and Body. The running state is the open
  segment's start timestamp, never a ticking counter, so suspension/relaunch does not lose elapsed
  time. A forgotten pause can still overstate effective study; recording timestamps does not verify
  attention. Corrections and long-block reconciliation are implemented in source 0.14.0; device proof remains open.
- One running block at most; Start and Pause are idempotent (double taps and duplicate notification
  callbacks change nothing). A Start never begins inside an earlier block, even with the clock set
  back. A block under five seconds is an accidental tap and is dropped on Pause. A block is stored
  whole and split at 3:00 AM when days are counted. Manual blocks (Build 2) cannot overlap other
  blocks or run into the future.
- Daylight saving and time-zone changes: totals come from absolute timestamps; only the day a block
  belongs to uses local time. Tests cover a block across 3:00 AM on a daylight-saving night.
- Backup: `study-log.json` (version 1, ISO dates, the blocks and the settings; whole-file validation
  — unique ids, no overlaps, at most one running block and it the latest — before a confirmed
  restore replaces everything). Source 0.14.0 requires an explicit actual end for a backed-up running block and restores it
  closed. Build 1 previously restored it as running. Notification permission is never carried.

## Constraints

- **Notification budget.** The app coordinator considers actual unrelated pending requests, keeps
  two spare slots and a maximum of fifteen timed tasks. Study check and break are mutually
  exclusive; Morning plan has one upcoming dated slot. Journal invitations are retired and cancelled.
  Pushups uses 39 nudges plus its normal request until verified handover. `personal-hub.md` owns
  capacity/failure handling; no delivery-time app execution is assumed.

- **Current distribution has no app extension or Live Activity** (`hub-plan.md`). The tested
  WHOOP/Sideloadly installation provisioned only the parent app, and iOS killed its Live Activity
  extension before launch with a CODESIGNING / Invalid Page error; see
  [WHOOP's signing evidence](../whoop/build-81-audit.md#decisions-akshat).
  This establishes a limitation of the tested installation path, not a universal prohibition on
  Live Activities with every free-account setup. The timer currently lives in the app plus local
  notifications; the lock screen shows only the nudge.
- **Build-39 display work (source, not device-verified):** Apple supports Live Activities on
  iPhone's [Always-On Lock Screen](https://developer.apple.com/design/human-interface-guidelines/always-on),
  but their UI requires a [WidgetKit extension](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).
  The requested unsigned testing IPA is delivered; extension provisioning, launch and display
  acceptance remain open in the authorized SideStore experiment. Apple's
  [StandBy](https://support.apple.com/en-ie/guide/iphone/iph878d77632/ios) can show Live Activities
  while charging sideways and stationary, but does not bypass that requirement.
  The foreground desk display uses
  [`isIdleTimerDisabled`](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled)
  while running Focus is active and explicitly enabled, restoring normal auto-lock on exit. It uses more
  power and requires the app to remain foreground; it is not the low-power Always-On Lock Screen.
  Build 38 has no Focus keep-awake behavior, and Today/Focus remain portrait-only; only the
  PageVault reader enables landscape there. Build-39 source adds portrait/landscape Focus; Today
  stays portrait. `study-display.md` owns current implementation, public sources and all phone gates.
- **Local only:** no network, account or sync with the Windows Clock. The roadmap bridge is a file
  Akshat moves himself; nothing is sent anywhere by the app.
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
  edits and overlap refusal, Undo, the one rolling request choosing the right reminder, the sessions
  export with stable ids and DSA kept out of solve time), persistence and backup/restore tests, `FullBackupTests` extended,
  and UI navigation tests, all in `ios/tests/feature-tests.json`.
- Built and tested on GitHub Actions, not locally; the usual unsigned-IPA checks apply.
- Phone acceptance by Akshat: a real study block with pause/resume, a force-quit while running, the
  locked-screen nudge and its actions (Build 2), a day rollover, and a backup restored. Build 2 also:
  a Shortcut or the Action Button starting and pausing the timer, and a sessions file imported into
  the roadmap twice without duplicate entries.
- On acceptance, update `hub-plan.md`, this folder's `CLAUDE.md`, `README.md`, `handoff.md` and
  `todo.md` in place.

## For the next session

Read `CLAUDE.md`, `hub-plan.md` (module boundaries, notifications, full backup), `features.md` and
`lift-log.md` (the closest contracts) and this file. Build 2 waits on Build 1's phone pass.
