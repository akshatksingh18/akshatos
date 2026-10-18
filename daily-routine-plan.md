# Daily routine

**Status:** Implemented in Build-40 (0.15.0) source; cloud/native verification is pending. Not present
in the delivered Build-39 IPA. Core scope is authorized. Grouped presentation is the stated default
while the optional layout question is unanswered. Source/CI/device evidence must stay separate.

## Scope

- A Daily routine section on Today; no fifth tab. Morning, Day and Evening groups use the existing
  graphite/copper/sage design. Manage and history are deliberate closable sheets.
- User-authored items with optional local target times, selected weekdays, ordering and pause.
  Start empty; never seed personal routines or turn a target time into an alarm.
- Each eligible activity day has its own snapshot and explicit check-offs. Done, pending and skipped
  are distinct. Check-offs can be reversed; timestamps are reported entry times, not proof of when
  waking/reading happened. Missing an item never creates overdue task copies.
- Retain the existing 03:00 cutoff and source zone. History contains recorded days, not invented
  failures for days the app never recorded. Closed snapshots survive template edits/removal.
- Templates and history live inside To-do's atomic snapshot and full/module JSON backup. Old backups
  without routines leave an empty routine. Routine progress does not alter priority/study/Journal
  qualification or the optional full-day challenge. No cross-app/reading-time inference.
- No new notifications in this first addition. Timed reminders, automatic completion, target counters,
  streak mechanics and device-clock/health integrations are follow-ons, not silently enabled features.

## Direction contract

THESIS: check the day's repeated actions in one familiar place, independently of one-off priorities.
OWN-WORLD: inherit DESIGN.md, semantic native text, copper controls, sage completion and SF Symbols.
STORY: see what is due today, tap to record it, undo a mistake, then return to studying.
FIRST VIEWPORT: preserve the study instrument; the routine follows today's priorities, with a labelled
completion count and short progress track. Groups disclose their rows without new navigation.
FORM: local extension of Today, Operate mode, code-led; no concept seed is required for this scope.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict,
DESIGN.md, and every shipping raster carrying its provenance

## Verification

Cover independent daily generation, weekdays/03:00/DST, empty/no-schedule/unavailable states, double taps,
skips/undo, historic snapshots, editing/pausing, legacy decode, malformed restore and real persistence/
backup round trips. Native capture and UI navigation verify touch targets and accessibility reflow.
Cloud checks run without IPA packaging; a new IPA requires a release request. Delivered Build 39 and
accepted recovery are retained until a newer requested release passes their existing cache rules.
