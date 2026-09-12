# AkshatOS CI and delivery contract

**Status:** Enforced on every pull request and on `main`. The public repository's `main` branch
requires a strict, up-to-date `CI Gate`; documentation-only PRs keep Source checks and the gate while
skipping the macOS build, which is directly verified. The gate result for the current source is
recorded in `cloud-build.md`, which owns artifact and device evidence; `../book-reader/CLAUDE.md` owns
PageVault's phone verification.

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
- `gh run watch --exit-status` has reported success for a failed run. Verify each job's conclusion
  directly before treating a run as green.

## Coverage and limits

Squats suites: domain assertions for event deduplication, Undo, streaks, dates, DST and time zones,
Home decisions and backup validation; integration tests for notification routing and category order,
repeated deliveries, duplicate receipts after Undo or restart, save/schedule/inbox faults,
protected-store retry, permission tracking and Settings routing, remembered grants across store
recreation, lifecycle idempotency, cadence persistence and the Done reset, bounded nudge refill and
migration, idle-start scheduling, Home pause/resume guards and backup exclusion, foreground repair,
file-backed SwiftData reopen, legacy payload decoding, daily aggregation and safe restore/deletion;
plus hub, dashboard and Settings UI coverage.

PageVault suites: 150 domain assertions covering place clamping and the opening page, progress
labels, title derivation, fingerprint dedupe, recency ordering, the single-Reading-book invariant,
the Started shelf split, older-payload decoding (including records carrying fields since removed,
such as the daily page goal), export/restore (manifest round trip, Windows-safe file names,
whole-manifest validation and versions, content-matched planning, add-only versus replace, id
collisions), page fitting (four-sided crop, outlier edges, short documents, facing pages, scans,
blank and unmeasured pages, specks, off-white paper, a no-clipping property and cache versioning),
highlights (rejoining selections broken at line ends and hyphens, duplicate and empty passages,
reading order, page lookup, the page-and-text match behind the toggle, the books Takeaways lists
and their order, record round trip, records written before highlights existed), search
(matching, case and accent insensitivity, result limits, one-letter queries, snippet context and
ellipses, pages with no text) and page themes (stored raw values, default, inversion, the retired warm theme mapping to sepia,
fallback).
36 hosted integration tests generate real PDFs to exercise streamed copy-on-import, duplicate
rejection, unreadable-file cleanup, the bookmarked place across store recreation, bookmarking claiming
the book and shelving the previous one under Started, finishing a book, cover generation, copy-only
removal, clearing reading-day rows left by an older build, carrying a warm-paper choice over to
themes, a full export restored into a fresh library, reading data restored onto a re-imported PDF, a
tampered PDF restoring nothing, add-only versus replace against a live library, malformed or
mis-picked exports, pages measured and cropped on all four sides, a wide figure never clipped, a
full-page scan left untouched, the measurement reused after relaunch and removed with its book, crop
boxes applied in points, a highlight saved and reloaded, highlighting the same passage again
removing it, highlights travelling with an export,
highlights rendered into their own PDF, and search over a real text layer including an image-only
page that finds nothing. UI tests cover hub → library → back, the backup sheet, and Takeaways reporting that nothing is
kept yet.

Simulator coverage cannot exercise the system document picker, the file mover that saves an export,
real large-file memory pressure, rotation, paged swipe feel, how warm paper looks, or whether fitted
pages read comfortably. Each reader change needs its own device pass, owned by
`../book-reader/CLAUDE.md`. OS-process/device restart and protected-device storage remain separate
acceptance gates.

A registry entry proves test wiring, not test quality or complete feature coverage. Each future
feature must add meaningful domain, integration and UI scenarios; a shared placeholder test alone
is not sufficient. Fixes must include a regression test where practical. Shared changes must run
the entire suite. Do not weaken/delete checks or add unconditional retries to hide a regression.

Physical acceptance still owns lock-screen notifications, Focus, permission changes, geofences,
Shortcuts, force-quit/reboot, Sideloadly upgrades/expiry, performance and real data recovery.
Android, WHOOP and unimplemented media features are not tested by this pipeline.

Testing lessons that still apply: Simulator returns no file-protection metadata, so CI asserts the
write options passed to the real file writer and leaves protection attributes to device test runs;
injected protection failures do not prove real locked-device access, callback deadlines or delivery.
Lazily rendered Form rows must be scrolled into view before a UI test checks that they exist.

## Branch protection

GitHub confirms a `main` branch-protection rule requiring strict/up-to-date `CI Gate`, enforcing
the rule for administrators, and disabling force pushes and branch deletion. Pull-request reviews
and actor restrictions are not required. Agents must still inspect the exact source SHA's
`CI Gate`, fix red checks and wait for success before declaring code/build work verified or
promoting an IPA. Documentation changes also land through a PR.

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
