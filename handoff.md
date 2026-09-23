# AkshatOS session handoff

**Status:** Current-state entry point for resuming AkshatOS work, not a specification or log.
Working source 0.4.0 (27) adds a definition and example for every Lift Log load mode; it is not yet
pushed, compiled or cloud-verified. Build 26 added the local-only Lift Log. PR #52 is merged at `7a4f639`; main run
`35870794873` passed the complete CI Gate and artifact `akshatos-ios-129` passed local checksum/IPA
validation. It is retained in the testing slot; installation and phone acceptance remain open.
Accepted 0.3.0 (25) presents the
compatibility-preserved movement engine as Pushup Reminder and adds the Homebase/quest visual refresh
across the hub and PageVault. Retained-candidate commit
`4253311` passed workflow-dispatch run `35678793533`; artifact `akshatos-ios-123` has matching
checksum and IPA validation. Its Wi-Fi install reached 100%, and
Sideloadly corroborates version 0.3.0, the expected signed identity and current-version enrollment;
Akshat then reported Build 25 works perfectly, closing the focused launch/presentation pass. Its
artifact is now the accepted backup copy. Build 13 remains the detailed lifecycle baseline and
Build 24 the accepted PageVault v1 feature baseline.
Update this file in place when resume guidance changes; the linked owning documents control detail.

## Start here

1. Read `D:\AI Important Files\CLAUDE.md`, then `personal-project/CLAUDE.md` and this project's
   [CLAUDE.md](CLAUDE.md). Follow any applicable deeper instructions.
2. Read [architecture.md](architecture.md) for implemented versus planned behavior,
   [todo.md](todo.md) for remaining gates, and [features.md](features.md) for the full product scope.
   PageVault work also reads `../book-reader/CLAUDE.md`, `features.md` and `architecture.md`.
3. Read [cloud-build.md](cloud-build.md) before building/installing and [ci.md](ci.md) before
   accepting changes. [hub-plan.md](hub-plan.md) owns cross-project integration.
4. Inspect local Git status, source and current GitHub checks before continuing. Do not assume
   the recorded build is still the latest or its temporary artifact remains downloadable.

`CLAUDE.md` is canonical for all agents. The redundant root, financials and roadmap `AGENTS.md`
files were removed; do not recreate them. The global Codex fallback already includes `CLAUDE.md`.
New managed folders use `CLAUDE.md`. Automatically synchronize affected owning documentation with
material changes; do not copy child progress into root/container instructions.

## Repository visibility and CI controls

The repository is temporarily public to avoid the private-plan Actions-minute cap. Before the
switch, a fresh scan covered every reachable commit plus commit messages, filenames, dangling local
objects, collaborators, PR content, webhooks, deploy keys, secrets/variables and representative
Actions logs. It found no committed credentials, Apple signing material, third-party personal data,
real GPS coordinates, or content copied from Akshat's private workspace domains. Akshat explicitly
accepted the low-risk Windows username/path and project-plan exposure without a history rewrite.
All 26 then-retained Actions artifacts were deleted before public visibility was enabled.

GitHub confirms `main` protection with strict/up-to-date `CI Gate`, administrator enforcement, and
force pushes/deletions disabled, so every change — documentation included — lands through a PR.
Every PR produces Source checks and `CI Gate`; only a PR whose changed paths are all Markdown skips
the macOS build. When Akshat says the public-CI need has passed, return the repository to private
and synchronize the docs. That stops new public access but cannot undo anything cloned, forked,
downloaded, indexed, cached, or otherwise copied while public. `ci.md` owns the full contract.

## Identity and accepted scope

- Repository: temporarily public `https://github.com/akshatksingh18/akshatos`, evolved from Squat Reminder
  and now presented as Pushup Reminder with history retained, not a second implementation. Local path:
  `D:\AI Important Files\personal-project\akshatos`.
- Permanent target/display name: AkshatOS. Bundle: `com.akshatksingh18.akshatos`.
  Minimum iOS 17; the working source version is recorded in `cloud-build.md`. Preserve identity on
  updates.
- Launch into an app picker; select Pushup Reminder, PageVault, or Lift Log for its own destination.
  This is not a combined dashboard. ReelVault/Reels remains an unavailable planned card.
- The movement loop is accepted in ongoing phone use under its Build-13 Squats presentation, so
  PageVault was activated and its v1 is now accepted through Build 24. Pushup Reminder's new copy,
  visuals and notifications plus PageVault's refreshed presentation are accepted in Build 25.
  ReelVault stays deferred.
  The movement feature's remaining physical/refresh items stay open and are not superseded by PageVault work.
  Native source for both media modules goes into this hub. WHOOP stays standalone.
- One ordinary application target/IPA, no widget, Watch app or other shipped extensions. Logical
  feature folders are not separately installed apps.
- Local-only, single-user data; no backend, analytics, accounts or cloud sync. Windows authors
  source; GitHub macOS/Xcode builds; Sideloadly signs locally. Never put Apple secrets or IPAs in Git.

## Implemented in source

- Lift Log: feature-owned workout domain and SwiftData store, plates-per-side default plus explicit
  alternative load meanings, save-after-every-set active-session recovery, finished history,
  undo/discard/delete controls, validated JSON recovery and CSV export. `lift-log.md` owns its
  product/privacy/acceptance contract; none of it is cloud- or phone-verified yet.
- Homebase hub, Pushup power-up dashboard, PageVault story-quest library, shared atmospheric visual
  components, refreshed generated icon, and app-lifetime services across navigation.
- Pushups lifecycle: Start/Pause/Resume/End, dashboard and notification Done/Pause, Undo, a bounded
  normal-plus-59-nudge schedule with foreground replenishment, and one idle 9:00 AM start invitation
  that never auto-starts a day.
- Durable actions: atomic after-first-unlock command inbox, receipts that survive Undo, shared
  commands, protected-store retry and queued-action UI.
- Pushups data: versioned SwiftData sessions, same-date daily history with active/paused durations,
  next-calendar-boundary rollover on foreground, configurable goal (eight sets initially; zero turns
  tracking off), deterministic current/best streak, versioned JSON export with validated restore, and
  completed-history deletion.
- Home auto-pause: staged When In Use → Always authorization, one monitored circular region in
  protected storage excluded from backups, source-aware pause/resume, outside-Home choices, truthful
  health, and edit/disable/delete. No continuous background-location mode.
- Permissions and accessibility: authoritative notification/location authorization with
  revoked-versus-denied wording, Settings routing from blocking alerts, Focus/Scheduled Summary
  caveats, VoiceOver, Dynamic Type, Reduce Motion and Increased Contrast behavior.
- Foreground reconciliation of preferences, notification settings, pending requests, the action
  inbox, day data and the actual monitored Home region.
- PageVault: copy-on-import library with covers and a Started shelf, the page-curl reader cropping
  each page to its measured text, tinted paper (sepia by default), the bookmark as your place, one
  Reading book at a time, highlights with Takeaways and a PDF export, full-text search, and
  folder/JSON export with validated, conflict-aware restore. Its reading loop is phone-confirmed as
  of Build 20; reading streaks were removed in Build 21. Build 22's pass reworked the highlighter
  after it was found stacking marks; `cloud-build.md` owns that finding.
- Logical boundaries: `ios/AkshatOS/app/` composes features and owns the sole notification
  coordinator; `app/hub/` displays metadata and injected destinations; `shared/design-system/`
  is feature-independent; `features/squats/` and `features/pagevault/` own their domain, data,
  services, UI and store. All compile into one Swift module. Extend these systems rather than
  recreating them.
- Android remains an untouched, unverified fallback; no parity or successful Android build claimed.

Limits that still apply: simulator and cloud tests do not prove locked-device actions, real delivery,
geofences, Focus, reboot, signing refresh, or how reading feels. Day rollover happens on the next
launch or foreground entry; the app does not claim a background midnight execution.

## Build and device evidence

`cloud-build.md` owns every build record: source commits, runs, checksums, retained local artifacts
and phone findings. Three facts matter when resuming: Build 13 is the detailed legacy movement-loop
baseline, Build 24 is the accepted PageVault v1 feature baseline, and Build 25 is the accepted
installed Pushup/presentation baseline, Build 26 is the retained cloud/local artifact, and working
Build 27 supersedes it for the eventual phone pass once packaged. One same-ID update without uninstalling has preserved app data
(Build 12 over Build 11).
Sideloadly is installed; give Akshat manual steps rather than driving it. The previously helpful
Anisette workaround was disconnect phone, initialize Sideloadly, then reconnect; not a guaranteed fix.
Back up important history before risky deployment/recovery tests, and do not uninstall data-bearing builds.

## Recommended continuation order

1. **Lift Log Build-27 compile and device pass:** run the complete CI Gate and replace the retained
   Build-26 candidate, then install over Build 25 without uninstalling and use disposable data to
   verify per-side semantics, active-session relaunch and JSON/CSV
   recovery without disturbing existing Pushups or PageVault data. Do not publish private history.
2. **PageVault device pass:** hand Akshat the latest verified PageVault build from `cloud-build.md`
   and record what the phone shows there and in `../book-reader/CLAUDE.md`. Fix defects before
   calling any reader behavior working.
3. **Complete the remaining Pushups physical edge-case matrix:** locked/force-quit/reboot, permission,
   Focus/Scheduled Summary, picker/back, Undo/replay, summaries/recovery and Home-automation checks.
   Record actual results and fix defects; `architecture.md` owns durability limits.
4. **Deployment acceptance:** repeat same-ID USB/Wi-Fi refresh preserving data,
   current/previous known-good IPA cache, verified early-refresh health checks and expiry alerts,
   recovery exercises, then multiple signing cycles. Follow the existing guide's gates and recheck
   current Apple/Sideloadly requirements before activation. Do not promise unattended reliability yet.
5. **Optional App Intents/Shortcuts:** follow-on convenience triggers after the native core works,
   never the reminder engine; use the same pause-source and idempotency rules.

V1 counts completed sets/breaks, not reps or notification deliveries. The chosen initial goal is
eight sets and the chosen initial Home radius is 150 meters; both remain configurable. Reps,
freezes, achievements and extra places are not committed.

## Verification and handoff discipline

Every feature/fix needs meaningful regression coverage. Register suites in
`ios/tests/feature-tests.json`; run boundary and inventory checks plus relevant tests, then inspect
the exact source commit's GitHub CI Gate before claiming cloud verification. Verify job conclusions
directly rather than trusting a watch command's exit status. Docs-only PRs skip macOS but retain the
gate. Simulator tests do not prove locked actions, actual delivery, geofences, Focus, reboot or
signing refresh.

Authoring on Windows has two traps worth knowing before they cost a round trip. A long or
quote-heavy bash heredoc gets mangled or truncated by the shell, so write a script with the Write
tool and run it rather than piping a large one inline. And a Python string holding a Windows path
needs to be raw: `"C:\Users\..."` parses `\U` as a unicode escape and fails outright.

Keep this handoff, its index and source changes together when publishing. Commit/PR/check evidence
belongs in `cloud-build.md`.
