# AkshatOS — shared integration contract

**Status:** Integration implementation activated — AkshatOS owns the native hub and Squats-first
build. PageVault/ReelVault remain later modules; WHOOP stays standalone. Build/phone progress
belongs in `cloud-build.md`, not this integration contract.

## Installed applications

- **AkshatOS (accepted hub display name):** one SwiftUI application with Squats,
  PDF Reader/PageVault, and Reels/ReelVault sections, one entry point, bundle ID, profile, and IPA.
- **WHOOP:** its existing Flutter app remains independently built, installed, refreshed, and tested.
  Keep its native BLE restoration, database, and encrypted export/recovery separate from the hub.

Two apps fit the free Personal Team allowance of three installed development apps; the third slot
is unallocated, not an instruction to add a helper. All four product functions can be available
without rotation or paid membership. This is source-level feature composition, not four guest
IPAs, a PWA, LiveContainer, or an iOS extension workaround. No Flutter embedding is required.

## Native hub boundaries

App composition/navigation lives under `ios/AkshatOS/app/`, reusable UI under `shared/`, and each
feature under `features/<feature>/`. Features must not depend on other features or the host;
the host wires their entry points. `architecture.md` owns exact boundaries and checks.

- Use one native SwiftUI host and three feature modules; module names need not be separate
  application targets. Keep existing feature requirements and Android fallbacks intact.
- A simple home/section selector opens each experience. Load PDF documents and video players only
  when needed and release them on exit; preserve each module's state when switching.
- Host-level Squats services schedule local notifications and handle actions/Home-region events
  regardless of the selected screen. Navigating to a PDF or reel must not stop an active day.
- Register a central notification delegate/action router early. Namespace request/category/action
  identifiers; Pause/End cancel only Squats-owned notifications. Make foreground reminder behavior
  explicit while reading/watching and keep Done/Pause/Snooze idempotent across locked callbacks.
- One hub means one system notification identity and permission settings. Explain that location
  permission serves Squats, selected video access serves Reels, and Files import serves libraries.
  Request permissions when their feature is used; do not require location to read a PDF.
- Version module metadata independently in logically separate stores/directories with namespaced
  settings. Separation is organizational, not an OS security sandbox between modules. No cloud
  sync or cross-module data sharing is implied.
- Provide per-feature and full-hub export/restore before retaining irreplaceable data. PDF/video
  copies, headlines/bookmarks, and Squats history/goals need recovery; disposable caches do not.
- Update, profile expiry, process crashes/force-quit, and uninstall affect the hub as a whole.
  Uninstall removes all three modules' local data. The installed WHOOP app stays independent,
  although both signed apps still depend on Apple's signing services.
- Normal background limits remain: system-scheduled notifications do not require the Squats screen
  open, but Focus, permission changes, geofence delivery, and foreground presentation need tests.
  No continuous GPS, fake background mode, or keeping video alive to maintain reminders.

## Source, identity, and build activation gate

The canonical hub repository is **akshatksingh18/akshatos**, currently public temporarily for hosted
macOS CI capacity and evolved from the existing
Squat Reminder repository with history preserved. Its local folder is `personal-project/akshatos`.
There is no second hub repository or duplicate Squats implementation. PageVault/ReelVault keep
their feature plans and Android fallbacks in their existing folders; their future iOS source goes
into the AkshatOS target, not independent IPAs. Their own backup/activation work stays separately gated.

- Display/target name: **AkshatOS**.
- Selected permanent bundle identifier: `com.akshatksingh18.akshatos`; physical provisioning
  remains an acceptance check, not permission to invent another ID on error.
- The former `com.akshatksingh18.squatreminder` identifies only the disposable smoke. Its removal
  and installation evidence are owned by [the build guide](cloud-build.md). No retained
  feature data is being migrated; do not generalize that exception to future data-bearing updates.
- Launch into a hub app-selection screen, then select **Squat Reminder** for its dashboard.
  PageVault/ReelVault may appear as clearly unavailable planned cards; they do not open fake apps.
  Returning to the hub must leave the Squats session and scheduling untouched.
- Generate one AkshatOS Xcode target from `akshatos/ios/project.yml` and build through its
  macOS workflow. Ordinary Release IPA, payload inspection and SHA-256, no signing secrets in CI.
  Simulator-only test targets do not ship in the device IPA.
- `architecture.md` owns exact implemented versus target behavior. Finish Squats before
  starting either media module; hub scaffolding is not full product acceptance.

## Refresh and recovery

- Sign one hub IPA and one WHOOP IPA using stable respective identities and the same chosen
  Apple Account/team across refreshes. Both remain standard artifacts, not Sideloadly-dependent code.
- Keep each installed app's current/previous known-good unsigned IPA and metadata outside Git.
  Rebuilding is for source/toolchain changes; weekly refresh re-signs cached binaries.
- Use Local Anisette, initial trusted USB proof, Wi-Fi pairing, per-app auto-refresh enrollment,
  daemon startup, daily/48-hour maximum health-check gap, three-day refresh buffer, two-day
  escalation, and final-day USB recovery. Verify actual expiry/install success, not process startup.
- Hub refresh/upgrade must preserve all three modules and recheck pending squat requests. WHOOP
  refresh/upgrade must separately preserve pairing/history and pass its BLE/restoration gates.
- Export data before upgrades/migrations; test clean restore on disposable data before daily use.
  One expired hub profile can block all three sections, so early alerts and same-ID repair matter.

## Acceptance sequence

The current implementation focus is AkshatOS with **Squat Reminder as its first completed feature**.
Keep PageVault and ReelVault reserved as later modules, not active parallel implementation work.
A minimal host may expose only Squats initially; the three-module design remains the eventual
integration contract. Complete and test Squats' daily loop before starting either media module.
Source/build ownership and the permanent bundle ID are selected above; verify the new identity on the phone.

1. Build and verify the hub app picker and Squats entry, with the other modules clearly deferred.
2. Implement Squats' existing lifecycle, actions, streak, and optional Home behavior first.
3. Integrate native PageVault/PDFKit and ReelVault/AVFoundation modules with their existing
   import/performance/recovery tests; no feature gains are implied merely by a shell button.
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
