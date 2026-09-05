# AkshatOS CI and delivery contract

**Status:** Build-6 Home/goal source `3037348257938dcd545838a7b54d5bd53dafccd1`
passed Source checks, Build installable IPA and CI Gate in
[PR #1 run #18](https://github.com/akshatksingh18/akshatos/actions/runs/33972978593).
Daily-history/recovery source `2ac71a10731a73012a4726bbada4d3609fea93cf`
passed Source checks, Build installable IPA and CI Gate in
[PR #1 run #14](https://github.com/akshatksingh18/akshatos/actions/runs/33906715819).
All 29 domain assertions, 29 integration/persistence tests and the hub/settings UI test passed. Real PR
triggering, failure diagnostics download and correction are exercised. Server-enforced private
branch protection remains unavailable under the current GitHub plan.
The unchanged application source on documentation revision `ede1e492bedf8bfbc8c76fb938a3a0676aa97b32`
also passed PR run #11 and delivery run #12; exact artifact/hash evidence belongs in `cloud-build.md`.

## Automated checks

- Every pull request to `main` runs the full pipeline, without path filters. Pushes to `main`
  run it for `ios/**` or the workflow; manual dispatch also runs everything. Documentation-only
  main pushes do not spend macOS build minutes. PR validation never uses `pull_request_target`.
- **Source checks**: logical module boundaries, feature test inventory and actionlint 1.7.12
  workflow syntax/expression checking. ShellCheck is disabled; this is not shell/security auditing.
- **Build installable IPA**: all registered feature domain executables, simulator compilation,
  hosted XCTest persistence tests, XCUITest navigation, device Release compilation, and IPA
  payload/identity inspection. New features must register their tests in `ios/tests/feature-tests.json`;
  domain suites run automatically. The unit/UI directories are included recursively by XcodeGen.
- **CI Gate**: succeeds only if both prerequisite jobs succeed. Failed, cancelled or unexpectedly
  skipped prerequisites do not count as a pass. This is the stable check name to require later.
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

The initial PR run failed because Simulator returned no file-protection metadata. The test now
checks actual writer options and file durability in CI while retaining the filesystem protection
assertion for device tests. Its diagnostic artifact was successfully downloaded; no behavior check
was disabled, no failure was accepted as a pass, and no app protection setting was relaxed.

## Branch protection limitation

The repository's branch-protection and ruleset APIs return HTTP 403: GitHub requires Pro (or another
eligible plan) for these protections on this private repository. No upgrade or visibility change
was made. **CI is active but is not a server-enforced merge/direct-push restriction.**

Until that changes, agents must inspect the exact source SHA's `CI Gate`, fix red checks and wait
for success before declaring code/build work verified or promoting an IPA. Prefer feature branches
and PR validation for subsequent changes. A human can still bypass this agreement manually.
If Akshat later upgrades, explicitly enable a `main` rule requiring `CI Gate`, an up-to-date branch
and no force pushes/deletions; inspect/preserve existing rules before doing so. Do not claim this
rule is enabled until the server confirms it.

## Failure workflow

1. Read the failing job/test and download its diagnostics; distinguish product failures from
   infrastructure outages. An infrastructure outage is not a passing test.
2. Reproduce safely, fix the cause, add regression coverage and rerun the pipeline.
3. Record verified source/run/artifact in `cloud-build.md`; preserve the previous verified IPA.
4. For future modules, extend this coverage description and registry with the implementation.

Pipeline mechanics are owned here; artifact/device evidence belongs in `cloud-build.md`.
