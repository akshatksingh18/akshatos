# AkshatOS — shared integration contract

**Status:** Integration implementation activated — AkshatOS owns the native hub and Pushup-first
build. PageVault is active and phone-accepted through Build 24; Akshat explicitly added Lift Log as
a local-only strength utility in working Build-26 source. Lift Log is not compiled or phone-verified
yet and is owned by `lift-log.md`. ReelVault remains a later module and WHOOP stays standalone.
Build/phone progress belongs in `cloud-build.md`, not this integration contract.

## Installed applications

- **AkshatOS (accepted hub display name):** one SwiftUI application with Pushup Reminder,
  PDF Reader/PageVault, Lift Log, and Reels/ReelVault sections, one entry point, bundle ID, profile,
  and IPA.
- **WHOOP:** its existing Flutter app remains independently built, installed, refreshed, and tested.
  Keep its native BLE restoration, database, and encrypted export/recovery separate from the hub.

Two apps fit the free Personal Team allowance of three installed development apps; the third slot
is unallocated, not an instruction to add a helper. All five product functions can be available
without rotation or paid membership. This is source-level feature composition, not four guest
IPAs, a PWA, LiveContainer, or an iOS extension workaround. No Flutter embedding is required.

## Native hub boundaries

App composition/navigation lives under `ios/AkshatOS/app/`, reusable UI under `shared/`, and each
feature under `features/<feature>/`. Features must not depend on other features or the host;
the host wires their entry points. `architecture.md` owns exact boundaries and checks.

- Use one native SwiftUI host and four feature modules; module names need not be separate
  application targets. Keep existing feature requirements and Android fallbacks intact.
- A simple home/section selector opens each experience. Load PDF documents and video players only
  when needed and release them on exit; preserve each module's state when switching.
- Host-level Pushups services schedule local notifications and handle actions/Home-region events
  regardless of the selected screen. Navigating to a PDF or reel must not stop an active day.
- Register a central notification delegate/action router early. Namespace request/category/action
  identifiers; Pause/End cancel only Pushups-owned notifications. Make foreground reminder behavior
  explicit while reading/watching and keep Done/Pause/Snooze idempotent across locked callbacks.
- **Opening a notification opens the feature that sent it**, not whatever screen was last on
  display. This is a shared hub contract, so it is designed once for every present and future
  module rather than special-cased per feature:
  - Each feature namespaces its notification request identifiers (Pushups: `akshatos.squats.`) and
    exposes that namespace. The app layer maps namespace → hub route in
    `app/AppNotificationCoordinator.swift`; the feature never learns what a hub route is.
  - Route on the **request identifier**, not the category. Not every notification declares a
    category — Pushups' 9:00 AM invitation does not, and that is the one whose entire purpose is to
    open its feature.
  - Only opening the notification itself navigates. A background action such as Done or Pause must
    not move the screen, or logging a set would pull the reader off the page being read.
  - The request is plain hub state (`app/hub/HubNavigation.swift`), so `app/hub/` still owns no
    services. It holds one pending route, not a queue: two notifications tapped in a row land on
    the second.
  - **A new module adds its namespace to that map in the same change that registers its category.**
    Forgetting is not a breakage — an unclaimed notification routes nowhere and the hub stays put,
    which is the old behaviour.
- One hub means one system notification identity and permission settings. Explain that location
  permission serves Pushups, selected video access serves Reels, and Files import serves libraries
  and explicit Lift Log backup/restore; logging a workout itself requests no permission.
  Request permissions when their feature is used; do not require location to read a PDF.
- Version module metadata independently in logically separate stores/directories with namespaced
  settings. Separation is organizational, not an OS security sandbox between modules. No cloud
  sync or cross-module data sharing is implied.
- Provide per-feature and full-hub export/restore before retaining irreplaceable data. PDF/video
  copies, headlines/bookmarks, and Pushups history/goals need recovery; disposable caches do not.
- Update, profile expiry, process crashes/force-quit, and uninstall affect the hub as a whole.
  Uninstall removes all four modules' local data. The installed WHOOP app stays independent,
  although both signed apps still depend on Apple's signing services.
- Normal background limits remain: system-scheduled notifications do not require the Pushups screen
  open, but Focus, permission changes, geofence delivery, and foreground presentation need tests.
  No continuous GPS, fake background mode, or keeping video alive to maintain reminders.

## Source, identity, and build activation gate

The canonical hub repository is **akshatksingh18/akshatos**, currently public temporarily for hosted
macOS CI capacity and evolved from the existing
Pushup Reminder repository with history preserved. Its local folder is `personal-project/akshatos`.
There is no second hub repository or duplicate Pushups implementation. PageVault/ReelVault keep
their feature plans and Android fallbacks in their existing folders; their future iOS source goes
into the AkshatOS target, not independent IPAs. Their own backup/activation work stays separately gated.

- Display/target name: **AkshatOS**.
- Selected permanent bundle identifier: `com.akshatksingh18.akshatos`; physical provisioning
  remains an acceptance check, not permission to invent another ID on error.
- The former `com.akshatksingh18.squatreminder` identifies only the disposable smoke. Its removal
  and installation evidence are owned by [the build guide](cloud-build.md). No retained
  feature data is being migrated; do not generalize that exception to future data-bearing updates.
- Launch into a hub app-selection screen, then select **Pushup Reminder** for its dashboard.
  PageVault opens its own PDF library and Lift Log opens its own workout logger; ReelVault stays a
  clearly unavailable planned card and does not open a fake app.
  Returning to the hub must leave the Pushups session and scheduling untouched.
- Generate one AkshatOS Xcode target from `akshatos/ios/project.yml` and build through its
  macOS workflow. Ordinary Release IPA, payload inspection and SHA-256, no signing secrets in CI.
  Simulator-only test targets do not ship in the device IPA.
- `architecture.md` owns exact implemented versus target behavior. Finish Pushups before
  starting either media module; hub scaffolding is not full product acceptance.

## Refresh and recovery

- Sign one hub IPA and one WHOOP IPA using stable respective identities and the same chosen
  Apple Account/team across refreshes. Both remain standard artifacts, not Sideloadly-dependent code.
- Keep each installed app's current/previous known-good unsigned IPA and metadata outside Git.
  Rebuilding is for source/toolchain changes; weekly refresh re-signs cached binaries.
- Use Local Anisette, initial trusted USB proof, Wi-Fi pairing, per-app auto-refresh enrollment,
  daemon startup, daily/48-hour maximum health-check gap, three-day refresh buffer, two-day
  escalation, and final-day USB recovery. Verify actual expiry/install success, not process startup.
- Hub refresh/upgrade must preserve all four modules and recheck pending pushup requests. WHOOP
  refresh/upgrade must separately preserve pairing/history and pass its BLE/restoration gates.
- Export data before upgrades/migrations; test clean restore on disposable data before daily use.
  One expired hub profile can block all four sections, so early alerts and same-ID repair matter.

## Acceptance sequence

Pushup Reminder is AkshatOS's first completed feature and its daily loop is accepted in ongoing phone
use. PageVault is the activated media module and is phone-accepted through Build 24. Akshat's later
explicit decision adds Lift Log as a narrow local utility without activating ReelVault; ReelVault
stays reserved. Pushups' open
physical edge-case, refresh/recovery, and soak items remain owned by `todo.md` and `cloud-build.md`
and must not be dropped because PageVault started. Source/build ownership and the permanent bundle
ID are selected above; the identity is already phone-verified through Build 13.

1. Build and verify the hub app picker and Pushups entry, with ReelVault clearly deferred.
2. Implement Pushups' existing lifecycle, actions, streak, and optional Home behavior first.
3. Integrate the native PageVault/PDFKit module (active; phases and gates owned by
   `../book-reader/CLAUDE.md`) and the local Lift Log (`lift-log.md`), then ReelVault/AVFoundation
   later, each with its own persistence/import/performance/recovery tests; no feature gains are
   implied merely by a shell button. Making a
   module available also requires updating the hub picker's unavailable-card state and the UI
   assertion that its entry does not exist.
4. Verify scheduled/actionable notifications while each other section is foregrounded, background/
   locked handling, section switching, permission denial, memory pressure, and low-storage errors.
5. Verify all module exports, full restore, schema upgrade, same-ID refresh, and controlled expiry
   recovery, plus two refresh cycles and a failed-refresh/USB rehearsal.
6. Verify coexistence with standalone WHOOP after its separate activation and physical BLE tests.
   A successful hub build does not activate or prove WHOOP.

## Sources and documentation ownership

Packaging/policy references checked 2026-09-03; re-check before deployment:
[Apple account limits](https://developer.apple.com/help/account/basics/about-your-developer-account/),
[Apple application structure](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html),
[Apple local notifications](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html),
and [Sideloadly refresh/overwrite](https://sideloadly.io/faq.html).

Read each feature's `CLAUDE.md` and supporting architecture/features/TODO before module work.
This file owns cross-project packaging; `../CLAUDE.md` provides container routing and a brief boundary.
Feature folders own product behavior and individual progress. Update this plan when integration
decisions or gates change, not for routine feature milestones; link to evidence instead of copying
it. Keep planned/implemented/physically verified states distinct and repositories private unless
explicitly changed; AkshatOS is the current temporary public exception recorded in `ci.md`.
