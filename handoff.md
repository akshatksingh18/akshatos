# AkshatOS session handoff

**Status:** Current-state entry point for resuming AkshatOS work, not a specification or log. Squats
v1 is accepted in daily phone use on Build 13, with its physical edge-case and deployment matrix still
open; PageVault is under active implementation with one end-of-implementation device pass pending.
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
  with history retained, not a second implementation. Local path:
  `D:\AI Important Files\personal-project\akshatos`.
- Permanent target/display name: AkshatOS. Bundle: `com.akshatksingh18.akshatos`.
  Minimum iOS 17; the working source version is recorded in `cloud-build.md`. Preserve identity on
  updates.
- Launch into an app picker; select Squat Reminder to open its own dashboard, or PageVault for its own
  PDF library. This is not a combined dashboard. ReelVault/Reels remains an unavailable planned card.
- Squats' daily loop is accepted in ongoing phone use, so PageVault is the activated next module; its
  scope, phases and progress are owned by `../book-reader/CLAUDE.md`. ReelVault stays deferred.
  Squats' remaining physical/refresh items stay open and are not superseded by PageVault work.
  Native source for both media modules goes into this hub. WHOOP stays standalone.
- One ordinary application target/IPA, no widget, Watch app or other shipped extensions. Logical
  feature folders are not separately installed apps.
- Local-only, single-user data; no backend, analytics, accounts or cloud sync. Windows authors
  source; GitHub macOS/Xcode builds; Sideloadly signs locally. Never put Apple secrets or IPAs in Git.

## Implemented in source

- Hub picker, Squats dashboard, shared visual components, and app-lifetime services across navigation.
- Squats lifecycle: Start/Pause/Resume/End, dashboard and notification Done/Pause, Undo, a bounded
  normal-plus-59-nudge schedule with foreground replenishment, and one idle 9:00 AM start invitation
  that never auto-starts a day.
- Durable actions: atomic after-first-unlock command inbox, receipts that survive Undo, shared
  commands, protected-store retry and queued-action UI.
- Squats data: versioned SwiftData sessions, same-date daily history with active/paused durations,
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
- PageVault: copy-on-import library with covers and a Started shelf, a paged reader that crops each
  page to its measured text, warm paper, the bookmark as your place, one Reading book at a time, and
  folder/JSON export with validated, conflict-aware restore. Its reading loop is phone-confirmed as
  of Build 20; reading streaks were removed in Build 21.
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
and phone findings. Two facts matter when resuming: Build 13 is the last build accepted for Squats
daily use, and one same-ID update without uninstalling has preserved app data (Build 12 over Build 11).
Sideloadly is installed; give Akshat manual steps rather than driving it. The previously helpful
Anisette workaround was disconnect phone, initialize Sideloadly, then reconnect; not a guaranteed fix.
Back up important history before risky deployment/recovery tests, and do not uninstall data-bearing builds.

## Recommended continuation order

1. **PageVault device pass:** hand Akshat the latest verified PageVault build from `cloud-build.md`
   and record what the phone shows there and in `../book-reader/CLAUDE.md`. Fix defects before
   calling any reader behavior working.
2. **Complete the remaining Squats physical edge-case matrix:** locked/force-quit/reboot, permission,
   Focus/Scheduled Summary, picker/back, Undo/replay, summaries/recovery and Home-automation checks.
   Record actual results and fix defects; `architecture.md` owns durability limits.
3. **Deployment acceptance:** repeat same-ID USB/Wi-Fi refresh preserving data,
   current/previous known-good IPA cache, verified early-refresh health checks and expiry alerts,
   recovery exercises, then multiple signing cycles. Follow the existing guide's gates and recheck
   current Apple/Sideloadly requirements before activation. Do not promise unattended reliability yet.
4. **Optional App Intents/Shortcuts:** follow-on convenience triggers after the native core works,
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

Keep this handoff, its index and source changes together when publishing. Commit/PR/check evidence
belongs in `cloud-build.md`.
