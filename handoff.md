# AkshatOS session handoff

Build 39 (0.14.1) is now the active source-development task, with **no IPA and no release merge**
requested. Continue adding features incrementally. `study-display.md` owns rotating desk Focus,
keep-awake, quiet study notifications, the opt-in SideStore Live Activity candidate, research and
DND/device/signing gates. SideStore exploration is authorized; installed signing/refresh ownership
is unchanged. Exact-source CI and native inspection pass at `86c4367` on draft PR #68, including
the compact-dial readability correction. `cloud-build.md` owns the run, counts and diagnostics.
No Build-39 IPA was created. Explicit release-variant selection and strict extension validation
are implemented with exact-source CI pending; `study-display.md` owns this release contract.
Physical signing/DND/AOD/renewal checks remain open. Build 38 below
remains the last delivered candidate, not the working source version.

**Status:** Personal-hub Build 38 (0.14.0), PR #67, is merged at `b573ecc` and validated in the
single-slot testing cache. PR/main CI, local checksum/IPA inspection and the two native accessibility
fixes pass. Build 37 remains installed/enrolled; Build 31 remains accepted recovery.
`implementation-plan.md` tracks local coverage, `personal-hub.md` the implementation and
`todo-journal-plan.md` accepted decisions. Journal defaults unlocked. Do not restart design selection
or request approval for completed authorized work. All work stays at source/CLI level. Final release
evidence is synchronized locally and waits for the next real code change before its next push.

Planning files remain local because the public push containing a personal planning document was
rejected by automatic approval review. The accepted retry was code-only. Review every subsequent
outgoing commit under the root privacy gate; do not publish personal routines/records to satisfy
documentation synchronization. Technical implementation documentation can be reviewed separately.

## Start here

1. Read `D:\AI Important Files\CLAUDE.md`, then `personal-project/CLAUDE.md` and this project's
   [CLAUDE.md](CLAUDE.md). Follow any applicable deeper instructions.
2. Read [architecture.md](architecture.md) for implemented versus planned behavior,
   [todo.md](todo.md) for remaining gates, and [features.md](features.md) for the full product scope.
   PageVault work also reads `pagevault/CLAUDE.md`, `features.md` and `architecture.md`.
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
- Source 0.14.0 launches Today / To-do / Journal / Apps. Build 37 still has the old picker; legacy fitness stores stay behind a controlled handover/recovery path.
  This is not a combined dashboard. ReelVault shipped in Build 32 and is removed from Build 33.
- The movement loop is accepted in ongoing phone use under its Build-13 Squats presentation, so
  PageVault was activated and its v1 is now accepted through Build 24. Pushup Reminder's new copy,
  visuals and notifications plus PageVault's refreshed presentation are accepted in Build 25.
  The movement feature's remaining physical/refresh items stay open and are not superseded by PageVault work.
  Native source for both media modules goes into this hub. WHOOP stays standalone.
- Default: one ordinary application target/IPA, no widget, Watch app or shipped extension. Build 39
  prepares a separately opt-in study Live Activity candidate; see `study-display.md`. Logical
  feature folders are not separately installed apps.
- Local-only, single-user data; no backend, analytics, accounts or cloud sync. Windows authors
  source; GitHub macOS/Xcode builds; Sideloadly signs locally. Never put Apple secrets or IPAs in Git.

## Implemented in source

- Lift Log: feature-owned workout domain and SwiftData store, splits edited in the app (from 0.8.0
  (31); Upper/Lower were hard-coded before), Add exercise and empty workouts, explicit load meanings and guidance, same-mode last-performance lookup,
  save-after-every-mutation active-session recovery, set edit/undo/discard/delete controls,
  finished history, validated JSON recovery and CSV export. `lift-log.md` owns its
  product/privacy/acceptance contract; its core and editable splits are phone-accepted through Build 31.
- Body (introduced in Build 29, accepted with Build 31): daily weigh-in with seven-day and weekly-block averages, the
  eight-site weekly tape with guidance and per-site change, Navy body-fat and waist-to-height
  estimates from a height set on the phone, camera/Photos progress photos with first-vs-latest
  comparison, an optional weekly reminder routed by the `akshatos.body.` namespace, folder backup
  with validated restore, and CSV. `body-log.md` owns it; no personal data belongs in this repo.
- A plain hub list, Pushup dashboard, PageVault library and Lift Log on one minimal shared design
  system (neutral surfaces, one accent, plain labels), a flat generated icon, and app-lifetime
  services across navigation. The Build-25 "quest" theme is replaced in 0.6.0 (29); keep it plain.
- Pushups lifecycle: Start/Pause/Resume/End, dashboard and notification Done/Pause, Undo, a bounded
  normal-plus-39-nudge schedule with foreground replenishment, and one idle 9:00 AM start invitation
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
  after it was found stacking marks; `cloud-build.md` owns that finding. Imports run through one
  serialized store path. The laptop inbox folder and Open in AkshatOS from Build 28 are removed in
  0.6.0 (29) at Akshat's request; do not re-propose them.
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
baseline, Build 24 is the accepted PageVault v1 feature baseline, Build 25 is the accepted
installed Pushup/presentation baseline, and Build 31 is the current accepted recovery/refresh
artifact. Build 37 is installed by Akshat's confirmation and enrolled for current-version automatic
refresh in automatic bundle-ID mode with no recorded error; its feature phone pass remains open.
One same-ID update without uninstalling has preserved app data
(Build 12 over Build 11).
Sideloadly is installed; give Akshat manual steps rather than driving it. The previously helpful
Anisette workaround was disconnect phone, initialize Sideloadly, then reconnect; not a guaranteed fix.
Back up important history before risky deployment/recovery tests, and do not uninstall data-bearing builds.

## Recommended continuation order

0. **Continue Build 39 without packaging:** `study-display.md` owns current changes, research and
   DND/SideStore gates. Use the development branch and draft PR for cloud checks. Do not merge or
   create an IPA until requested; the user plans one combined installation after more features.
   Build 38 remains cached for recovery/testing reference, not a required intermediate install.
1. **Phone acceptance:** four tabs, real study Start/Pause/Focus/corrections/Undo/rollover, task
   recurrence/priorities, Journal default/privacy/photos/recovery and optional notifications. The
   retained Build-37 voice-menu and shelf-order checks should run on this candidate too; one
   installation is not acceptance. Build 31 stays recovery until the full promotion rule passes.
2. **Fitness handover:** new fitness work belongs in WHOOP. Verify its imports/photos/reminders and
   recovery on the phone, then use AkshatOS Settings to stop the old reminder owner. Preserve old
   stores/backups; no automatic synchronization or completed cutover is implied.
3. **Files and roadmap:** measure provider latency, offline/revoked access and re-sign behavior.
   Manual transport remains the baseline. The laptop receiving importer is separately unimplemented;
   follow its owning instructions when explicitly requested. No new workspace upload exception.
4. **Remaining legacy checks:** if continuing to rely on old Pushups before handover, its physical
   edge-case matrix remains in `todo.md`/`architecture.md`. Do not treat new-hub CI as hardware proof.
5. **Deployment acceptance:** same-ID USB/Wi-Fi refresh and data preservation, protected recovery,
   early-refresh health and multiple signing cycles remain physical checks. Keep the accepted cache.
6. **Shortcuts:** personal-hub App Intents are implemented; exercise them on the phone. Optional
   fitness automation belongs to WHOOP, using its own source-aware/idempotency contracts.

The retained Pushups v1 counts completed sets/breaks, not reps or notification deliveries. The chosen initial goal is
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
