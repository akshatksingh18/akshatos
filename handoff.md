# AkshatOS session handoff

**Status:** Continue the existing hub and finish Squat Reminder first. Source and cloud checks
exist; first physical AkshatOS acceptance and the full Squats feature contract remain unfinished.
This is a current-state entry point, not a separate specification or chronological log. Update it
in place when its resume guidance changes; the linked owning documents control detailed facts.

## Start here

1. Read `D:\AI Important Files\CLAUDE.md`, then `personal-project/CLAUDE.md` and this project's
   [CLAUDE.md](CLAUDE.md). Follow any applicable deeper instructions.
2. Read [architecture.md](architecture.md) for implemented versus planned behavior,
   [todo.md](todo.md) for remaining gates, and [features.md](features.md) for the full product scope.
3. Read [cloud-build.md](cloud-build.md) before building/installing and [ci.md](ci.md) before
   accepting changes. [hub-plan.md](hub-plan.md) owns cross-project integration.
4. Inspect local Git status, source and current GitHub checks before continuing. Do not assume
   the recorded build is still the latest or its temporary artifact remains downloadable.

`CLAUDE.md` is canonical for all agents. The redundant root, financials and roadmap `AGENTS.md`
files were removed; do not recreate them. The global Codex fallback already includes `CLAUDE.md`.
New managed folders use `CLAUDE.md`. Automatically synchronize affected owning documentation with
material changes; do not copy child progress into root/container instructions.

## Identity and accepted scope

- Repository: private `https://github.com/akshatksingh18/akshatos`, evolved from Squat Reminder
  with history retained, not a second implementation. Local path:
  `D:\AI Important Files\personal-project\akshatos`.
- Permanent target/display name: AkshatOS. Bundle: `com.akshatksingh18.akshatos`.
  Current source version: `0.2.0 (5)`, minimum iOS 17. Preserve identity on updates.
- Launch into an app picker; select Squat Reminder to open its own dashboard. This is not a
  combined dashboard. PageVault/PDF Reader and ReelVault/Reels are unavailable planned cards.
- Finish Squats before implementing either media module. Their requirements remain in the sibling
  `book-reader` and `reels` projects; future native source goes into this hub. WHOOP stays standalone.
- One ordinary application target/IPA, no widget, Watch app or other shipped extensions. Logical
  feature folders are not separately installed apps. Keep the repository private.
- Local-only, single-user data; no backend, analytics, accounts or cloud sync. Windows authors
  source; GitHub macOS/Xcode builds; Sideloadly signs locally. Never put Apple secrets or IPAs in Git.

## Already implemented in source

- Picker, Squats dashboard, shared visual components, and app-lifetime services across navigation.
- Start/Pause/Resume/End; dashboard Done +1, Undo, and replaceable ten-minute snooze.
- Notification Done, Pause and ten-minute snooze; atomic after-first-unlock command inbox,
  receipt persistence surviving Undo, shared commands, protected-store retry and queued-action UI.
- One system-scheduled recurring local reminder; permission/pending-request reconciliation.
- Versioned SwiftData session storage, recent session summaries, configurable daily goal,
  same-day set aggregation, and current/best streak calculation. Initial goal is deliberately unset.
- Build-5 source adds one daily history entry across same-date sessions, active/paused duration,
  pause/snooze/completion detail, deterministic foreground rollover at the next local calendar
  boundary, versioned JSON export/validated restore, and completed-history deletion.
- Logical boundaries: `ios/AkshatOS/app/` composes features and owns the sole notification
  coordinator; `app/hub/` displays metadata and injected destinations; `shared/design-system/`
  is feature-independent; `features/squats/` owns domain/data/services/UI and its store.
  All compile into one Swift module. Extend these systems rather than recreating them.
- Android remains an untouched, unverified fallback; no parity or successful Android build claimed.

Important limitations: build-4 actions passed cloud checks but still need physical acceptance; the existing
downloaded build-3 preview has no action buttons. Build-5 daily/recovery source passed its cloud
gate but has no downloaded or phone-tested artifact. No Home location permission or monitoring is implemented. Rollover happens on the next app
launch/foreground entry; the app does not claim a background midnight execution.
Many unchecked TODOs are full-contract acceptance gates for partially implemented systems.

## Build and device evidence

Current work is on `feature/squats-notification-actions`, published in
[PR #1](https://github.com/akshatksingh18/akshatos/pull/1), not merged into main. Build-4 source
`3cfea6176d43e79b8af899b579e0ac602b480715` passed
[run #10](https://github.com/akshatksingh18/akshatos/actions/runs/33897588498): 20 domain assertions,
24 integration tests, one hub/settings UI test, source/inventory/workflow checks, simulator/device
compilation, IPA inspection and CI Gate. Documentation revision
`ede1e492bedf8bfbc8c76fb938a3a0676aa97b32` passed PR run #11 and delivery run #12 with unchanged
application source. Follow-up documentation preserves this evidence; inspect current PR checks
when resuming. `cloud-build.md` owns exact source/hash/build records and manual install instructions.

The selected hash-verified local preview is **0.2.0 (4)** from delivery run #12, at:
`C:\Users\aksha\Downloads\akshatos-notification-actions\akshatos-ios-12\AkshatOS-unsigned.ipa`.
Its checksum, identity, version/build and payload passed local inspection. Recheck SHA-256 against
`cloud-build.md` before install; keep checksum/build metadata together. Older build-3 and smoke
downloads remain preserved, with their evidence in the build guide. No build-4 install is recorded.

Only the old standalone Squat Reminder smoke was installed and opened on the phone. Akshat then
deleted that disposable app. **AkshatOS installation, reminders and same-ID refresh remain pending.**
Sideloadly is installed; use manual user-facing steps, not computer control. The previously helpful
Anisette workaround was disconnect phone, initialize Sideloadly, then reconnect; not a guaranteed fix.
Use disposable activity until recovery and device tests pass. Do not uninstall data-bearing builds.

## Recommended continuation order

Finish the agreed native Squats v1 and automated/cloud tests before requesting physical testing.
Akshat reports sideloading is working and will test the complete feature afterward. Do not pause
implementation for baseline installation. Existing device gates remain open until that later pass.

1. **Harden remaining day/streak edges:** build-5 exact-source CI is green; finish remaining goal
   snapshots, skipped-date, clock/time-zone and streak edges before the consolidated phone pass.
2. **Opt-in Home auto-pause:** explanatory staged permissions, Home/radius setup, one protected
   local geofence, source-aware pause/resume, duplicate/jitter protection, degraded-health UI and
   edit/disable/delete. Arrival may resume only a Home-auto-paused day, never a manual pause or End.
   No continuous tracking or movement trail. Manual and notification controls remain fallbacks.
3. **Finish native v1 UI and reliability coverage:** complete dashboard/settings, accessibility,
   lifecycle/permission/error states, and remaining day/streak, persistence and service regression
   scenarios. Existing components are partly implemented; extend them rather than recreate them.
   Keep exact-source CI mandatory throughout, then deliver a complete candidate for phone testing.
4. **Physical feature acceptance:** picker → Squats → back, one-minute/45-minute reminders,
   dashboard and locked notification Done/Pause/snooze, Undo/replay, relaunch, permissions, day
   summaries/recovery, Home automation and the full physical matrix. Record actual results and fix
   defects; `architecture.md` owns action retry, expired-snooze and before-first-unlock limits.
5. **Deployment acceptance:** same-ID USB/Wi-Fi refresh preserving data,
   current/previous known-good IPA cache, verified early-refresh health checks and expiry alerts,
   recovery exercises, then multiple signing cycles. Follow the existing guide's gates and recheck
   current Apple/Sideloadly requirements before activation. Do not promise unattended reliability yet.
6. **Optional App Intents/Shortcuts:** follow-on convenience triggers after the native core works,
   never the reminder engine; use the same pause-source and idempotency rules.

V1 counts completed sets/breaks, not reps or notification deliveries. The daily goal number still
needs Akshat's choice; don't invent one. Reps, freezes, achievements and extra places are not committed.

## Verification and handoff discipline

Every feature/fix needs meaningful regression coverage. Register suites in
`ios/tests/feature-tests.json`; run boundary and inventory checks plus relevant tests, then inspect
the exact source commit's GitHub CI Gate before claiming cloud verification. Prefer feature branches
and PRs. Current private-repo branch protection was blocked by the GitHub plan (HTTP 403): the pipeline
is active, but merge/direct-push enforcement is not. No paid upgrade or public visibility is authorized.
Real PR-trigger/failure-diagnostic paths have been exercised. Simulator tests do not prove locked
actions, actual delivery, geofences, Focus, reboot or signing refresh.

Keep this handoff, its index and source changes together when publishing. Commit/PR/check evidence
belongs in `cloud-build.md`; no phone installation or signing state changed during source continuation.
