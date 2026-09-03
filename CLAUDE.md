# Squat Reminder

Personal, local-only squat-reminder app with a daily Start/Pause/Resume/End lifecycle, actionable
interval notifications, completed-set tracking, streak motivation, optional Home-geofence
auto-pause/resume, and a daily overview. The primary target is now Akshat's iPhone; the current
Kotlin/Compose Android scaffold is preserved as a fallback for the old Android phone. Both variants
are personal sideloads only: no backend, account, remote analytics, App Store, or Play Store release.

**Status:** iPhone cloud-build smoke scaffold now passes private GitHub Actions compilation,
packaging, Windows download, and checksum verification, but is not yet signed, installed, or opened
on the physical phone; Android fallback remains unverified. Moves to Building after this IPA passes
the Sideloadly open test and dashboard implementation begins.

## Files

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
- `.github/workflows/ios-build.yml` — private macOS-runner job that generates the Xcode project,
  compiles simulator/device smoke builds, packages the unsigned IPA, and uploads verified metadata.
- `ios/` — Windows-authored SwiftUI smoke source, XcodeGen project specification, asset catalog,
  and deterministic placeholder-icon generator; this is the iPhone source tree.
- `build.gradle.kts` — root Android build configuration and plugin versions.
- `settings.gradle.kts` — Gradle project and repository configuration.
- `gradle.properties` — project-wide Gradle and Android settings.
- `.gitignore` — Android/Gradle and generated iOS build-output plus local-environment exclusions.
- `app/` — Android application module, manifest, resources, and Kotlin source.

## iPhone-use plan

### Product and target decision

- Build a **separate native iOS app in SwiftUI** rather than translating the Android alarm chain,
  wrapping the Android project, using Shortcuts, or treating a PWA as the reminder engine. Keep it
  in this repository under `ios/` as its own generated Xcode target/source tree; do not replace or
  delete the Android fallback. The current screen is only an installation smoke test.
- The accepted iPhone interaction is: choose a whole-minute interval (45 minutes by default), tap
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

- Use one stable normal-request identifier and a repeating
  `UNTimeIntervalNotificationTrigger(timeInterval:repeats:)`. Convert the validated whole-minute
  setting to seconds, default it to 45 minutes, and enforce the iOS repeating-trigger minimum of
  **60 seconds**. Allow at most one separate, stable one-off snooze request; never create an
  unbounded list of future requests.
- **Start my day** requests notification authorization if its status is undetermined, verifies the
  resulting settings, creates a new active day, removes/replaces stale project requests, and adds
  the single repeating request. Mark the state Running only after the request is accepted. The
  first reminder occurs one selected interval after Start; no immediate reminder is implied.
- **Pause** cancels the recurring request and any pending snooze without ending the active day.
  **Resume** adds a fresh recurring request and schedules its first reminder one full interval
  later. **End my day** cancels every project-owned normal/snooze request, finalizes the session,
  and presents its overview. All lifecycle operations are idempotent.
- Register one actionable reminder category. Order its actions **Done**, **Pause**, then **Remind
  me in 10 min** because compact notification interfaces may show only the first two actions.
  Done records one completion event without altering the regular cadence; Pause uses the same
  domain command as the dashboard; 10 min schedules/replaces one one-off snooze and leaves the
  underlying cadence in place. Handle action responses through the notification-center delegate
  and persist before completing the background callback.
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

- Keep settings, current lifecycle intent, stable identifiers, daily-goal configuration, geofence
  enablement/health, and a schema/version key in `UserDefaults`. Store the Home coordinate/radius in
  protected local storage, never logs or remote services. Use a local versioned SwiftData store for
  active/finalized day sessions, completion timestamps, pause segments, snooze events, per-day goal
  snapshots, and streak qualification when the final deployment target is iOS 17 or later; fall back
  to Core Data or SQLite only if the activation toolchain/device makes SwiftData unsuitable.
- Notification actions can run while the phone is locked. Write each action through an idempotent,
  lock-safe command path; if the primary store is unavailable under data protection, durably queue
  the small action event and merge it into the main store on the next accessible foreground pass.
  Never lose a Done tap or apply one twice.
- On launch and every return to the foreground, query both
  `getNotificationSettings` and `getPendingNotificationRequests`. Reconcile the stored intent with
  the actual pending request instead of trusting `UserDefaults` alone:
  - stored running + correct pending request + usable permission = Running;
  - stored running + missing/wrong request = visible repair-required state, with an explicit
    re-arm action (or a carefully tested automatic repair while foregrounded);
  - stored paused/ended/not-started + unexpected recurring request = cancel the stale request;
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
  lifecycle controls, and a compact Today event timeline. End requires confirmation and opens a
  summary with sets, goal/streak result, start/end, active/paused duration, completion times, pause
  segments, snoozes, and interval. Keep finalized daily summaries local.
- Treat only explicit Done actions as completion evidence. iOS does not provide a dependable count
  of every notification actually presented under Focus/Scheduled Summary, so do not display a
  fabricated delivery count or completion percentage.
- A day qualifies once when its local-day set total reaches the configured threshold. The initial
  threshold remains deliberately unset until Akshat chooses it. Store the goal used per day, apply
  later goal changes prospectively, treat an unfinished current day as at risk rather than already
  broken, and deterministically recompute current/best streak after Undo or day edits. Do not add a
  grace/freeze or retroactive goal rewrite without an explicit later decision.
- Implement native Home auto-pause with one system-monitored circular geographic region. Request
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

- Use `com.akshatksingh18.squatreminder` as the candidate permanent reverse-DNS bundle identifier.
  It becomes fixed after the first successful phone install; use the same Apple Account/team and
  identifier on every later build and refresh, and do not let build scripts or Sideloadly generate
  changing identifiers.
- Produce a plain release-mode IPA with no Sideloadly-specific injection, tweak, JIT, or private
  framework dependency. That standard artifact must remain signable by Sideloadly and portable to
  another compatible installer or direct Xcode deployment if the preferred tool stops working.
- New or changed iOS binaries still require macOS/Xcode, but Akshat has no local Mac. The accepted
  primary compiler is therefore the private-repository `.github/workflows/ios-build.yml` job on a
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
- Add a Windows health check when implementation reaches deployment. It must record and verify the
  last successful re-sign/install, distinguish “attempted” from “succeeded,” retry with a bounded
  cadence, and raise a visible failure alert no later than two days before profile expiry. A quiet
  daemon or successful process exit alone is not proof that the phone received a fresh profile.
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

### Free-account app-slot portfolio

- Plan around the free Personal Team limit of three simultaneously installed development apps on
  the iPhone:
  1. Squat Reminder native iOS app — one slot.
  2. WHOOP personal native iOS app — one slot.
  3. PageVault native iOS app — one slot.
- This deliberately fills all three free-development-app slots. There is no standing fourth slot
  for test builds, helper apps, AltStore, or SideStore. Replace an existing app temporarily, merge
  scope deliberately, or use a different signing account/tier before installing another personal
  development app. Do not count ordinary App Store apps against this development-app portfolio.
- A PageVault PWA can remain an emergency non-native fallback, but it is not the selected primary
  plan and must not be used to claim that a free development slot is available.
- Sideloadly runs from Windows and does not itself install a permanent host app that consumes one
  of these slots. By contrast, SideStore or AltStore installs its own on-phone host app: keeping
  either installed would require removing one of the three planned native apps. Confirm the
  current Apple/tool limits before switching because they can change.

### Current authoritative constraints

- Re-check Apple's current free-account limits before first deployment and after any policy
  change. Apple's account documentation currently allows up to ten App IDs and three devices, both
  expiring after seven days, plus three installed apps per device and seven-day provisioning
  profiles:
  <https://developer.apple.com/help/account/basics/about-your-developer-account/>.
- The no-local-Mac build uses GitHub-hosted macOS runners and the pinned Xcode version available on
  that image; private repositories consume the account's Actions-minute allowance. Re-check runner
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
- 10-minute snooze replacement, its interaction with the unchanged regular cadence, repeated
  snooze, Pause/End with a snooze pending, and notification action ordering in compact/expanded UI;
- daily summary correctness across start/end, pause segments, snoozes, completions, local midnight,
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

1. **Cloud-build activation:** generate the smoke target from `ios/project.yml`, pass simulator and
   unsigned-device compilation, download/checksum the IPA, and prove that Sideloadly can sign,
   install, and open it on the physical iPhone with the candidate permanent bundle ID.
2. **Product and visual foundation:** replace the smoke screen with reusable dashboard tokens/
   components while preserving the permanent bundle ID, add the explicit lifecycle state model,
   goal/streak presentation, and notification/location permission-status surfaces, and leave
   Android intact.
3. **Reliable lifecycle:** implement validated interval input, Start/Pause/Resume/End, the single
   repeating request plus one snooze request, `UserDefaults` intent, versioned day/event storage,
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
   force-quit, reboot, Focus/Summary, Low Power Mode, permission, snooze, lifecycle, persistence, and
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
- Start creates exactly one correct repeating local-notification request; Pause removes it without
  ending the day; Resume safely recreates it; End removes all project requests and finalizes the
  day; and the UI reconciles permission, requests, interval, and stored state truthfully;
- Done from both dashboard and notification records exactly one set, 10-minute snooze never
  accumulates requests or records completion, and the Today timeline/history/end summary survive
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
- the cached IPA can be signed by a fallback path without source changes, and Squat Reminder,
  WHOOP, and native PageVault together fit the agreed three-slot portfolio;
- Android remains buildable as a fallback or is still explicitly documented as unverified—do not
  silently imply parity between the platforms.

## Repository and hosting

The project is backed up to the private GitHub repository
<https://github.com/akshatksingh18/squat-reminder>; local `main` tracks `origin/main` after the first
push. Keep it private unless Akshat explicitly decides to make it public after a separate privacy,
licensing, history, and secret review. GitHub stores source and documentation only—not Apple
credentials, signing material, provisioning data, device state, or release IPAs.

## Working agreement

- Treat this as an unverified scaffold until it passes a clean physical-device build and run; do
  not describe intended behavior as tested behavior. Track iPhone and Android verification
  separately.
- Preserve the local-only, single-user, one-purpose scope unless Akshat explicitly changes it.
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
