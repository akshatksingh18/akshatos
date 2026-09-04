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
  Current source version: `0.2.0 (4)`, minimum iOS 17. Preserve identity on updates.
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
- Logical boundaries: `ios/AkshatOS/app/` composes features and owns the sole notification
  coordinator; `app/hub/` displays metadata and injected destinations; `shared/design-system/`
  is feature-independent; `features/squats/` owns domain/data/services/UI and its store.
  All compile into one Swift module. Extend these systems rather than recreating them.
- Android remains an untouched, unverified fallback; no parity or successful Android build claimed.

Important limitations: build-4 actions need exact-source cloud and physical acceptance; the existing
downloaded build-3 preview has no action buttons. No Home location permission or monitoring is implemented. Prior-day running sessions are stopped
at foreground reconciliation and require explicit End; background midnight finalization is not done.
Many unchecked TODOs are full-contract acceptance gates for partially implemented systems.

## Build and device evidence

The resume baseline was documentation commit `db2a458` plus the uncommitted handoff/index, which
were preserved. Build-4 notification action implementation and tests are pending cloud validation.
Recorded expanded baseline CI success is source
`a31643b2375abcd3e708ca3747c9980b1a3e78b8`,
[run #7](https://github.com/akshatksingh18/akshatos/actions/runs/33820332042): 12 domain assertions,
three SwiftData persistence tests, one hub/settings UI test, source/inventory/workflow checks,
simulator/device compilation, IPA inspection and CI Gate. This handoff did not rerun cloud CI.
Run #7's artifact was not recorded as downloaded or phone-tested.

The recorded hash-verified local preview is run #6, source
`e70740d3af51e5bad288787c99f3a1430103c88e`, at:
`C:\Users\aksha\Downloads\akshatos-module-boundaries\akshatos-ios-6\AkshatOS-unsigned.ipa`.
Its presence was checked for this handoff; recheck SHA-256 against `cloud-build.md` before install.
Keep its checksum and build metadata together; do not confuse equal version numbers with equal builds.

Only the old standalone Squat Reminder smoke was installed and opened on the phone. Akshat then
deleted that disposable app. **AkshatOS installation, reminders and same-ID refresh remain pending.**
Sideloadly is installed; use manual user-facing steps, not computer control. The previously helpful
Anisette workaround was disconnect phone, initialize Sideloadly, then reconnect; not a guaranteed fix.
Use disposable activity until recovery and device tests pass. Do not uninstall data-bearing builds.

## Recommended continuation order

1. **Baseline phone acceptance:** follow the existing manual install guide with an intentionally
   selected, verified artifact. Confirm picker → Squats → back, one-minute and normal 45-minute
   reminders, dashboard lifecycle/counting/Undo/snooze, relaunch and permission changes. Record
   actual user results in `cloud-build.md`; if hardware is unavailable, keep this gate open.
2. **Accept notification actions:** build-4 source implements Done, Pause, then ten-minute snooze
   in the central coordinator, shared commands, durable inbox and receipt-based replay protection.
   Verify exact-source CI and the physical locked/background matrix. `architecture.md` owns retry,
   expired-snooze and before-first-unlock limits; do not equate simulated failures with phone tests.
3. **Complete day data and recovery:** daily aggregate overview with active/paused durations,
   timeline/history, date rollover and time-zone/DST rules, migration/disk-restart tests, explicit
   history deletion and export/restore. Harden goal snapshots, skipped dates, Undo and streaks.
4. **Opt-in Home auto-pause:** explanatory staged permissions, Home/radius setup, one protected
   local geofence, source-aware pause/resume, duplicate/jitter protection, degraded-health UI and
   edit/disable/delete. Arrival may resume only a Home-auto-paused day, never a manual pause or End.
   No continuous tracking or movement trail. Manual and notification controls remain fallbacks.
5. **Optional App Intents/Shortcuts:** only after native commands work. They are convenience
   triggers, never the reminder engine; use the same pause-source and idempotency rules.
6. **Deployment acceptance:** full physical matrix, same-ID USB/Wi-Fi refresh preserving data,
   current/previous known-good IPA cache, verified early-refresh health checks and expiry alerts,
   recovery exercises, then multiple signing cycles. Follow the existing guide's gates and recheck
   current Apple/Sideloadly requirements before activation. Do not promise unattended reliability yet.

V1 counts completed sets/breaks, not reps or notification deliveries. The daily goal number still
needs Akshat's choice; don't invent one. Reps, freezes, achievements and extra places are not committed.

## Verification and handoff discipline

Every feature/fix needs meaningful regression coverage. Register suites in
`ios/tests/feature-tests.json`; run boundary and inventory checks plus relevant tests, then inspect
the exact source commit's GitHub CI Gate before claiming cloud verification. Prefer feature branches
and PRs. Current private-repo branch protection was blocked by the GitHub plan (HTTP 403): the pipeline
is active, but merge/direct-push enforcement is not. No paid upgrade or public visibility is authorized.
Real PR-trigger/failure-diagnostic paths still need exercise. Simulator tests do not prove locked
actions, actual delivery, geofences, Focus, reboot or signing refresh.

Keep this handoff, its index and source changes together when publishing. Commit/PR/check evidence
belongs in `cloud-build.md`; no phone installation or signing state changed during source continuation.
