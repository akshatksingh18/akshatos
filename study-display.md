# Study display and lock-screen timer

**Status:** Build 39 (0.14.1) implementation in progress, with cloud verification pending. No Build-39
IPA is requested or produced. Build 38 remains the delivered candidate. The SideStore extension
variant is an opt-in test candidate, not device-verified signing or a change to installed refresh ownership.

## Desk Focus

Today opens one full-screen Focus view. Portrait stacks the dial and actions; compact-height landscape
places them side by side when width permits. Accessibility sizes and narrow widths scroll vertically.
The hub remains portrait outside Focus and the PageVault reader. Independent rotation owners cannot
disable each other. Rotation, opening Control Center, DND, calls and locking do not issue Start/Pause
commands or rewrite a segment. Time remains the persisted timestamp projection, not a background task.

Keep screen awake is off on each entry. It applies only while Focus is visible, the scene active,
the store available and study running. Pausing, leaving or becoming inactive releases the override;
returning resumes it only if still selected and running. The previous idle-timer value is restored.
It does not change device brightness, disable manual locking, enable background execution or replace
the low-power Always-On Lock Screen. Park a thought and Undo remain available.
Apple DTS also notes that Adaptive Power can override the idle-timer setting and offers no public
API to detect that mode specifically. Do not fake media/camera activity to keep the phone awake;
include Adaptive Power in phone testing and keep the recorded session independent of display sleep.

## Live Activity candidate

- `ios/project.yml` remains the extension-free default/recovery build.
- `ios/project-live-activity.yml` adds exactly one WidgetKit extension and `NSSupportsLiveActivities`.
  Its source parent identity is unchanged; the extension is its `.studyactivity` child.
- In that variant, Focus exposes a collapsed Lock-screen timer section. Show study timer defaults off;
  the device preference is not transported in Study/full backup. Pausing ends the card immediately,
  resuming requests one new card when foreground. Foreground launch reconciles existing activities.
- The extension receives only a session identifier and a clock projection, never topics, tasks,
  notes, Journal content or access to feature stores. No App Group, APNs, remote service, frequent-push
  capability, new background mode or per-second app polling is used.
- SwiftUI timer text renders elapsed and remaining from dates. This does not guarantee a visible
  every-second refresh on a dimmed display. The system controls visibility, placement and update rate.
  Cards become stale at the next 03:00 boundary or eight hours after creation. The stale presentation
  asks to reopen the app instead of presenting yesterday's live total as today's. Foreground refresh
  can reconcile the new day. At the activity lifetime limit, Show again is explicit; the study block
  continues. A dismissed card is not automatically recreated for that block, including after app relaunch.
- Request failure, denied Live Activity authorization and a missing/hidden/ended card never pause,
  delete or alter study data. Status says requested, not visible or verified. Show again is a manual
  retry. Tapping the card routes `akshatos://study` to Today without starting or pausing study.
  Explicit Off removes cards even when storage is unavailable; an unavailable cache alone does not
  end them. System-ended cards are removed rather than updated/restarted. Unlock recovery retries
  reconciliation after protected data becomes readable.

## Quiet operation and Do Not Disturb

The core clock requires neither notification permission nor a Focus allowlist. The app does not read
private Focus state or change Focus settings. Live Activity requests and updates have no alert
configuration or push token. While study runs, foreground AkshatOS notifications request only a
Notification Center list entry. Future task, Journal, morning and break invitations are reconciled
to passive/no-sound requests during study, even if the app is allowed through DND. Pausing restores
normal settings for future reminders. The separately enabled Still studying check remains an explicit
opt-in; normal iOS DND delivery rules still apply. A request already delivering at a transition cannot
be recalled atomically, and unrelated app/system alerts remain controlled by iOS.
Retained fitness reminder ownership remains governed by the explicit WHOOP handover; this change
does not cancel those background schedules. Keeping AkshatOS off the DND allowlist does not prevent
study recording. Foreground suppression applies to all this app's notification namespaces.

Do not promise that allowlisting AkshatOS makes a Live Activity visible in every Focus configuration.
Lock-screen access, per-app Live Activities, a different linked Lock Screen, user dismissal, competing
activities, Sleep Focus and power/display policy are separate checks. Apple can turn Always-On off
under Sleep Focus, Low Power Mode, obstruction, face-down placement and other system conditions.
The persisted session must remain correct when the display is dark. StandBy requires charging,
sideways stationary placement and a working extension; it does not bypass provisioning.

## Signing experiment and release boundary

SideStore is the preferred free signing experiment; Sideloadly is a recovery option, not a runtime
dependency. At upstream release `0.7.0-alpha` / `6032424a0e56c1c319762e786099bdd9186a238b`,
`FetchProvisioningProfilesOperation` provisions each extension separately when `useMainProfile`
is false. Use **Keep app extensions (register app ID for each extension)** for this experiment,
not Remove extensions or reuse main profile. This addresses the known parent-profile-only failure
class but is source evidence, not a successful install. Account/App-ID availability and the exact
installed version must be checked on the phone. SideStore + the two apps occupy the three app slots;
extension App IDs also consume the separate weekly ID allowance.

Follow `sidestore-evaluation.md`: verified exports first, preserve the same final signed app ID/team
and keychain groups, no uninstall, no automatic certificate revocation, one refresh owner per app,
and advancing-expiry evidence including SideStore's own renewals. No installer, credential, account,
certificate, enrollment or scheduled-task change is performed by this source work.

Build 39 stays on a development branch. PR CI compiles/tests without packaging an IPA. It separately
compiles the optional host/extension for simulator and the extension for device, then restores the
default project for normal device compilation. Manual dispatch defaults to no packaging. Main's
existing release packaging remains; do not merge this branch or dispatch packaging until a later
release request. The existing IPA validator remains intentionally extension-free; before producing a
SideStore candidate, add explicit single-extension validation and release-variant selection. No
SideStore IPA or phone compatibility is implied by a successful compile.

## Verification

Registered hosted tests cover keep-awake acquisition/release, inactive/paused/hidden paths, previous
override preservation, independent rotation ownership, clock projection, request failures, permission
denial, dismissal/retry, single-activity reconciliation, 03:00 and eight-hour boundaries. Notification
tests cover passive reminders and foreground presentation. XCUITest exercises Focus, both landscape
orientations, continued running, Pause and return to portrait. Synthetic native captures include
portrait/landscape, accessibility and the actual shared lock-screen card/stale content.

Physical acceptance remains required:

- DND on before Start, switched during a block through Control Center, switched off and linked Lock
  Screen changed: no unwanted sound/banner or automatic pause; compare totals before/after unlock.
- DND without an AkshatOS allowlist, with an allowlist, and allowed people/calls/repeated calls:
  timer does not claim to block other apps or OS interruptions. Optional study checks on/off tested.
- Manual lock, Auto-Lock, switch apps, interruption/call, background suspension, force-quit,
  relaunch and reboot: saved segment identity/start survive; do not assume a card survives restart.
- Lock-screen Live Activities allowed/denied, per-app authorization changed, Notification permission
  denied, card dismissed, Dynamic Island occupied by another activity, one repeated manual retry.
- AOD on/off, dimmed readability, Low Power Mode, Adaptive Power and Sleep Focus, face down/covered, StandBy
  charging/disconnected, portrait and both landscape directions. Darkness is not a recording failure.
- 03:00 rollover, long block past eight hours, target reached/overtime, clock/time-zone/DST changes,
  phone offline and battery exhaustion. No stale card may be treated as current-day proof.
- SideStore installs without removal, extension has its own matching profile and launches, data
  survives, then both manual and unattended renewals advance expiry. Existing recovery stays intact.

## Primary sources

Public sources reviewed 2026-10-16; none proves this device's installed behavior.

- [Apple: Live Activity architecture and lifetime](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).
- [Apple: system-rendered timer text](https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:)).
- [Apple: Live Activity design and reduced-luminance behavior](https://developer.apple.com/design/human-interface-guidelines/live-activities).
- [Apple: foreground screen-awake API](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled).
- [Apple DTS: Adaptive Power can override the idle timer](https://developer.apple.com/forums/thread/815962).
- [Apple: passive notifications do not light the screen or play sound](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/passive).
- [Apple: Focus options and Lock Screen settings](https://support.apple.com/en-gb/guide/iphone/iphd6288a67f/26/ios/26).
- [Apple: Always-On conditions](https://support.apple.com/en-mn/guide/iphone/iph7117338a8/ios).
- [Apple: StandBy](https://support.apple.com/en-ie/guide/iphone/iph878d77632/ios).
- [SideStore: version-pinned extension provisioning source](https://github.com/SideStore/SideStore/blob/6032424a0e56c1c319762e786099bdd9186a238b/SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift).
- [SideStore: latest release](https://github.com/SideStore/SideStore/releases/latest) still resolves to 0.7.0-alpha, a temporary sign-in fix.
- [SideStore: limits and in-place transfer FAQ](https://docs.sidestore.io/docs/faq).
- [AltStore: separate App ID allowance](https://faq.altstore.io/altstore-classic/app-ids).
