# Daily routine

**Status:** Implemented in Build-40 (0.15.0) source; exact-source CI Gate passes in run `39122553639` at `18a59b1`; both native accessibility fixes are scored resolved. Phone acceptance remains open. Not present
in the delivered Build-39 IPA. Core scope is authorized. Grouped presentation is the stated default
while the optional layout question is unanswered. Source/CI/device evidence must stay separate.

## Scope

- A Daily routine section on Today; no extra tab. Morning, Day and Evening groups use the existing
  graphite/copper/sage design. Manage and history are deliberate closable sheets.
- User-authored items with optional local target times, selected weekdays, ordering and pause.
  Start empty; never seed personal routines or turn a target time into an alarm.
- Each eligible activity day has its own snapshot and explicit check-offs. Done, pending and skipped
  are distinct. Check-offs can be reversed; timestamps are reported entry times, not proof of when
  waking/reading happened. Missing an item never creates overdue task copies.
- Retain the existing 03:00 cutoff and source zone. History contains recorded days, not invented
  failures for days the app never recorded. Closed snapshots survive template edits/removal.
- Templates and history live inside To-do's atomic snapshot and full/module JSON backup. Replacing
  To-do from an old payload without routines clears the routine, with an explicit warning; a full
  backup without the To-do module leaves the existing store intact. Routine progress does not alter priority/study
  qualification. Journal and its full-day challenge are retired. No cross-app/reading-time inference.
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

Exact-source run [39122553639](https://github.com/akshatksingh18/akshatos/actions/runs/39122553639)
passes all three jobs, including 18 release-contract tests, nine domain suites, 197 hosted tests,
15 UI tests and both complete device variants' payload validation. IPA packaging/upload were skipped;
only `test-diagnostics-185-1` was published. No routine IPA has been created.

Matching native captures at `18a59b1` show an unbroken Manage action at accessibility sizes and
manager/history actions and records before optional explanatory disclosures. The fresh reviewer
scored both material fixes resolved. Evidence is in
`.impeccable/review/build-40-confirmation/` (routine, manager, editor and history at normal and
accessibility sizes, plus the actual Today check-off flow). Isolated component captures do not
certify the full Today composition, VoiceOver, unseen scroll positions or physical-phone behavior.
The documenter confirmed an ordinary extension of the incumbent system: `DESIGN.md` and its sidecar
remain unchanged; no new design tokens or shipping raster assets were introduced.

Cover independent daily generation, weekdays/03:00/DST, empty/no-schedule/unavailable states, double taps,
skips/undo, historic snapshots, editing/pausing, legacy decode, malformed restore and real persistence/
backup round trips. Native capture and UI navigation verify touch targets and accessibility reflow.
Cloud checks run without IPA packaging; a new IPA requires a release request. Delivered Build 39 and
accepted recovery are retained until a newer requested release passes their existing cache rules.
