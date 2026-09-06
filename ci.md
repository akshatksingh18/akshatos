# AkshatOS CI and delivery contract

**Status:** Permission-history and Home-backup privacy correction source
`d80653da39433815c1d12fb9470adb9417a6f819` passed Source checks, Build installable IPA and
`CI Gate` in [PR #1 run #27](https://github.com/akshatksingh18/akshatos/actions/runs/33985917032):
37 domain assertions, 41 integration/persistence tests, the hub/settings UI test, simulator/device
compilation and IPA inspection. The public repository's `main` branch is server-protected with a
strict required `CI Gate`, administrator enforcement, and force pushes/deletions disabled.
Documentation-only PRs retain Source checks and `CI Gate` while intentionally skipping the macOS
build. PR runs do not upload an IPA artifact; exact downloadable build/hash evidence belongs in
`cloud-build.md`.
Final classifier/documentation source `d3864970a2beb2ebcc463bf73fca0574542ca942` passed the full
pipeline in [PR #1 run #28](https://github.com/akshatksingh18/akshatos/actions/runs/33986900743);
that update contained the workflow itself, so classification correctly required macOS.
The subsequent Markdown-only source `931d3a568d5540167dbf9734020a1715a3cd3420` passed Source
checks and the required `CI Gate` in
[PR #1 run #29](https://github.com/akshatksingh18/akshatos/actions/runs/33987404033) while `Build
installable IPA` concluded `skipped`, directly verifying that the protected check does not remain
pending when a PR update changes only documentation.

## Automated checks

- Every pull request to `main` runs Source checks and `CI Gate`. On a normal PR update, a checked-out
  full-history diff compares the previous head to the new head; a newly opened/reopened PR compares
  its base to its head. The macOS build is skipped only when every changed path ends in `.md`; an
  unavailable/empty comparison or any non-Markdown path runs it. Pushes to `main` run the full pipeline for
  `ios/**` or the workflow; manual dispatch also runs everything. Documentation-only changes do not
  spend macOS build minutes. PR validation never uses `pull_request_target`.
- **Source checks**: logical module boundaries, feature test inventory and actionlint 1.7.12
  workflow syntax/expression checking. ShellCheck is disabled; this is not shell/security auditing.
- **Build installable IPA**: all registered feature domain executables, simulator compilation,
  hosted XCTest persistence tests, XCUITest navigation, device Release compilation, and IPA
  payload/identity inspection. New features must register their tests in `ios/tests/feature-tests.json`;
  domain suites run automatically. The unit/UI directories are included recursively by XcodeGen.
- **CI Gate**: always runs. It requires Source checks to succeed and, when classification requires
  macOS, requires the build to succeed. It accepts a skipped build only when the classifier output
  is explicitly false. Failed, cancelled or unexpectedly skipped prerequisites cannot pass. This
  is the stable required branch-protection check.
- Simulator `.xcresult` bundles (including coverage) and screenshots are uploaded even when tests
  fail, when produced, with seven-day retention. Coverage is collected, not a numeric pass threshold.
- IPA upload requires successful checks/tests/packaging and a non-PR run. Artifacts expire after
  14 days; they are not signed releases or durable backups. No Apple credentials or auto-install step.

## Coverage and limits

Current automated coverage: domain event deduplication/Undo/streak/date assertions; SwiftData
in-memory round-trip across contexts, persisted Undo/End and malformed-payload preservation;
hub entry/back/reopen, settings open/dismiss and unavailable media entries; plus the action suite
below. File-backed reopen, legacy payload decoding, daily aggregation/durations, DST rollover,
versioned backup validation/round-trip, safe repository replacement/deletion, malformed restore
preservation and data-management settings now have coverage. Full schema migration,
OS-process/device restart and protected-device storage remain separate acceptance gates.

A registry entry proves test wiring, not test quality or complete feature coverage. Each future
feature must add meaningful domain, integration and UI scenarios; a shared placeholder test alone
is not sufficient. Fixes must include a regression test where practical. Shared changes must run
the entire suite. Do not weaken/delete checks or add unconditional retries to hide a regression.

Physical acceptance still owns lock-screen notifications, Focus, permission changes, geofences,
Shortcuts, force-quit/reboot, Sideloadly upgrades/expiry, performance and real data recovery.
Android, WHOOP and unimplemented media features are not tested by this pipeline.

Build-4 source adds eight domain assertions and 21 action integration tests, plus notification-help
UI coverage. Tests exercise routing/category order, repeated deliveries, duplicate receipts after
Undo/restart, save/schedule/inbox faults, protected-store retry, Pause during Resume, cancellation,
expired/denied snooze, old-category repair, atomic inbox recreation/corruption/write-failure preservation,
legacy JSON payload decoding and a file-backed SwiftData reopen. These passed in run #10.
CI verifies the write options passed to the real file writer; actual
protection attributes are asserted only in device test runs because Simulator returns no metadata.
Build-6 adds pure Home decision tests for exit/entry, debounce, deliberate-pause precedence and
same-day guards; store integration tests for automatic pause/resume, manual override, outside Resume
suppression and same-day goal snapshots; plus a settings UI assertion. Run #18 passed all 37 domain
assertions, 34 integration/persistence tests, the UI test, simulator/device compilation and IPA inspection.
Injected protection failures do not prove
real locked-device access, background callback deadlines or system notification delivery.

Build-7 adds five integration tests covering `NotificationAuthorization`/`HomeAuthorization` tracking
on `SquatStore` (denied vs. restricted location, denied notifications) and `SettingsRoute` message
routing for Start/Resume-without-permission and Home-setup-denied paths, plus one UI-test assertion
for the new Notifications settings section. Run #22 passed all 37 domain assertions, 39
integration/persistence tests, the UI test, simulator/device compilation and IPA inspection. An
initial push (run #21, commit `58c6ff7`) failed because the new Notifications section pushed
`delete-squats-history` below the Settings form's initial fold, so the lazily rendered row was not
yet in the accessibility tree when a bare `.exists` check ran; the UI test now scrolls once more
before checking Data management buttons, matching the file's existing scroll-then-wait pattern.

Build-8 introduced two integration tests for remembered notification/Home authorization. A security
review found the implementation and tests too narrow: notification history depended on alert
availability, Home history counted only Always access, and neither test reconstructed the store.
Correction source `d80653da39433815c1d12fb9470adb9417a6f819` records granted notification enum states even
when alerts are disabled, records both When In Use and Always location grants, and exercises the
persisted flags plus revoked wording after store recreation. It also verifies that the Home boundary
file and containing directory are excluded from device backup. The totals remain 37 domain
assertions, 41 integration/persistence tests and one UI test; run #27 passed.

The initial PR run failed because Simulator returned no file-protection metadata. The test now
checks actual writer options and file durability in CI while retaining the filesystem protection
assertion for device tests. Its diagnostic artifact was successfully downloaded; no behavior check
was disabled, no failure was accepted as a pass, and no app protection setting was relaxed.

## Branch protection

GitHub now confirms a `main` branch-protection rule requiring strict/up-to-date `CI Gate`, enforcing
the rule for administrators, and disabling force pushes and branch deletion. Pull-request reviews
and actor restrictions are not required. Agents must still inspect the exact source SHA's
`CI Gate`, fix red checks and wait for success before declaring code/build work verified or
promoting an IPA. Prefer feature branches and PR validation for subsequent changes.

## GitHub Actions minutes and repository visibility

The private-plan account `akshatksingh18` was at ~94% of its 2,000 included Actions minutes this
billing cycle (resets 2026-10-01), because this project's macOS-runner CI (Xcode simulator/device
builds) consumes minutes quickly under GitHub's private-repo accounting; the account's Actions
budget is already set to $0 with "stop usage," so further private-repo runs simply block rather
than bill. GitHub Actions on standard hosted runners is free/unmetered for **public** repositories,
so the repository is now **public temporarily** to remove that cap, with the intent to revert it to
private once the CI-minutes need has passed. Before the switch, a fresh scan of every reachable
commit plus GitHub-side collaborators, PR content, webhooks, deploy keys and representative Actions
logs found no committed credentials, signing material, third-party personal data, or real Home
coordinates. Akshat explicitly accepted the low-risk local username/path and project-plan exposure;
history was not rewritten. All 26 previously retained Actions artifacts were deleted before the
switch. Branch protection was then enabled and server-verified as described above.

When Akshat says the public-CI need has passed, return the repository to private and update these
documents. That stops new public access but cannot undo source, logs, or artifacts already cloned,
forked, downloaded, indexed, cached, or otherwise copied while the repository was public.

## Failure workflow

1. Read the failing job/test and download its diagnostics; distinguish product failures from
   infrastructure outages. An infrastructure outage is not a passing test.
2. Reproduce safely, fix the cause, add regression coverage and rerun the pipeline.
3. Record verified source/run/artifact in `cloud-build.md`; preserve the previous verified IPA.
4. For future modules, extend this coverage description and registry with the implementation.

Pipeline mechanics are owned here; artifact/device evidence belongs in `cloud-build.md`.
