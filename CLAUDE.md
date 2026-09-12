# AkshatOS

Personal native iPhone hub: the home screen selects a feature, starting with Squat Reminder.
PageVault is the activated next module — its scope, phases, and progress are owned by
`../book-reader/CLAUDE.md`, and its source lives in `ios/AkshatOS/features/pagevault/`. ReelVault is reserved for
later; WHOOP stays standalone. This repository evolved
from Squat Reminder with history preserved. Android Squats remains an untouched, unverified fallback.

**Status:** Building. Squats' native v1 — lifecycle, notification actions, dashboard/Settings UI,
daily history and recovery, Home auto-pause and foreground reconciliation — is implemented, and
Build 13 is accepted in ongoing daily phone use; its edge-case, refresh/recovery and multi-cycle soak
matrix remains open. PageVault is implemented in source through export/restore and page fitting and
awaits one end-of-implementation device pass (`../book-reader/CLAUDE.md`). `cloud-build.md` owns build
evidence and the working source version; `todo.md` owns open gates. The full target contract below is
not a claim that every feature is physically verified.

## Files

- `handoff.md` — new-session entry point, current implementation/evidence boundaries and recommended
  continuation order; read to resume, then use its linked owning specifications and setup guides.
- `ci.md` — pipeline stages, docs-only PR classification, feature test registration, failure
  handling, coverage limits, public-repository operation, and `main` protection; read before
  changing CI or accepting a build.
- `ios/tests/feature-tests.json` — required per-feature domain/integration/UI test inventory.
- `ios/scripts/check-test-inventory.py` — validate inventory and run registered Swift domain suites.
- `ios/scripts/validate-ipa.py` — inspect unsigned artifact identity/payload before publication.
- `ios/UnitTests/` — hosted simulator XCTest tests for feature integration/persistence, not shipped.
- `ios/UnitTests/SquatsActionTests.swift` — notification routing, replay, protected-store fallback,
  scheduling/save failures and file/disk recovery regression tests.
- `ios/AkshatOS/features/squats/domain/SquatAction.swift` — shared action commands and delivery receipts.
- `ios/AkshatOS/features/squats/domain/SquatDaySummary.swift` — same-date aggregation, active/paused
  timing, goal status and detailed daily history.
- `ios/AkshatOS/features/squats/domain/SquatsBackup.swift` — versioned local JSON export/restore
  contract and whole-file validation.
- `ios/AkshatOS/features/squats/data/SquatActionInbox.swift` — atomic, after-first-unlock action inbox.
- `ios/AkshatOS/features/squats/domain/HomeAutomation.swift` — pure Home-boundary state, debounce,
  and source-aware pause/resume decisions.
- `ios/AkshatOS/features/squats/data/HomeAutomationStorage.swift` — protected this-device-only Home
  configuration and durable minimal boundary-event inbox.
- `ios/AkshatOS/features/squats/services/HomeRegionService.swift` — feature-owned protocol and
  inactive test/preview adapter; the app coordinator owns the Core Location delegate implementation.
- `ios/AkshatOS/features/squats/ui/HomeSetupView.swift` — one-shot Home map/radius confirmation UI.
- `ios/AkshatOS/features/squats/data/SquatRepository.swift` — retryable SwiftData persistence adapter.
- `hub-plan.md` — canonical shared packaging, source/identity ownership, feature boundaries,
  and integration gates; versioned here, with parent/sibling indexes linking to it.
- `CLAUDE.md` — canonical project instructions and the accepted end-to-end iPhone implementation,
  signing, refresh, testing, and fallback plan.
- `README.md` — current product/status overview, accepted iPhone behavior and caveats, build/
  installation boundary, and Android fallback evaluation steps.
- `features.md` — accepted dashboard, lifecycle, notification actions, completion counting,
  goal/streak rules, Home geofence, daily overview/history, optional Shortcuts automation, and v1
  scope; read before product work.
- `architecture.md` — accepted native-iOS scheduling/reconciliation plan plus the distinct current
  Android fallback stack/source design and cross-platform invariants.
- `todo.md` — prioritized iPhone implementation/physical-refresh gates and separate Android gaps;
  update items in place as their real state changes.
- `cloud-build.md` — exact GitHub Actions artifact, checksum, Windows download, Sideloadly smoke-
  install, and failure-handoff procedure; read before building or installing an iOS artifact.
- `setup.md` — keeping an installed build signed: the split between Sideloadly's refreshing daemon
  and the health check that proves it happened, what counts as success, the installed task and its
  paths, and the refresh/recovery gates still open. Read before changing anything about weekly
  signing.
- `scripts/check-signing-health.ps1` — the scheduled health check. Reports only a completed install
  moving forward as success, and only once corroborated — the install date past the first install and
  the new expiry in the future — because a changed record alone has already produced a refresh report
  for a refresh that never happened; an uncorroborated difference is logged as `RECORD-CHANGED`. A
  `-DatabasePath` test run is redirected to its own sidecar log/state so a fixture cannot write into
  the real record. Escalates to a blocking dialog when an app is close to expiry, errored, or
  uncheckable. Refreshes nothing itself. Never judge what it has recorded from an agent shell — those
  are sandboxed and read a redirected copy of the log; `setup.md` explains how to read the real one.
- `scripts/read-signing-state.py` — reads a read-only copy of Sideloadly's `installations.db` and
  emits per-app expiry as JSON; never touches the signing material stored beside it. Carries the
  documented `RETIRED_BUNDLE_PREFIXES` list so an app removed from the phone (Sideloadly keeps its
  row forever) is reported, not raised as a false alarm.
- `.github/workflows/ios-build.yml` — public-repository macOS-runner job that generates the Xcode
  project, runs domain/UI tests, compiles simulator/device builds, and packages the unsigned IPA/metadata.
- `ios/` — Windows-authored SwiftUI hub source, XcodeGen project specification, asset catalog,
  and deterministic icon generator; this is the canonical hub source tree.
- `ios/AkshatOS/app/` — composition/lifetime ownership, sole notification delegate, and `hub/`
  display-only picker with metadata and injected destinations; read for host integration changes.
- `ios/AkshatOS/app/OrientationGate.swift` — app-scope supported-orientation answer: portrait
  everywhere except an open PDF reader, which reports its presence instead of forcing rotation.
- `ios/AkshatOS/app/hub/HubNavigation.swift` — the one pending hub route, so a tapped notification
  opens the feature that sent it instead of leaving the last screen up. Plain hub state with no
  feature types or services; the namespace→route map lives in `AppNotificationCoordinator.swift`
  and the contract in `hub-plan.md`.
- `ios/AkshatOS/features/pagevault/` — PageVault: `domain/` (Foundation-only book/library logic plus
  reading status, the place marker, highlights with their band geometry, folding and area-based
  identity, search matching, snippets and find marks, page themes,
  page-fitting geometry and ink scanning, and the export manifest with restore planning),
  `data/` (versioned SwiftData store,
  streamed copy-on-import storage, export staging, disposable cover and page-measurement caches),
  `services/` (import-time PDFKit inspection, cover rendering, whole-book ink measurement, selection
  capture and the highlights PDF, page-text search), `ui/` (library grid, the page-curl reader with
  its fitting screen, book sheet, backup sheet, the per-book takeaways list, the Takeaways surface,
  search sheet, the page-jump picker). Product scope and
  gates are owned by `../book-reader/`. Its reading loop, the page curl, drawing highlights and
  jumping to a page from a search result are phone-confirmed; search itself, the page themes and the
  reworked highlighter are not. Build 22 found the highlighter stacking marks over each other
  because identity compared captured text rather than the page area covered; it now offers Highlight
  and Remove highlight explicitly and compares line bands, and that awaits a device pass.
- `ios/tests/pagevault/main.swift` — executable PageVault domain assertions run by the cloud workflow.
- `ios/UnitTests/PageVaultPersistenceTests.swift` — real copy-on-import, fingerprint dedupe,
  rejected/corrupt imports, the bookmarked place across store recreation, source-file-preserving
  removal, the single-Reading-book invariant and cover generation.
- `ios/UnitTests/PageVaultBackupTests.swift` — real-file export/restore: full export into a fresh
  library, reading data onto a re-imported PDF, a tampered PDF restoring nothing, add-only versus
  replace against a live library, and malformed or mis-picked exports.
- `ios/UnitTests/PageVaultLayoutTests.swift` — page fitting on generated PDFs: every page measured and
  cropped on all four sides, a wide figure never clipped, a full-page scan left untouched, the
  measurement reused after relaunch and removed with its book, and crop boxes applied in points.
- `ios/UnitTests/PageVaultHighlightTests.swift` — highlights saved through the store and reloaded,
  carried by a full export and restored, rendered into their own PDF, and refused when there are none.
- `ios/UnitTests/PageVaultSearchTests.swift` — search over a real text layer: every page carrying the
  phrase, case-insensitivity, one-letter queries refused, and nothing found in an image-only page.
- `ios/AkshatOS/shared/design-system/` — feature-independent colors and UI components.
- `ios/AkshatOS/features/squats/` — store, `domain/`, `data/`, `services/`, and `ui/`; owns
  reminder behavior/storage, but not the process-wide notification delegate.
- `ios/AkshatOS/Resources/` — app assets; existing icon generation path is unchanged.
- `ios/scripts/check-boundaries.py` — source dependency/delegate guard and negative fixtures;
  run locally and in CI. Logical boundaries, not compiler-enforced Swift packages.
- `ios/tests/squats/main.swift` — executable Squats domain assertions run by the cloud workflow.
- `ios/UITests/` — simulator hub/dashboard/PageVault navigation tests and screenshot attachments;
  test runner is not packaged in the device IPA and adds no installed app slot on Akshat's phone.
- `build.gradle.kts` — root Android build configuration and plugin versions.
- `settings.gradle.kts` — Gradle project and repository configuration.
- `gradle.properties` — project-wide Gradle and Android settings.
- `.gitignore` — Android/Gradle and generated iOS build-output plus local-environment exclusions.
- `app/` — Android application module, manifest, resources, and Kotlin source.

## iPhone-use plan

### Product and target decision

- Canonical source/build owner: this `akshatos/` repository, temporarily public GitHub
  `akshatksingh18/akshatos`, evolved from Squat Reminder without a second source copy.
  The native target is **AkshatOS**, bundle ID `com.akshatksingh18.akshatos`, with the working
  source version and per-build evidence owned by `cloud-build.md`. Build 13 is the last build
  accepted for Squats daily use, including automatic overdue nudges and the idle 9:00 AM start
  invitation, and Build 12 is its retained accepted predecessor. Later builds add PageVault. The broader physical edge-case and repeated-refresh matrix remains open.
  This is a new identity from the disposable smoke app, which Akshat removed; no user-history
  migration is implemented or needed for that featureless smoke. Preserve the hub ID going forward.
- Launch into the hub picker, then select Squat Reminder to open its dashboard. Returning to the
  picker must not stop reminders. PageVault/ReelVault cards are visibly unavailable, not fake apps.
  `architecture.md` owns implemented-vs-target details; `todo.md` owns unfinished work.

- The accepted iPhone interaction is: choose a whole-minute interval (45 minutes by default), use
  the configurable eight-set daily goal, tap
  **Start my day**, receive ordinary squat reminders, log completed sets, Pause/Resume around
  interruptions, protect a daily-goal streak, optionally auto-pause outside Home, and tap **End my
  day** for a local daily overview. `features.md` owns the exact dashboard, lifecycle,
  notification-action, counting/streak, geofence, history, and automation scope.
- Count explicit completed squat **sets/breaks** in v1. Do not infer individual repetitions or
  notification-delivery counts. Keep timestamped current-day events and lightweight local daily
  summaries, but do not add accounts, cloud sync, social features, remote analytics, or a server.
- The iOS app must use local UserNotifications scheduled by iOS. It must not depend on the app
  staying alive, a background timer, Web Push, a remote notification service, a Shortcut or
  Personal Automation, LiveContainer/JIT, or the Android phone. App Intents/Shortcuts are optional
  convenience entry points after the native core works, never the reminder engine.
- Use a single ordinary application target with no widget, Watch app, App Group, or notification-
  service extension. Core Location geographic-region monitoring and its honest usage descriptions
  are accepted for Home auto-pause. Add only the location/background configuration demonstrated to
  be necessary for region events on the target iOS version; never run continuous route/location
  tracking or retain movement history.

### Notification behavior

- Use one stable normal-request identifier and a bounded batch of one-off
  `UNTimeIntervalNotificationTrigger` requests. The first request is one selected interval after
  Start/Resume/Done (45 minutes by default); if ignored, follow it with 59 automatic nudges ten
  minutes apart. Together with the idle daily-start request this remains below iOS's pending-
  notification ceiling. Foreground reconciliation replenishes a low or exhausted batch from the
  persisted cadence anchor without shifting the clock. Never build an unbounded request list.
- **Start my day** requests notification authorization if its status is undetermined, verifies the
  resulting settings, creates a new active day, removes/replaces stale project requests, and adds
  the bounded request batch. Mark the state Running only after the requests are accepted. The
  first reminder occurs one selected interval after Start; no immediate reminder is implied.
- **Pause** cancels the active reminder batch without ending the active day.
  **Resume** adds a fresh batch whose first reminder is one full interval later. **End my day**
  cancels every project-owned active reminder, finalizes the session,
  and presents its overview. All lifecycle operations are idempotent.
- Register one actionable reminder category with **Done** then **Pause**. Done records one
  completion event, replaces every pending active reminder, and begins a fresh full interval from
  that completion whether the first reminder or automatic nudges were pending. Pause uses the same
  domain command as the dashboard. Build-12 snooze commands may still decode for compatibility but
  must be acknowledged as no-ops and must not appear in new UI/categories. Handle action responses through the notification-center delegate
  and persist before completing the background callback.
- When notification access has already been granted and no active day exists, keep exactly one
  repeating calendar notification for 9:00 AM local time. It invites the user to open AkshatOS and
  start; tapping it must not silently create a session. Starting a day cancels it, and returning to
  idle schedules it again. Tapping it opens the Squats screen, by the routing rule below — that is
  also why routing keys on the request identifier: this request carries no category.
- **Opening any notification opens the feature that sent it.** The app layer maps each feature's
  notification-identifier namespace to its hub route and asks the hub to go there; a background
  action such as Done or Pause deliberately does not move the screen. `hub-plan.md` owns this
  contract for every present and future module, including the rule that a new module registers its
  namespace alongside its category. Do not special-case a feature in the hub or let a feature learn
  what a hub route is.
- If permission is denied or notifications are disabled, Start must not display a healthy
  “Running” state. Show a clear blocked state and a route to the app's iOS notification settings.
  Do not repeatedly prompt after denial because iOS will not show the authorization sheet again.
- Pause and End remove already-delivered Squat Reminder notifications if that proves least
  surprising in physical testing. A notification already visible or being delivered at the exact
  moment of either action may still be seen; document the final observed behavior rather than
  promising an impossible atomic recall.
- Use ordinary local notifications, with ordinary sound/badge behavior only if useful. Do not make
  delivery depend on Time Sensitive notifications or Critical Alerts: users can disable Time
  Sensitive delivery, and Critical Alerts require special Apple approval/entitlements that do not
  fit a free personal build.
- Explain in the UI that Focus modes can silence or defer alerts, Scheduled Summary can collect
  non-urgent notifications, and per-app sound/banner settings can make an accepted request appear
  not to work. The app can inspect notification authorization/settings but cannot override those
  user choices.

### Persistence and reconciliation

- Keep idle interval/goal preferences in `UserDefaults`. Lifecycle intent belongs in the same
  versioned SwiftData session payload as its events, avoiding a separate divergent intent copy.
  Home configuration and minimal pending region events use separate protected, atomic files marked
  excluded from device backup. Store the Home coordinate/radius in protected local storage, never
  logs, backups, or remote services. Use a local versioned SwiftData store for
  active/finalized day sessions, completion timestamps, pause segments, snooze events, per-day goal
  snapshots, and streak qualification when the final deployment target is iOS 17 or later; fall back
  to Core Data or SQLite only if the activation toolchain/device makes SwiftData unsuitable.
- Notification actions can run while the phone is locked. Write each action through an idempotent,
  lock-safe command path; if the primary store is unavailable under data protection, durably queue
  the small action event and merge it into the main store on the next accessible foreground pass.
  Never lose a Done tap or apply one twice.
- On launch and every return to the foreground, query both
  `getNotificationSettings` and `getPendingNotificationRequests`. Reconcile the stored intent with
  the actual pending request instead of trusting persisted intent alone:
  - stored running + correct pending batch + usable permission = Running;
  - stored running + missing/wrong/drained batch = automatic foreground repair from the persisted
    cadence anchor, or a visible repair-required state if rescheduling fails;
  - stored paused/ended/not-started + unexpected active request = cancel the stale request;
  - revoked/disabled permission = blocked state even if a request remains pending.
- Interval edits are allowed only when no active day exists; Pause keeps the interval fixed for the
  still-active day. If that decision changes later, changing an active interval must atomically replace
  the pending request and update stored state only after replacement succeeds.
- A normal same-bundle refresh/update is expected to overwrite the binary while preserving its app
  container, settings, local history, and pending requests, but this must be proven on the physical
  phone. Never automate an uninstall as part of refreshing because uninstalling removes local data
  and pending requests.

### Dashboard, overview, and automation

- Build the dashboard around one readable state hero, a scheduled-next-reminder treatment, a large
  sets-completed-today count, configurable daily-goal progress, current/best streak, contextual
  lifecycle controls, and a compact completion-only **Your day so far** list showing Done events and
  their times. Do not show pause, resume, legacy snooze or reminder-maintenance events in that
  dashboard list. Persist each Start/Resume/Done cadence anchor so background/foreground or relaunch
  cannot restart the displayed interval. Before the anchor is due, the single main clock shows the
  normal interval; afterward it advances through ten-minute automatic-nudge deadlines. Any Done
  logs the set, removes pending nudges and starts a full regular interval. End requires confirmation and opens a
  summary with sets, goal result, start/end, active/paused duration, completion times, pause
  segments, snoozes, and interval. Same-date sessions aggregate into one local history entry.
  Export/restore uses a versioned local JSON file selected by the user; validation completes before
  replacement, and completed-history deletion preserves an active day and settings.
- Treat only explicit Done actions as completion evidence. iOS does not provide a dependable count
  of every notification actually presented under Focus/Scheduled Summary, so do not display a
  fabricated delivery count or completion percentage.
- A day qualifies once when its local-day set total reaches the configured threshold. New installs
  start at eight completed sets; zero explicitly disables goal tracking. Preserve the goal used per
  day, apply later goal changes prospectively, treat an unfinished current day as at risk rather
  than already broken, and deterministically recompute current/best streak after Undo or day edits.
  Do not add a grace/freeze or retroactive goal rewrite without an explicit later decision.
- Implement native Home auto-pause with one system-monitored circular geographic region, initially
  offering a configurable 150-meter radius. Request
  authorization only from an explanatory setup flow: use foreground access to choose/confirm Home,
  then request Always access for terminated/background delivery. Leaving pauses only a Running day;
  entering resumes only that same day when its pause reason is `homeAwayAutomation`. Persist no movement
  trail, debounce boundary noise, and provide edit/disable/delete controls.
- A deliberate Pause while already auto-paused replaces the automation reason so arrival cannot
  override it. Start while known Outside offers start-paused versus run-anyway; a confirmed manual
  Resume while Outside suppresses repeat exit auto-pauses until Home entry or End.
- Location denial/revocation, insufficient authorization, unavailable region monitoring,
  Background App Refresh off, reboot-before-first-unlock, or a missed event must show a degraded
  automation state with manual/notification fallback. Do not label Home automation healthy merely
  because a region was registered.
- After core behavior passes, add App Intents for Start, Pause, Resume, Log completed set, and End.
  Shortcuts Leave/Arrive and Focus/workout automations remain optional backup/alternate triggers.
  Native geofence and Shortcut events call the same idempotent commands, and neither may restart an
  ended day or override a manual/notification pause.

### Build and signing artifact

- The hub uses `com.akshatksingh18.akshatos`. Do not change it for retries or updates.
  The former `com.akshatksingh18.squatreminder` is historical smoke identity only; its IPA must
  never be relabeled as AkshatOS. Build 12 has passed physical signing/install acceptance under the
  permanent AkshatOS identity.

- Produce a plain release-mode IPA with no Sideloadly-specific injection, tweak, JIT, or private
  framework dependency. That standard artifact must remain signable by Sideloadly and portable to
  another compatible installer or direct Xcode deployment if the preferred tool stops working.
- New or changed iOS binaries still require macOS/Xcode, but Akshat has no local Mac. The accepted
  primary compiler is therefore the `.github/workflows/ios-build.yml` job on a
  pinned GitHub-hosted macOS/Xcode image. Windows authors source; XcodeGen creates the project on the
  runner; the job builds an unsigned ordinary device IPA and publishes its hash/build metadata.
- Keep Apple credentials, two-factor codes, certificates, provisioning profiles, device IDs, and
  Sideloadly state out of GitHub Actions. Download the unsigned artifact to trusted Windows storage,
  verify its SHA-256, and let Sideloadly perform personal signing/install locally.
- GitHub workflow artifacts are temporary delivery files, not the release cache. After a physical
  build is verified, copy the IPA to the stable portfolio cache with its version/build number and
  checksum. The
  weekly signing process should repeatedly re-sign that exact cached IPA; rebuilding is necessary
  only when the app changes or a new iOS/Xcode compatibility fix is required.
- Preserve a recovery path through a borrowed/rented Mac or another compatible macOS builder. The
  human-readable XcodeGen spec and standard unsigned IPA packaging must not depend on GitHub-specific
  runtime code, and a green cloud job never substitutes for physical-iPhone verification.
- Free Apple Personal Team provisioning is an Apple-controlled development path, not permanent
  installation: profiles normally expire after seven days and Apple authentication/signing
  services remain a dependency. Sideloadly can also require maintenance when Apple changes those
  systems. The design therefore depends on standard Apple APIs and a standard IPA, not on
  Sideloadly-specific runtime behavior.

### Windows Sideloadly refresh operation

- Use Sideloadly on the Windows machine as the primary signer/installer, configured for **Local
  Anisette** and its background refresh daemon. Complete the normal device trust/pairing setup and
  Developer Mode flow, use iTunes to enable **Sync with this iPhone over Wi-Fi**, and verify both USB
  and same-Wi-Fi detection. Sideloadly currently warns that wireless discovery can occasionally
  require iTunes to be open or the iPhone screen to be on, and some Windows pairing errors require
  the web/non-Microsoft-Store Apple components. Treat those as current setup caveats to re-check,
  and keep USB as the deterministic recovery route when wireless discovery fails.
- Do not run one job at the seven-day deadline. Start the daemon with Windows and attempt/check
  refresh daily (or at least every 48 hours), targeting a successful refresh while **three or more
  days remain**. This provides several retries for a sleeping PC, disconnected phone, Apple outage,
  expired pairing, authentication change, or Sideloadly breakage.
- Sideloadly describes the daemon as acting when an app is "near expiry" but does not document a
  user-configurable threshold. If the three-day health check has not observed success, use its
  supported **Refresh All Apps Manually**/normal same-IPA install path. Do not build blind GUI
  automation that treats opening Sideloadly, a process exit, or a changed cache timestamp as a
  successful phone installation.
- The Windows health check is **installed**: the `AkshatOS Signing Health` scheduled task runs at
  logon and twice daily, reads Sideloadly's own install record, and treats only a corroborated
  completed install moving forward as success — a quiet daemon, a clean process exit, or a merely
  changed install record is explicitly not proof. It
  escalates to a blocking dialog at two days or on any recorded error. Its scheduled execution is
  confirmed; the daemon's refreshing is not. `setup.md` owns the detail and the gates still open,
  including why an agent shell's sandboxed view of the log cannot be used to judge them. It deliberately refreshes nothing: Sideloadly's daemon does that, and a
  second signer racing it would be worse than none.
- After the first install and after the first several refresh cycles, open the app and confirm its
  running/interval state and pending notification request survived. Once the process is trusted,
  keep periodic manual launch checks in addition to automated signing verification.
- If the profile expires, treat that as an operational failure even if an already-scheduled local
  notification happens to appear. The app may stop launching and post-expiry delivery is not a
  supported guarantee. Restore signing over USB if needed, reinstall over the existing same-bundle
  app, then let foreground reconciliation verify or re-arm the reminder. Do not uninstall first.
- Keep the current working Sideloadly installer/configuration available locally, but assume an
  Apple-side change can still invalidate an old release. The recovery path is to update or replace
  the signer while keeping the bundle ID and cached standard IPA unchanged.

### Accepted free-account app-slot portfolio

- Install one native hub for Squats, PageVault, and ReelVault, plus standalone WHOOP: two free slots.
  One slot remains unallocated. No paid membership, rotation, on-device app launcher, or extra
  installation identity per module is required. Packaging is accepted; implementation is pending.
- The hub's notification/geofence handlers belong to the application lifecycle, not the Squats
  screen. Reading PDFs or playing reels must not stop scheduling or action processing. Show
  foreground notifications appropriately; namespace requests/categories/actions and cancel only
  Squats-owned requests. Never let navigation disable Home monitoring.
- OS permissions, icon/notification identity, update, profile expiry, process failure, and uninstall
  apply to the hub as a whole. Keep module stores/export logically separate and test cross-section
  behavior. Deleting the hub removes all three modules' local data, so full recovery is mandatory.
- Use Windows Sideloadly, no phone-side host. Another signer is an explicit workflow choice; the
  spare slot is not automatic permission to add it. Free seven-day expiry/early refresh still apply.
- `hub-plan.md` owns source/build ownership and identity reconciliation before coding.
  The hub target/workflow now live here; the old downloaded smoke IPA remains a separate historical artifact.

### Current authoritative constraints

- Re-check Apple's current free-account limits before first deployment and after any policy
  change. Apple's account documentation currently allows up to ten App IDs and three devices, both
  expiring after seven days, plus three installed apps per device and seven-day provisioning
  profiles:
  <https://developer.apple.com/help/account/basics/about-your-developer-account/>.
- The no-local-Mac build uses GitHub-hosted macOS runners and the pinned Xcode version available on
  that image. The repository is temporarily public so standard hosted-runner use does not consume the
  private-repository Actions-minute allowance. Re-check runner
  availability before toolchain changes: <https://docs.github.com/en/actions/reference/runners/github-hosted-runners>.
- XcodeGen turns the versioned `ios/project.yml` into the ephemeral Xcode project on the runner;
  keep its version pinned and re-verify generation when changing it:
  <https://github.com/yonaskolb/XcodeGen>.
- The notification design is based on Apple's documented repeating time-interval trigger, whose
  repeating interval must be at least 60 seconds, and on local notifications being scheduled by
  the system rather than an in-process timer:
  <https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger/init%28timeinterval%3Arepeats%3A%29>
  and
  <https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app>.
- Apple supports actionable notification categories and background handling of selected actions.
  Compact presentations may display only the first two category actions, so verify action order and
  availability on the physical phone:
  <https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types>,
  <https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions>,
  and <https://developer.apple.com/documentation/usernotifications/unnotificationcategory/actions>.
- App Intents expose app commands to Shortcuts/Siri without making them the native reminder engine.
  Apple's current Shortcuts guide lists Arrive and Leave among personal automations that can be
  configured to run automatically; re-check target-iOS behavior during physical setup:
  <https://developer.apple.com/documentation/appintents>,
  <https://developer.apple.com/documentation/appintents/app-shortcuts>, and
  <https://support.apple.com/guide/shortcuts/welcome/ios>.
- Core Location geographic-condition monitoring can wake an iOS app for region changes. Reliable
  terminated-app delivery requires Always authorization; region events remain approximate and must
  be treated as a convenience with observable fallbacks. Re-check the selected API and capability
  configuration against the final deployment target:
  <https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions>,
  <https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services>,
  and <https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background>.
- Re-check the official Sideloadly FAQ and changelog before activation or after an iOS/Apple-login
  change. They document current iOS support, same-bundle overwrite behavior, background refresh,
  wireless-detection caveats, retry behavior, and recent Apple-authentication fixes:
  <https://sideloadly.io/faq.html> and <https://sideloadly.io/changelog>.

### Physical-device verification

The iOS app is not done based on simulator behavior. Verify on Akshat's actual iPhone, recording
current observed behavior in the applicable project document rather than relying on assumptions:

- permission first-run, allow, deny, later enable, and later revoke flows;
- 1-minute development interval plus the normal intended interval;
- repeated Start, Pause, Resume, and End; Pause/End just before delivery; starting again after End;
  and attempted interval changes while Running or Paused;
- Done from the dashboard and locked-screen notification, accidental-tap Undo, duplicate callback
  protection, and durable merge of an action received while protected files are unavailable;
- automatic ten-minute nudges after an ignored normal reminder, stable foreground/relaunch countdown,
  Done before/after nudge delivery, batch replenishment, Pause/End with nudges pending, and two-action
  notification ordering in compact/expanded UI;
- idle 9:00 AM start delivery, tap-to-open without auto-start, cancellation on Start, restoration
  after End, and behavior across time-zone/clock changes;
- daily summary correctness across start/end, pause segments, legacy snoozes, completions, local midnight,
  time-zone changes, relaunch, and same-day restart confirmation;
- goal/streak behavior below, exactly at, and above the chosen threshold; current-day at-risk state;
  skipped days; same-day multiple sessions; Undo/past-day edits; prospective goal changes; current/
  best recomputation; midnight, daylight-saving, clock, and time-zone changes;
- Home setup/edit/disable/delete; When In Use → Always authorization, denial/revocation/reduced
  accuracy, region-monitoring unavailability, enter/exit while foreground/background/terminated,
  force-quit, boundary jitter/duplicate events, Background App Refresh off/on, reboot before/after
  first unlock, Start/Resume while outside, deliberate-pause precedence, missed-event reconciliation,
  and proof that no route/location history is retained;
- foreground, locked screen, ordinary background, explicit force-quit, device reboot, and Low
  Power Mode;
- notifications while a representative Focus mode and Scheduled Summary are enabled, confirming
  the UI explains any silence/delay rather than claiming guaranteed interruption;
- notification/banner/sound settings changed outside the app;
- a real Sideloadly refresh over Wi-Fi and over USB using the same IPA/bundle ID, proving that
  `UserDefaults`, the installation container, and reminder reconciliation remain sound;
- Windows reboot, Sideloadly daemon restart, phone absent during an attempted refresh, later retry,
  pairing/authentication failure, and the visible expiry-warning path;
- App Intents invoked from Siri/Shortcuts plus optional Leave/Arrive and Focus automations; prove
  native and Shortcut boundary events remain idempotent and that arrival cannot resume an ended day
  or a day paused manually; document disabled/failed automation behavior;
- a controlled expiry/recovery exercise on a disposable/test state before trusting automation;
  never use “pending notifications might survive expiry” as a success condition;
- multiple consecutive seven-day signing cycles without uninstalling, changing bundle IDs, losing
  state, or requiring a Shortcut.

### Phased implementation plan

Execution order: finish the agreed native Squats v1 implementation and automated/cloud checks
before asking Akshat for physical-phone testing. Sideloading is reported working; do not make
another installation exercise a prerequisite for continued coding. Physical acceptance remains
required after implementation, with defects found there fixed before calling the feature dependable.
`handoff.md` and `todo.md` own the current implementation-first work order. Optional Shortcuts
remain a follow-on; this sequencing change does not expand native v1 or activate media modules.

1. **Hub transition and cloud activation:** source/repository and bundle ID are selected and the
   target/workflow is adapted. Pass cloud tests/build and physical hub-picker → Squats navigation
   before calling this new identity phone-verified; see `cloud-build.md`.
2. **Product and visual foundation:** replace the smoke screen with reusable dashboard tokens/
   components while preserving the permanent bundle ID, add the explicit lifecycle state model,
   goal/streak presentation, and notification/location permission-status surfaces, and leave
   Android intact.
3. **Reliable lifecycle:** implement validated interval input, Start/Pause/Resume/End, the bounded
   normal-plus-automatic-nudge batch and idle daily-start request, SwiftData intent and versioned day/event storage,
   idempotent domain commands, and foreground reconciliation. Gate optional automation on this core.
4. **Actions and insight:** implement Done +1, notification actions, lock-safe action persistence,
   Undo, Today timeline, per-day goal snapshot, deterministic current/best streak calculation,
   finalized daily summaries/history, and the end-of-day overview. Verify the summary never treats
   scheduled/delivered reminders as completed sets.
5. **Home automation:** implement one locally stored geographic Home condition, staged When In Use
   then Always authorization, pause-source guards, boundary-event deduplication, automation health,
   and edit/disable/delete. Use region monitoring, not continuous tracking, and keep every manual
   fallback working.
6. **Native verification:** build through macOS/Xcode and complete action ordering, locked/background/
   force-quit, reboot, Focus/Summary, Low Power Mode, permission, automatic nudges, lifecycle, persistence, and
   day-boundary, goal/streak, geofence, Background App Refresh, and authorization tests on the
   physical iPhone.
7. **Optional Shortcut automation:** expose App Intents and prove Leave/Arrive or Focus automations
   on the target iPhone as backup/alternate triggers, including pause-source guards, duplicate native
   plus Shortcut events, and failure states.
8. **Portable release:** produce and checksum a clean release IPA; prove same-bundle overwrite and
   state/history/request reconciliation first through a direct reinstall and then through Sideloadly.
9. **Reliable refresh:** configure Local Anisette, Windows-start daemon, early retries, verified
   success records, expiry alerts, and USB recovery; exercise failure and expiry recovery.
10. **Soak:** run through multiple profile cycles before calling it dependable. Only after the iOS
   path is stable should nonessential rep tracking, streak freezes, deeper charts/achievements, or
   Android parity work resume.

### iPhone done criteria

The iPhone path can be described as working only when all of the following are true:

- the standard release IPA installs and launches on the actual iPhone under free Personal Team
  signing, with its permanent bundle ID and no unsupported entitlement dependency;
- a clean checkout can regenerate the Xcode project and IPA through the documented macOS workflow;
  its bundle/version/architecture and checksum are inspected, no Apple secrets enter GitHub, and the
  artifact is copied out of temporary Actions storage after physical verification;
- Start creates one bounded normal-plus-nudge local-notification batch; Pause removes it without
  ending the day; Resume safely recreates it; End removes active project requests and finalizes the
  day; and the UI reconciles permission, requests, interval, and stored state truthfully;
- ignored normal reminders lead to automatic ten-minute nudges until Done/Pause within the bounded
  scheduled horizon, foreground reconciliation replenishes that horizon, idle days have one 9:00 AM
  start invitation, and tapping it never auto-starts a session;
- Done from both dashboard and notification records exactly one set, resets a full normal interval,
  and the Today timeline/history/end summary survive
  relaunch, locked action handling, and in-place upgrade without duplication or loss;
- the configurable daily goal, current/best streak, at-risk state, qualification history, and
  prospective goal changes remain correct across End, skipped days, Undo, relaunch, local midnight,
  daylight-saving changes, and time-zone changes;
- expected behavior is physically verified across background/force-quit, reboot, Low Power Mode,
  notification-setting changes, actionable-notification presentation, and the documented Focus/
  Summary caveats;
- optional Home auto-pause uses one local-only system geofence, pauses/resumes only the appropriate
  active day, never records a movement trail, reports degraded authorization/system conditions, and
  leaves the manual and notification controls fully usable when no region event arrives;
- the core loop remains complete without Shortcuts; optional native and Shortcut automations share
  idempotent source-aware commands and cannot resume an ended or deliberately paused day;
- same-bundle Sideloadly refresh preserves local state through multiple cycles, daily/early
  automation proves success rather than merely running, expiry risk raises a visible alert, and
  USB recovery has been rehearsed;
- the common hub IPA can be signed by a fallback path without source changes, coexists with
  standalone WHOOP in two free slots, and preserves all three modules across refresh/upgrade;
- Squats actions and Home events work without opening its section, including while PageVault/Reels
  is visible, and their module transitions cannot cancel requests or delay durable action handling;
- Android remains buildable as a fallback or is still explicitly documented as unverified—do not
  silently imply parity between the platforms.

## Repository and hosting

The project is backed up to the temporarily public GitHub repository
<https://github.com/akshatksingh18/akshatos>; local `main` tracks `origin/main`. Akshat authorized the
visibility change after a fresh full-history and GitHub-surface security review, accepted the
low-risk local username/path exposure without rewriting history, and had all 26 retained Actions
artifacts deleted before the switch. The intent is to return to private once the public-CI need has
passed. Doing so will stop new public access but cannot undo anything cloned, forked, downloaded,
indexed, or cached while public. `ci.md` owns the operational details and verified `main` protection.
GitHub stores source and documentation only—not Apple credentials, signing material, provisioning
data, device state, or durable release IPAs.

## Working agreement

- **Continuous verification is automatic:** every feature/fix must add or update meaningful tests,
  register new feature suites, and pass the exact commit's GitHub Actions `CI Gate` before claiming
  verification or promoting an IPA. Inspect failures and fix the cause; never bypass or weaken tests
  to make a build green. Prefer PRs for subsequent code changes. Follow `ci.md`, including the
  server-enforced `main` protection and docs-only PR classification.
- Documentation synchronization is an automatic completion step; Akshat must never need to request
  it separately. Before every final response after code/configuration work, a plan decision, build or
  signing progress, or a reported phone test, audit the full applicable `CLAUDE.md` chain plus
  `README.md`, `features.md`, `architecture.md`, `todo.md`, `cloud-build.md`, and affected workflows/
  setup guides. Update current-state wording in the same change, commit and push repository-backed
  updates when publishing the project work, and state which documents changed or why none needed to.
- **Sync documentation locally as work happens, but do not push a PR for every small finding.**
  Akshat's correction: a PR-plus-CI round trip per minor doc note or script tweak is redundant
  ceremony. Batch related small changes and push them together once there is a meaningful chunk of
  work, or the change is large enough to stand alone. Still push immediately when Akshat needs the
  result right away — a build he is about to install, or a fix he is waiting on to test.
- Treat each new hub feature as unverified until it passes its tests and physical-device run; do
  not describe intended behavior as tested behavior. Track iPhone and Android verification
  separately.
- Preserve the local-only, single-user Squats feature scope within the accepted three-module hub;
  packaging consolidation does not add new product features or activate WHOOP.
- Treat `features.md` as the product-scope source of truth. Preserve the accepted dashboard,
  Start/Pause/Resume/End lifecycle, explicit-set counting, daily goal/streak, Home auto-pause, daily
  overview, and notification actions; keep optional Shortcuts automation distinct from the
  dependable native core.
- Read `architecture.md` before changing notification/alarm, reboot, permission, reconciliation,
  action handling, day/session persistence, streak, Core Location/geofence, Shortcuts, or lifecycle
  behavior on either platform.
  When the iOS target is created, replace planned architecture statements with implemented details,
  add/index exact setup documentation, and keep Android fallback behavior explicitly separate.
- Keep actionable implementation gaps in `todo.md`; remove or rewrite an item when its current
  state changes instead of appending dated progress notes. Do not mix unimplemented iPhone work
  into statements that describe the current Android scaffold as already working.
- Preserve the permanent iOS bundle ID, ordinary/actionable-notification design, standard portable
  IPA, local-only Home boundary, deterministic streak rules, and early verified refresh buffer
  unless Akshat explicitly changes the deployment strategy.
- Read `cloud-build.md` before changing the iOS project generator, workflow, artifact packaging,
  bundle identity, checksum process, or Sideloadly smoke-install steps. Never add Apple credentials,
  signing files, device identifiers, or release IPAs to Git/GitHub.
- Treat Sideloadly as a replaceable signer/installer, not an application runtime or proprietary
  build target. Never couple reminder behavior to it.
- Any material product, platform, scheduling, permission, location, streak, persistence, build/
  signing, status, or recovery decision must update this file and every affected current-state document—
  especially `features.md`, `README.md`, `architecture.md`, and `todo.md`—in the same change. Keep
  iPhone plan, iPhone implementation, Android fallback, and physical verification claims explicitly
  separate.
- **Whenever a new file is added to this folder**, add a bullet for it under `## Files` above,
  in the same edit, with a one-line description of what it's for.
