# SideStore evaluation

**Status:** Pilot approved; Akshat reports setting up SideStore on the laptop. On-phone installation,
self-refresh, app handover and unattended renewals are not yet confirmed. Sideloadly's local
records still enroll both apps; no signing ownership or certificate setting was changed in this
check. Akshat runs the steps below on the PC and phone, alongside
WHOOP Build 86's implementation (WHOOP `todo.md` section 10). LocalDevVPN is allowed on the phone
as SideStore's installer helper; it is never a WHOOP or AkshatOS dependency.
Public sources checked 2026-10-09; release claims are from that research, not a fresh release check.
The cached iloader MSI is present locally; registry/process probes did not establish an installed
or running iloader in this session, which does not contradict Akshat's setup report.

## Recommendation

SideStore is a credible way to remove routine PC dependence for the existing two-app portfolio,
but not a proven reliability upgrade yet. Prefer a controlled pilot over an immediate switch.
The current release situation and preservation of installed data are the main gates.

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

1. **Timing (Akshat: alongside WHOOP Build 86):** set up SideStore and move AkshatOS first,
   install WHOOP Build 86 with Sideloadly (the proven path), and move WHOOP to SideStore only
   after Build 86 has worked for a day or two. A signing problem and a new-build problem then
   stay distinguishable while both happen in the same window.
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

## Scope boundary

Signing refresh keeps an app launchable. It does not retrieve band history, refresh dashboards,
improve GPS speed, grant continuous execution or override iOS suspension/force-quit behavior.
WHOOP's sync/lifecycle repairs remain independent Build 86 work. No LiveContainer, JIT workaround,
extra WHOOP background mode, credential automation or installation is authorized by this research.
Only public technical sources were queried; no health records, logs or credentials were sent.
