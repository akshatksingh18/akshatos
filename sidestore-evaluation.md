# SideStore evaluation

**Decided purpose:** Akshat wants SideStore to refresh signing **without the laptop**, not for the
lock-screen Live Activity timer. So the pilot moves the ordinary standard IPA (Build 41), the
Build-39 Live Activity candidate does not need restoring, and the kept-extension provisioning work
below is out of scope unless he later asks for the timer. The honest goal is not needing the laptop
weekly: initial setup still requires USB trust, iloader and a pairing file, and an iOS update or
reset can invalidate that pairing. Gate 5 below — a replacement expiry monitor — becomes the
critical one, because the installed health check reads Sideloadly's database and cannot see
SideStore-owned renewals. Build the replacement and prove it before retiring Sideloadly's AkshatOS
enrolment; `setup-checklist.md` stage 5 carries the running order.

**Status:** Pilot approved; Akshat reports setting up SideStore on the laptop. On-phone installation,
self-refresh, app handover and unattended renewals are not yet confirmed. Sideloadly's local
records still enroll both apps; no signing ownership or certificate setting was changed in this
check. Akshat runs the steps below on the PC and phone; WHOOP's current build and its later handover
remain owned by that project's instructions. LocalDevVPN is allowed on the phone
as SideStore's installer helper; it is never a WHOOP or AkshatOS dependency.
Public install/prerequisite/FAQ pages and the latest-release URL were rechecked 2026-10-24.
They still prescribe iloader and LocalDevVPN, and latest resolves to 0.7.0-alpha. The study
extension follow-up uses pinned upstream provisioning source. The phone pilot remains unverified.
The cached iloader MSI is present locally; registry/process probes did not establish an installed
or running iloader in this session, which does not contradict Akshat's setup report.

## Recommendation

SideStore is a credible way to remove routine PC dependence for the existing two-app portfolio,
but not a proven reliability upgrade yet. Prefer a controlled pilot over an immediate switch.
The current release situation and preservation of installed data are the main gates.

## Windows 11 ARM pilot

The second laptop is confirmed Snapdragon/ARM64 Windows 11. The normal workspace kit supports
native ARM developer tools but defers the old desktop-iTunes/iCloud/Sideloadly stack. Its separate
explicit `PhonePilot` mode only downloads verified public candidates; an optional
`-InstallDeviceSupport` requests Apple Devices through the Store's normal compatibility checks.
It never launches a signer, authenticates, pairs or installs an IPA. The primary remains active.

[SideStore's prerequisites](https://docs.sidestore.io/docs/installation/prerequisites) exclude
Windows 10 on ARM and 32-bit Windows, and prescribe iloader with Apple Devices as a fallback when
iTunes fails. This supports testing Windows 11 ARM; it does not prove this laptop's Apple driver,
USB or pairing path. Test USB/Trust first without forcing an incompatible driver package.
The kit pins [iloader v2.4.0](https://github.com/nab138/iloader/releases/tag/v2.4.0), Windows x64 MSI,
SHA-256 `24a594680f40e7750746d43384756b7a3d848cc054ed7760cb576ebde0e582d5`.
This x64 client would use Windows 11 app emulation. Its release defaults to using the main profile;
the Live Activity pilot still requires separate profiles for kept extensions. Do not silently
upgrade the existing v2.3.6 installation/report or treat a new download as installed evidence.

[Impactor v2.7.2](https://github.com/claration/impactor/releases/tag/v2.7.2) is another candidate,
with a native ARM64 portable build. Downloaded bytes match the release digest and the actual PE
machine header is ARM64; SHA-256
`351ff17e1eab2a5615ab5c155a499f1eeb3c7347c0404cbf6918a4462b756b80`.
Its Windows release still requires iTunes device drivers, so Apple Devices compatibility with this
client remains a test, not a documented guarantee. Its [FAQ](https://impactor.claration.dev/docs/troubleshooting/faq/)
describes remote anisette and beta automatic refresh. No credentials or pairing files were
submitted in this research and it was not executed. This candidate has not replaced the approved
SideStore experiment or current Sideloadly ownership. Use one route at a time and retain the
data/identity/certificate gates below; either alternative needs suitable expiry monitoring before
retiring the Sideloadly health task. A matching public hash is integrity evidence, not a security audit.

## What changes

- SideStore is an AltStore fork that installs and periodically re-signs ordinary IPAs on the
  phone. It is not a compiler or a replacement for our GitHub macOS build pipeline.
  [Repository](https://github.com/SideStore/SideStore).
- Initial setup still needs a computer, USB trust and the documented iloader procedure.
  A pairing file can become invalid after an iOS update/reset or unexpectedly; repairing it
  can bring the computer back into the process. Refresh SideStore itself before adding apps.
  [Install guide](https://docs.sidestore.io/docs/installation/install).
- The documented baseline is Wi-Fi plus LocalDevVPN during install/update/refresh. The tunnel
  is an installer helper, not a background mode or JIT dependency added to WHOOP.
  [Prerequisites](https://docs.sidestore.io/docs/installation/prerequisites).
- LocalDevVPN is distributed through the App Store, so it does not consume a Personal Team
  sideload slot. Its developer describes a local tunnel, not an external traffic relay; this
  is not an independent security audit or a guarantee of zero battery cost.
  [App Store listing](https://apps.apple.com/us/app/localdevvpn/id6755608044).
- Apple's free Personal Team still permits three installed apps per device and seven-day
  provisioning profiles. SideStore + WHOOP + AkshatOS use all three slots. SideStore itself
  must stay signed; there is no fourth slot for a disposable test app in this arrangement.
  [Apple account limits](https://developer.apple.com/help/account/basics/about-your-developer-account/).

## Current reliability caveat

The releases page labels 0.6.4 as unusable for sign-in. The current latest release,
0.7.0-alpha, is explicitly a temporary fix for Apple-side changes that broke sign-in on
0.6.4 and earlier. A Latest badge is not stable-release or device-soak evidence.
Do not blindly follow the installation guide's Stable button without checking what it installs.
[Releases](https://github.com/SideStore/SideStore/releases),
[0.7.0-alpha](https://github.com/SideStore/SideStore/releases/tag/0.7.0-alpha).

Recent release notes advertise on-device anisette and optional cellular refresh through
Shortcuts, while the prerequisite guide still requires Wi-Fi. Treat these as version-specific
features to verify, not guaranteed behavior. Background renewal must be demonstrated away
from the PC; a successful manual renewal does not prove unattended renewal.

The general iOS minimum is satisfied by the reported iPhone 17/iOS 26.6.2, but this specific
device/version combination has not been tested here. VPN/DNS interference and pairing failures
are documented failure modes. Never follow troubleshooting advice to delete managed apps
without verified recovery of their data.
[Troubleshooting](https://docs.sidestore.io/docs/troubleshooting/common-issues).

## Data and signing gates before a pilot

These are our acceptance requirements, not completed migration steps:

1. Verify WHOOP backup/restore and AkshatOS full backup, including actual Body photo completeness.
   The known missing-media exception in `hub-plan.md` must not be mistaken for complete recovery.
2. Preserve the same Apple Account/team and each app's exact final signed bundle identity.
   Compare signed application identifiers and keychain access groups before an overwrite.
   The FAQ describes in-place Sideloadly transfers, but that does not prove our rewritten
   identities match. Do not uninstall the original apps to make space.
   [Transfer FAQ](https://docs.sidestore.io/docs/faq).
3. Review certificate ownership before sign-in/self-refresh. The official guide can prompt
   certificate revocation; accepting it could invalidate apps signed with that certificate.
   Do not blindly accept revocation or run competing refresh owners for the same apps.
4. Inspect the resulting signed IPA/profile and background-task identifier rewriting if WHOOP
   later ships the proposed background tasks. Preserve required capabilities and BLE ownership.
   A new signer is not evidence that background restoration works.
5. Define a replacement expiry-health check before disabling Sideloadly enrollment or tasks.
   **Built in source from Build 42, not device-verified:** the app reads its own bundled
   provisioning profile and warns before expiry, which works whoever signs it. `setup.md`
   owns it and its limits - it only re-arms when the app is opened and cannot make a refresh
   happen. Prove it on the phone before retiring Sideloadly enrollment, not after.
   Our Windows check reads Sideloadly's database and cannot certify SideStore-managed renewals.
   A stale record must not become either false reassurance or endless recovery attempts.
6. Prove at least two renewals without the PC, including SideStore's own renewal, with advancing
   expiry evidence and preserved data. Separately test WHOOP locked/background workouts,
   Bluetooth restoration and overnight capture; test AkshatOS reminders and every module.
7. Keep known-good standard IPAs and verified exports for rollback. An account/team change
   remains a separate migration under `apple-account-switch.md`, not part of this experiment.

## Pilot sequence

Approved; laptop setup reported, phone steps unconfirmed. Each step is done by Akshat on the
PC/phone; nothing is automated by the agent.

1. **Timing:** set up SideStore and pilot the delivered AkshatOS Build-39 Live Activity candidate
   first. Leave WHOOP's installed app and existing refresh owner alone during this pilot; its
   owning project controls its current build and later handover. Build 40 is source-only and is
   not in this installation. Do not assume the earlier WHOOP Build-86 timing remains current.
2. **Backups first:** WHOOP encrypted export copied to Windows; AkshatOS Back up everything with
   the Body photo count checked against the library. Record each app's final bundle ID and expiry.
3. **Install SideStore** from its official release after checking which version the Stable
   button installs. Checked: iloader's Install SideStore (Stable) fetches GitHub's latest
   release, currently 0.7.0-alpha (the 503 sign-in fix; 0.6.4 is marked do-not-use). Use that
   option, not the LiveContainer+SideStore one. iloader v2.3.6 for Windows is downloaded at
   `../installers/iloader-2.3.6/iloader-windows-x64.msi`, SHA-256
   `6f0d038f74f60e2e036efa17dd45b7cebd3a4c61b226ff0f03cc8668bb5e3b2d` (matches GitHub's record). Stop at any certificate-revocation prompt and decide before accepting it:
   revoking the certificate Sideloadly used can stop both installed apps from opening.
4. **Move one app first.** Recommended: AkshatOS (simpler, no BLE). Add the cached IPA in
   SideStore, confirm the same final bundle ID and that data survived. Then turn that app's
   Sideloadly automatic refresh off, so there is one refresh owner per app.
5. **WHOOP second, on Build 86** (already installed by Sideloadly and working), with the same checks plus: band still paired, automatic-backup passphrase
   still readable, Status shows the new expiry, and a short background sync works.
6. **Monitoring:** the Windows health check reads only Sideloadly records, so it will report a
   moved app as stale. Mark it as SideStore-managed there rather than ignoring the alert. WHOOP's
   own 48/24-hour expiry alerts keep working; AkshatOS has no on-device expiry check.
7. **Pass condition:** two unattended renewals of each moved app and of SideStore itself, away
   from the PC, with advancing expiry and preserved data. Then decide adopt, fallback or remove.
8. **Rollback:** reinstall the cached IPA with Sideloadly at the same final bundle ID and
   re-enable its automatic refresh; restore from the step-2 backups only if data was lost.

## Build-39 install and test checklist

This is an instruction checklist, not evidence that any installation or test was performed.
`cloud-build.md` owns the exact testing IPA path and checksum; `study-display.md` owns the full
physical edge-case matrix. Keep the accepted Build-31 recovery copy unchanged.

1. Export AkshatOS full backup and WHOOP's encrypted backup to Windows. Confirm the files are
   actually readable there; compare Body photos with the library. Do not test a destructive
   restore against the only live copy. Do not uninstall either app or switch Apple Accounts.
2. Use home Wi-Fi and USB for initial setup. Install LocalDevVPN from the official prerequisite
   page on the phone. Open iloader on Windows (use its official installer if needed), connect and
   trust the phone, sign in with the same signing Apple Account/team, select the phone and choose
   Install SideStore (Stable), not LiveContainer. Check the fetched version against releases.
3. Trust the developer in Settings > General > VPN & Device Management; enable Developer Mode
   if needed. Connect LocalDevVPN, open SideStore, sign in with the same account and manually
   refresh SideStore itself before adding AkshatOS. Stop at certificate-revocation prompts for
   review: the generic upstream Yes instruction does not establish safety for the existing apps.
4. Copy the validated Build-39 unsigned IPA to Files yourself. In SideStore > My Apps > +,
   select it and keep extensions with Register app ID for each extension. Preserve the expected
   final host identity `com.akshatksingh18.akshatos.5564K8D4SV`, team and keychain groups; do not
   select a random/custom identity. If identity cannot be confirmed before overwrite, stop for
   inspection. A duplicate app, unexpected empty store or prompt to delete the original is not
   a successful in-place handover. Do not delete either copy to troubleshoot.
5. Confirm version 0.14.1 (39), four tabs, previous study/task/fitness/Body/PageVault data and
   permissions. After a successful SideStore-managed install/refresh and identity/data checks,
   retire only AkshatOS's Sideloadly automatic-refresh enrollment and update its expiry monitor;
   do not change WHOOP's owner or globally disable its daemon. No ownership change has occurred
   merely because SideStore installed.
6. Run a short study, pause for a break and resume. Check actual elapsed time. Open Focus,
   rotate both ways, enable Keep screen awake, then leave/reopen Focus and verify it defaults off.
7. Enable Focus > Lock-screen timer > Show study timer, lock and check the card. Pausing should
   end it; resuming from the foreground should request a new one. Missing cards are display/signing
   failures, not permission to erase study data. Check system Live Activity access if absent.
8. Enable Settings > StandBy, charge and stand the locked phone sideways. Inspect/expand the
   study Live Activity if present. Compare its studied/remaining values with the app. Then test
   DND before Start and toggled during study, without an AkshatOS allowlist, plus Low Power Mode,
   Sleep Focus and unplugging. Display sleep must not pause the persisted block; dimmed seconds
   need not animate continuously. Calls/other apps remain under iOS control.
9. Switch apps, lock for several minutes, relaunch and compare totals; inspect the next actual
   03:00 rollover. Reboot/card recovery and long-session limits follow `study-display.md`.
10. Test other hub features using disposable tasks/Journal entries and a short PageVault read;
    export a fresh full backup without replacing live data. Build 39 has no Daily routine yet.
11. Separately test linked-folder delivery with harmless files in both directions; measure actual
    arrival/edit latency, offline recovery and re-linking per `laptop-phone-sync.md`. This is not
    continuous sync, and it does not depend on SideStore working.
12. Away from the PC, manually refresh SideStore and AkshatOS and check advancing expiry/data.
    Then verify two unattended renewals of both with Wi-Fi and the required tunnel available.
    Record exact expiry changes rather than assuming a rounded day counter proves renewal. Keep
    WHOOP migration and cache promotion open until their own acceptance gates pass.

Report version, old-data preservation, manual refresh/expiry, landscape/keep-awake, lock-screen,
StandBy, DND and timed-session results as pass/fail. Never include passwords, pairing files or
signing material in reports. No installer, account, certificate or refresh-owner state was changed
by preparing these instructions.

## Scope boundary

### Build-39 study Live Activity experiment

SideStore is authorized as the preferred free signing experiment for the combined Build-39 candidate;
Sideloadly need not remain the long-term dependency. The requested unsigned Live Activity IPA is
validated and delivered in `testing/`; `cloud-build.md` owns its exact evidence. Existing renewal
ownership remains until verified handover. `study-display.md` owns the source variant and phone matrix.
At upstream 0.7.0-alpha (`6032424a0e56c1c319762e786099bdd9186a238b`),
[`FetchProvisioningProfilesOperation`](https://github.com/SideStore/SideStore/blob/6032424a0e56c1c319762e786099bdd9186a238b/SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift)
explicitly registers/fetches a profile per extension when `useMainProfile` is false. Choose
**Keep app extensions (register app ID for each extension)** for the future experiment; reusing the
parent profile or removing the extension does not test the required path. This is source evidence
that a suitable provisioning route exists, not proof of signing, launch or renewals on the phone.
Extensions also consume the separate weekly [App ID allowance](https://faq.altstore.io/altstore-classic/app-ids).
Keep the existing preservation/certificate/monitoring gates above, then prove the card renders with
DND, lock-screen access, AOD and StandBy. No account/installer changes are made by the source work.

Signing refresh keeps an app launchable. It does not retrieve band history, refresh dashboards,
improve GPS speed, grant continuous execution or override iOS suspension/force-quit behavior.
WHOOP's sync/lifecycle repairs remain independent Build 86 work. No LiveContainer, JIT workaround,
extra WHOOP background mode, credential automation or installation is authorized by this research.
Only public technical sources were queried; no health records, logs or credentials were sent.
