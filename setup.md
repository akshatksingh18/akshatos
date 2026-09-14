# Weekly signing: setup and health check

How the sideloaded apps on Akshat's iPhone are kept signed, and how that is proved rather than
assumed. `cloud-build.md` owns producing and installing a build; this file owns keeping an already
installed one alive.

**Status:** The health check is installed, and its scheduled execution is **confirmed** — the log
carries a run from every trigger fired so far, on time and with the expected verdict. **A genuine
unattended wireless refresh has now happened once** — WHOOP, 2026-09-13 08:22:48, corroborated
(`everRefreshed: true`, expiry moved forward to Sep 20, no error). One more unattended cycle, on
either app, closes that gate. The fix that got here is below.

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

`installations.db`'s `one_off: 0` and `refresh_at_hours: 96` on both AkshatOS and WHOOP look like
automatic-refresh enrollment already being active for both — confirm visually in Sideloadly's own
window rather than trusting that inference alone. The health check above is what actually tells you
whether a wireless cycle happened; silence from the phone is not evidence either way.

**Fixed, and confirmed working — Bonjour was never the fix.** Two changes were made together, and
the original write-up here credited both on reasoning, not evidence. Tested afterward, in two steps:

1. ~~Bonjour was not installed~~ **— tested, ruled out, then removed.** Bonjour Print Services was
   installed at the time, reasoning that Sideloadly's Windows discovery runs on Bonjour/mDNS
   (`mDNSResponder.exe`). Three tests settled it:
   - **Holding:** with the phone already connected, Bonjour was stopped. The connection kept
     working, still holding half an hour later.
   - **Cold start:** Sideloadly was fully quit from the tray — not just the window — and relaunched
     from scratch, Bonjour still stopped the whole time (confirmed by process start time, 3:46:36 PM,
     after the stop). It found the phone over Wi-Fi immediately.
   - **Fully uninstalled** (both `Bonjour Print Services` and `Bonjour` registry entries, the service,
     and both install folders — confirmed gone). Sideloadly still showed `@Wi-Fi` afterward.
   Bonjour has no role here, discovery or otherwise — Apple Mobile Device Service does this on its
   own. **Not installed on this machine at all**, as of the same session; nothing depends on it.
2. **The iPhone's Private Wi-Fi Address was set to rotating**, on this specific network — this is now
   the entire explanation, not one of two contributing changes. A rotating MAC address is a moving
   target for device discovery. Fix: iPhone Settings → Wi-Fi → (this network) → **Private Wi-Fi
   Address → Off**. `Limit IP Address Tracking` is unrelated (an IP-tracking privacy setting, not
   device discovery) and can stay on or off independent of this fix.

After the Private Wi-Fi Address change, Sideloadly showed the phone as `@Wi-Fi` and began installing
without USB. The
first attempt hit a second, unrelated bug — see below — but the very next attempt, **fully
unattended** (Akshat did nothing; Sideloadly launches at Windows startup on its own), completed a
real corroborated refresh: WHOOP, 2026-09-13 08:22:48, expiry moved to Sep 20. That is the first of
the two unattended cycles the gate below asks for.

**A known second failure mode, seen once so far:** the very first wireless refresh attempt failed
with `Install failed: Guru Meditation 556260@79:6edd68 __init__() missing 1 required positional
argument: 'orig'` — Sideloadly's own cached copy of WHOOP's IPA had gone missing from its internal
store, unrelated to anything in `D:\AI Important Files\personal-project\final-ipas`. It cleared on its own on the next attempt roughly 22
minutes later, without a manual reinstall. Whether that was the daemon self-healing or coincidence is
not established from one occurrence. If it recurs and does not clear on its own, the fix is a manual
reinstall from `D:\AI Important Files\personal-project\final-ipas\<project>\backup\` — see "What it does when something is wrong" above.

## What this has already found

**A stalled or cancelled install leaves debris in Sideloadly's own database, and the reader now
handles it.** Found while trying to align AkshatOS and WHOOP onto the same refresh clock — after
AkshatOS's manual reinstall completed cleanly, a same-day manual WHOOP reinstall was attempted for
the same reason and stalled mid wireless transfer instead. It was cancelled here rather than
retried, so the two apps are not on a shared clock: AkshatOS last signed 2026-09-13 16:31 from that
reinstall, WHOOP last signed 2026-09-13 08:18 from its own earlier unattended refresh — about 8
hours apart, not identical, but both close enough that they will not drift back to the original
nine-day gap. Retrying the WHOOP reinstall for full alignment is optional, not a gap to close.
Sideloadly signed and uploaded the IPA successfully but never
got a completion signal back, and cancelling in its own UI did not delete the row — it left a second
`WHOOP` row behind with its `last_updated` at Sideloadly's zero-value date (year `0001`), which read
literally computed an expiry hundreds of thousands of days in the past. Confirmed this is Sideloadly
housekeeping debris, not a real problem: the app's original row was untouched (no error, no
failures), and the cached IPA file the earlier "orig" bug worried about was intact and correctly
referenced.

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

**The real test is WHOOP**, whose 96-hour refresh point falls the evening of the day this was
installed. If its `last_updated` moves on its own, the daemon works and the loop is closed. If it
does not, the daemon does not refresh on this machine and the fallback is a manual refresh every few
days, with this check as the reminder. As of the last look, nothing had refreshed yet: all three
registrations still have `last_updated` equal to their first install.

## Still open

These stay open until exercised, per the operating model in `CLAUDE.md`:

- [x] ~~Two unattended refresh cycles observed~~ **One of two.** WHOOP, 2026-09-13 08:22:48,
      corroborated and unattended — Akshat did nothing; Sideloadly launches at Windows startup on
      its own. A `RECORD-CHANGED` line never counts, and neither does a line produced by a fixture
      run. One more, on either app, closes this.
- [ ] One deliberate USB recovery rehearsed from an expired or near-expired state.
- [ ] One forced failure — phone absent or offline at the refresh point — confirmed to raise the
      alert rather than pass quietly.
Until all three are done, do not describe weekly signing as dependable.
