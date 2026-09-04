# AkshatOS CI and delivery contract

**Status:** Expanded pipeline implemented; first verification of the new persistence tests and gate
is pending. The previous build evidence remains in `cloud-build.md` until a new run passes.

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
hub entry/back/reopen and unavailable media entries. In-memory tests do not prove disk restart,
migration, protected-device storage, or the full SquatStore error/reconciliation lifecycle.

A registry entry proves test wiring, not test quality or complete feature coverage. Each future
feature must add meaningful domain, integration and UI scenarios; a shared placeholder test alone
is not sufficient. Fixes must include a regression test where practical. Shared changes must run
the entire suite. Do not weaken/delete checks or add unconditional retries to hide a regression.

Physical acceptance still owns lock-screen notifications, Focus, permission changes, geofences,
Shortcuts, force-quit/reboot, Sideloadly upgrades/expiry, performance and real data recovery.
Android, WHOOP and unimplemented media features are not tested by this pipeline.

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
