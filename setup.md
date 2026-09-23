# Weekly signing: setup and health check

How the sideloaded apps on Akshat's iPhone are kept signed, and how that is proved rather than
assumed. `cloud-build.md` owns producing and installing a build; this file owns keeping an already
installed one alive.

**Status:** The health check is installed and its scheduled execution is confirmed. It now treats a
missing expected app, a stopped Sideloadly daemon, or the current version lacking a completed
automatic-refresh registration as a blocking failure. AkshatOS Build
24 expired after Sideloadly's scheduled-app registrations were cleared during WHOOP recovery; the
same accepted IPA was reinstalled over the existing bundle by Wi-Fi on 2026-09-20, reached 100%,
and created a completed automatic-refresh record with no error. WHOOP build 65 was clean-installed
with automatic refresh enabled after a verified backup/delete/restore cycle; it also has a completed
scheduled registration and its data works. Its first manual refresh stalled because Sideloadly's
**Use automatic bundle ID** rewriting was left enabled. Repeating the overwrite with that option off
and the exact final ID `com.akshat.personal.whoop.5564K8D4SV` reached 100%, advanced the signing time,
and preserved data and band pairing. Manual same-ID refresh is proven for both apps. A controlled
forced-due test then let the daemon discover the USB-disconnected phone over Wi-Fi and refresh WHOOP
without the GUI or a manual refresh command; the signing time advanced, expiry reset, data remained
intact, Akshat confirmed the real app still had its data and band connection afterward, and the
scheduled health task logged `REFRESHED`/`ENROLLED` with exit `0`.
AkshatOS Build 25 was then installed over Build 24 by Wi-Fi on 2026-09-21 and reached 100%.
Sideloadly's database corroborates version 0.3.0 at the same final signed identity, automatic bundle-ID
mode, a completed current-version automatic-refresh registration, no error and a seven-day expiry.
Launch/data preservation and a future actual refresh cycle remain separate gates.

## The two halves, and why they are separate

- **Sideloadly's daemon refreshes.** It is installed, starts at logon through the `Sideloadly
  Daemon` entry in `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`, and its own
  `refresh_at_hours` is 96 — it intends to act with three days left, which is the buffer the
  operating model calls for. Nothing here re-implements or drives it: automating its interface was
  ruled out, and a second signer racing it would be worse than none.
- **The health check proves it happened.** This is the half that did not exist. A running daemon is
  not evidence: it can sit for days having done nothing, which is exactly how an app quietly stops
  launching and how the retired Squat Reminder registration reached expiry with no error recorded.

## What counts as success

Only one thing: Sideloadly's record of a **completed install moving forward**, reported with the
bundle ID and the new expiry. Logged as `REFRESHED`.

A changed record is not by itself that install. The check notices a refresh by comparing what it
saved last time against what Sideloadly says now, and several ordinary things produce the same
difference without anything being signed: a run against a substituted `-DatabasePath`, a restored
database, an install done by hand, or lost state. So a difference is only reported as `REFRESHED`
once it is corroborated — the install date has moved past the app's first install, and the new
expiry is in the future. A difference that fails either test is logged as `RECORD-CHANGED`, which
names why it is not a refresh and is explicitly not evidence for the gates below.

Explicitly **not** success: the daemon process running, its log file changing, the check exiting
cleanly, an app merely not being expired yet, or a `RECORD-CHANGED` line.

The honest limit: this is Sideloadly's record that it finished signing, which implies a real
round-trip with Apple, not the phone confirming the profile it holds. Device-sourced truth would
need a `libimobiledevice` toolchain, which is deliberately not installed. Opening the apps
occasionally is what covers that gap — keep doing it.

## What is installed

| | |
|---|---|
| Scheduled task | `AkshatOS Signing Health` — at logon, 09:00 and 21:00 daily |
| Check | `personal-project/akshatos/scripts/check-signing-health.ps1` |
| Reader | `personal-project/akshatos/scripts/read-signing-state.py` |
| Required-app contract | `personal-project/akshatos/scripts/signing-apps.json` |
| Log | `%LOCALAPPDATA%\AkshatOSSigningHealth\health.log` |
| State | `%LOCALAPPDATA%\AkshatOSSigningHealth\state.json` |
| Source read | `%LOCALAPPDATA%\Sideloadly\installations.db` (copied, opened read-only) |
| Test sidecars | `health.test.log` and `state.test.json`, beside the real pair |

A run that passes `-DatabasePath` is a test, not an observation of the phone, so it is redirected to
those sidecars automatically and cannot write into the real log or state. Pass `-LogPath`/`-StatePath`
explicitly to override that. This matters because a fixture run that writes into the real state makes
the next real run read the difference back as a refresh that never happened — reproduced in a
sandboxed agent session, and the reason the redirect exists.

The database is copied before reading so a health check can never lock or alter the daemon's own
store. The signing material beside it (`key.pem`, `cert-*.pem`, `sessions.json`) is never read,
copied or committed, and the reader selects named columns only.

Run it by hand any time:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI Important Files\personal-project\akshatos\scripts\check-signing-health.ps1"
```

Add `-Quiet` to suppress the pop-ups and just read the log lines. Exit code is `0` healthy,
`1` warning, `2` act now.

## Reading the log from an agent session

**A coding agent's shell cannot be trusted to read this log.** Agent shells here run sandboxed, and
writes outside the workspace — `%LOCALAPPDATA%` included — are redirected into a per-workspace
overlay. The agent then reads its own overlay copy back, so it sees a log that mixes real history with
whatever previous agent sessions wrote, and misses everything the real scheduled task has recorded.

This is not hypothetical: it produced a confident, wrong diagnosis that the scheduled task was
launching and silently doing nothing, on the evidence of runs "missing" from a log that had never
received them. The two views disagreed on both line count and modification time.

So when the question is what the real check has actually recorded:

- Read the log **outside** an agent shell — a terminal you opened yourself, or Explorer.
- If an agent must read it, have a scheduled task copy `health.log` into the workspace first and read
  the copy; a scheduled task runs unsandboxed. Delete the copy afterwards.
- Treat an agent-session run of the check as a logic exercise only, never as an observation of the
  phone's real signing state.

The same applies to `state.json`, and it is why fixture runs are redirected to sidecars: an agent's
testing must not be able to reach either file, whichever side of the sandbox it lands on.

## What it does when something is wrong

| Condition | What happens |
|---|---|
| 3 days or less left | Balloon warning — the daemon should have acted at 4 days and did not |
| 2 days or less, or expired | **Blocking dialog**, deliberately impossible to miss |
| `failures_count` or `last_error` set | Blocking dialog naming the error |
| Sideloadly daemon stopped | Blocking dialog — an enrolled row cannot refresh without the daemon |
| AkshatOS or WHOOP missing from the exact-identity contract | Blocking dialog |
| Current app version has no completed scheduled registration | Blocking dialog with enrollment recovery |
| Registration uses the wrong app-specific bundle-ID mode | Blocking dialog with exact recovery mode |
| Python missing, database unreadable | Blocking dialog — a check that cannot run must shout, not pass |

The recovery it tells you to do, in order: open Sideloadly and use **Refresh All Apps Manually**
with the iPhone unlocked and on the same Wi-Fi; if that fails, connect USB and install the IPA at
`D:\AI Important Files\personal-project\final-ipas\<project>\backup\` again — that folder is always the current accepted build, so it is
what any manual reinstall or recovery should point Sideloadly at; `D:\AI Important Files\personal-project\final-ipas\README.md` owns the
model. **Never uninstall to fix signing** — that deletes the app's data.

**A known second failure mode, found once on WHOOP:** Sideloadly's own internal cache of a
previously-installed app's IPA can go missing on its end — nothing to do with the file above — and a
refresh then fails with `Install failed: Guru Meditation … __init__() missing 1 required positional
argument: 'orig'` instead of a clean "file not found". This happened on the very first wireless
refresh attempt after wireless detection started working: the connection succeeded, Sideloadly tried
to re-sign from its own cached copy, and that copy was gone. The fix is the same USB reinstall above,
using the file at `D:\AI Important Files\personal-project\final-ipas\<project>\backup\`; it repopulates Sideloadly's cache with a real
file and should clear the error for future refreshes, wired or wireless.

## Checking the check

The decision logic lives in PowerShell and reads a Windows-local database, so the GitHub Actions
`CI Gate` does not and cannot cover it — it is verified by hand on this machine. Re-run these three
cases after changing how the check decides anything, because the failure mode that matters is a
false success, and a false success is silent by definition.

Copy `installations.db` somewhere scratch, edit one app's `last_updated`, seed `state.test.json`
with a *different* value for that app so the run sees a change, then run with `-DatabasePath`:

| Fixture | `last_updated` set to | Expected |
|---|---|---|
| Never refreshed | a second after that app's `created_at` | `RECORD-CHANGED` naming the unmoved install date |
| Past expiry | more than the 7-day TTL ago | `RECORD-CHANGED` naming the past expiry, then `CRITICAL`, exit `2` |
| Real refresh | now | `REFRESHED` with a future expiry, then `OK`, exit `0` |

The first case is the regression test for the false positive described above. Confirm in the same
pass that the real `health.log` and `state.json` are byte-identical afterwards; a fixture run that
touches them has reintroduced the original fault.

## Wireless-only refresh: what it does and does not promise

The goal is one USB connection ever, then Sideloadly's daemon refreshes wirelessly over Wi-Fi from
then on. Two things from Sideloadly's own FAQ (<https://sideloadly.io/faq.html>, re-checked
2026-09-12) keep that from being a guarantee rather than a design intent:

- **"You also need to have your iDevice screen on for it to be detected."** The FAQ does not say
  whether that applies only to the one-time Wi-Fi pairing or to every refresh attempt going
  forward. Leaving the phone on the same Wi-Fi, ideally charging, removes the biggest variable
  either way.
- **Refresh is driven by nearness to each app's own expiry, not a shared calendar day.** AkshatOS
  and WHOOP were last signed on different days, so they will not naturally refresh together; a
  missed cycle also pushes every later cycle for that app back by the same amount. A one-time
  manual **Refresh All Apps** in Sideloadly resets every app's clock to the same day if a shared
  schedule is wanted.

`installations.db` currently has completed `one_off: 0` automatic-refresh registrations for both
AkshatOS and WHOOP. Manual same-ID overwrites advanced both apps' signing times and expiries. WHOOP
requires automatic bundle-ID rewriting **off** and its exact final signed ID entered; the base ID
plus Sideloadly's automatic transformation stalls at 0%. Confirm the database and Sideloadly UI
after every recovery rather than equating enrollment with a successful cycle. The health check above
is what tells you whether a recorded refresh happened; silence from the phone is not evidence.

## Durable workflow for every new app version

Source changes do not require a new Apple identity and weekly re-signing does not require a source
rebuild. Merely copying a new IPA into `testing\` does not install it or change Sideloadly's cached
refresh artifact; every new version needs one controlled install-over-install pass. After that pass,
weekly re-signing uses the new cached version automatically. For every AkshatOS or WHOOP iteration:

1. Build and validate the unsigned IPA, then place the candidate and its checksum/manifest in that
   project's `final-ipas\<project>\testing\` folder. Leave the accepted `backup\` build untouched.
2. Make a current app-owned backup before an upgrade that can affect stored data. Install **over**
   the existing app — never uninstall — with the same Apple Account/team and the per-app identity
   mode in `scripts/signing-apps.json`:
   - **AkshatOS:** keep **Use automatic bundle ID** enabled; the IPA/source ID is
     `com.akshatksingh18.akshatos`, and the expected final ID is
     `com.akshatksingh18.akshatos.5564K8D4SV`.
   - **WHOOP:** turn **Use automatic bundle ID** off and enter exact final ID
     `com.akshat.personal.whoop.5564K8D4SV`.
   Keep the separate automatic-refresh control enabled for both.
3. Require all five device gates: installation reaches 100%, the app launches with its data intact,
   its version is the intended version, the signing check prints `ENROLLED` for that exact signed
   identity/current version, and it prints the expected `IDENTITY` mode. A successful one-off install
   or a correctly spelled final ID under the wrong Sideloadly mode is not enough.
4. Only after the project-specific phone checks also pass, promote the candidate from `testing\` to
   `backup\`. Sideloadly's cached refresh artifact and the recovery folder must now represent that
   same accepted version.
5. Leave the daemon enabled at sign-in and let the existing scheduled health task watch both apps.
   After installer, Apple-device-component, iOS, Apple Account/team, or bundle-identity changes,
   prove one Wi-Fi refresh again instead of inheriting old evidence.

The exact signed identities are pinned in `scripts/signing-apps.json`. A normal version/build change
must not edit that file. If a deliberate team or bundle migration is ever necessary, treat it as a
data-migration project and update the contract only after container preservation is proven.

This workflow is ready for both apps. WHOOP passes installation, restore, enrollment, exact-ID
same-app overwrite, data preservation, band reconnection, and a controlled forced-due unattended
Wi-Fi daemon cycle. One naturally elapsed next cycle remains before calling the long-term schedule
fully proven.

**Current discovery state:** Apple Bonjour 2.0.2 is installed, automatic, and running; its signed
installer added UDP 5353 firewall rules, and `_apple-mobdev2._tcp` browsing sees the iPhone. Earlier
controlled tests also found Sideloadly could rediscover the phone after Bonjour was stopped and
removed, so Bonjour alone must not be credited as the root fix. Apple Mobile Device Service, trusted
Wi-Fi sync, the iPhone's stable network identity, and Sideloadly all remain part of the path.

1. **Bonjour was tested as a variable.** Bonjour Print Services was
   installed at the time, reasoning that Sideloadly's Windows discovery runs on Bonjour/mDNS
   (`mDNSResponder.exe`). Three tests settled it:
   - **Holding:** with the phone already connected, Bonjour was stopped. The connection kept
     working, still holding half an hour later.
   - **Cold start:** Sideloadly was fully quit from the tray — not just the window — and relaunched
     from scratch, Bonjour still stopped the whole time (confirmed by process start time, 3:46:36 PM,
     after the stop). It found the phone over Wi-Fi immediately.
   - **Fully uninstalled** (both `Bonjour Print Services` and `Bonjour` registry entries, the service,
     and both install folders — confirmed gone). Sideloadly still showed `@Wi-Fi` afterward.
   Those tests show it was not the sole cause. It was later reinstalled as a conservative discovery
   dependency and is part of the current working configuration.
2. **The iPhone's Private Wi-Fi Address was set to rotating**, on this specific network — this is now
   the entire explanation, not one of two contributing changes. A rotating MAC address is a moving
   target for device discovery. Fix: iPhone Settings → Wi-Fi → (this network) → **Private Wi-Fi
   Address → Off**. `Limit IP Address Tracking` is unrelated (an IP-tracking privacy setting, not
   device discovery) and can stay on or off independent of this fix.

With a stable Private Wi-Fi Address, trusted iTunes Wi-Fi sync, Apple Mobile Device Service, and the
current Bonjour installation, Sideloadly detects the phone as `@Wi-Fi`. A temporary AkshatOS bundle,
a clean WHOOP build-65 bundle, and the AkshatOS same-ID renewal all reached 100% over that path. A
later USB-disconnected, forced-due daemon cycle also refreshed WHOOP automatically over this path.

**A known second failure mode, seen once so far:** the very first wireless refresh attempt failed
with `Install failed: Guru Meditation 556260@79:6edd68 __init__() missing 1 required positional
argument: 'orig'` — Sideloadly's own cached copy of WHOOP's IPA had gone missing from its internal
store, unrelated to anything in `D:\AI Important Files\personal-project\final-ipas`. It cleared on its own on the next attempt roughly 22
minutes later, without a manual reinstall. Whether that was the daemon self-healing or coincidence is
not established from one occurrence. If it recurs and does not clear on its own, the fix is a manual
reinstall from `D:\AI Important Files\personal-project\final-ipas\<project>\backup\` — see "What it does when something is wrong" above.

## What this has already found

**A stalled or cancelled install leaves debris in Sideloadly's own database, and the reader handles
it.** The scheduled-app list was later cleared during recovery, removing both apps' old registrations
and debris. Both apps now have completed scheduled rows. WHOOP reached that state through a clean
install after backup/delete. Automatic bundle-ID rewriting then caused its manual refresh to stall;
using the exact final signed ID succeeded and preserved the working container. A scheduled row is
still enrollment, not by itself proof that replacement works. The reader must continue
folding zero-date attempts into `staleAttempts`; they are not completed refreshes.

`read-signing-state.py` now groups rows by bundle ID and reports one entry per app — the most
recently *completed* row if any exists in the group, with every other row (a stalled attempt, or any
future duplicate) folded into that entry's `staleAttempts` rather than reported as a second app.
`check-signing-health.ps1` logs a `STALE-ATTEMPT` line when this happens, informational only, and
gives incomplete-attempt-only bundles their own clearer message instead of the generic "no usable
install date" WARN. Verified against the real database with the real duplicate WHOOP row still
present — one clean `WHOOP` entry, correct expiry, the debris surfaced as `STALE-ATTEMPT` rather than
silently dropped or double-counted.

At the time it was installed, all three registrations had `last_updated` still equal to their
original install time: the daemon had never refreshed anything.

The **Squat Reminder** registration had expired two days earlier with `failures_count: 0` and an
empty `last_error` — it did not fail, it was simply never attempted. This turned out to be correct
behavior, not a gap: `cloud-build.md` already documents `com.akshatksingh18.squatreminder` as the
standalone smoke app that "launched once through Sideloadly and was then removed by Akshat" — it is
not on the phone, and the working Squats feature lives inside the AkshatOS hub's own bundle
(`com.akshatksingh18.akshatos`), which was healthy throughout. Sideloadly never deletes an
installation row on uninstall, so a retired app's registration keeps "expiring" every seven days
with nothing on the phone for it to affect.

The check now knows about this: `read-signing-state.py` carries a short, documented
`RETIRED_BUNDLE_PREFIXES` list, and a matching registration is logged as `RETIRED` rather than
raised as an error. Add a future retired identity there, with the reasoning, rather than leaving the
check to cry wolf about it forever. Removing the row from Sideloadly's own database is optional
tidiness at this point, not a fix — it does not free anything on the device, since the app limit
Apple enforces is what is actually installed on the phone, not a row in a Windows-local database.

A later pass found a fault in the check itself, by exercising it rather than by it firing. Two
separate defects, both now fixed:

- **Success was uncorroborated.** A `REFRESHED` line was written on nothing more than a difference
  between the saved state and Sideloadly's database. Against fixtures the old logic cheerfully
  reported a re-signing whose "new expiry" was already four days in the past, and another on the
  line immediately before stating the app had never been refreshed since first install.
- **A fixture run wrote into the real record.** Passing `-DatabasePath` still used the production log
  and `state.json`, so a test left its own install date behind and the next real run read that back
  as a change — manufacturing exactly the false `REFRESHED` above.

The real log has never carried a false line; both were reproduced in a sandboxed agent session's own
copy. The hazard was in the design regardless, and it mattered more than an untidy log because
`REFRESHED` is the only evidence the gates below are ever closed on — a false one is how the refresh
loop gets recorded as proven without a single refresh having happened.

Both apps have successful manual same-ID refresh evidence after their scheduled registrations were
rebuilt. WHOOP required automatic bundle-ID rewriting off and its exact final ID; the successful
overwrite advanced `last_updated` and preserved data/pairing. A controlled forced-due daemon run then
advanced WHOOP again over Wi-Fi with USB disconnected and no GUI/manual refresh command. The health
task initially exposed a Windows PowerShell 5 `$PSScriptRoot` parameter-default incompatibility; the
path is now resolved after the parameter block, and the installed task returns `0`. Keep WHOOP's
verified encrypted backup despite the successful container-preserving path.

## Still open

These stay open until exercised, per the operating model in `CLAUDE.md`:

- [ ] Two consecutive naturally due unattended refresh cycles. One earlier natural WHOOP cycle and
      one later controlled forced-due WHOOP Wi-Fi cycle are corroborated; the latter used the real
      daemon/sign/install path with USB disconnected and no GUI/manual refresh command, but does not
      replace observing the next naturally elapsed cycle. A `RECORD-CHANGED` or fixture line never
      counts.
- [ ] One deliberate USB recovery rehearsed from an expired or near-expired state.
- [ ] One forced failure — phone absent or offline at the refresh point — confirmed to raise the
      alert rather than pass quietly.
Until all three are done, do not describe weekly signing as dependable.
