# Weekly signing: setup and health check

How the sideloaded apps on Akshat's iPhone are kept signed, and how that is proved rather than
assumed. `cloud-build.md` owns producing and installing a build; this file owns keeping an already
installed one alive.

**Status:** The health check is installed and running. The refreshing half is Sideloadly's daemon,
which is installed and autostarts but **has never been observed to refresh anything**. Until it is,
treat weekly signing as unproven and expect to refresh by hand.

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
explicitly to override that. This matters because a fixture run *did* once write into the real state,
and the next real run read the difference back as a refresh that had never happened.

The database is copied before reading so a health check can never lock or alter the daemon's own
store. The signing material beside it (`key.pem`, `cert-*.pem`, `sessions.json`) is never read,
copied or committed, and the reader selects named columns only.

Run it by hand any time:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI Important Files\personal-project\akshatos\scripts\check-signing-health.ps1"
```

Add `-Quiet` to suppress the pop-ups and just read the log lines. Exit code is `0` healthy,
`1` warning, `2` act now.

## What it does when something is wrong

| Condition | What happens |
|---|---|
| 3 days or less left | Balloon warning — the daemon should have acted at 4 days and did not |
| 2 days or less, or expired | **Blocking dialog**, deliberately impossible to miss |
| `failures_count` or `last_error` set | Blocking dialog naming the error |
| Python missing, database unreadable | Blocking dialog — a check that cannot run must shout, not pass |

The recovery it tells you to do, in order: open Sideloadly and use **Refresh All Apps Manually**
with the iPhone unlocked and on the same Wi-Fi; if that fails, connect USB and install the cached
IPA again. **Never uninstall to fix signing** — that deletes the app's data.

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

## What this has already found

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

It also found a fault in itself. The log carries two `REFRESHED` lines dated `2026-09-12 14:55`
that are **test artifacts, not refresh cycles**, and a `NOTE` line in the log now says so:

- The first ran against a fixture database, so it reported the fixture's bundle
  (`com.example.testapp.TEAM1`) under WHOOP's name and gave a "new expiry" four days in the *past* —
  a nonsense success.
- The second looks real, naming the true bundle and a plausible expiry, but it fired only because
  that fixture run had overwritten the shared `state.json`; the very next line of the same run said
  WHOOP had *never* been refreshed since first install. Nothing had been signed.

Both causes are now fixed: success is corroborated before it is claimed, and a fixture run writes to
its own sidecars. The reason this mattered more than an untidy log is that `REFRESHED` is the only
evidence the gates below are ever closed on — two false ones sitting in the log is exactly how the
refresh loop gets recorded as proven without a single refresh having happened.

**The real test is WHOOP**, whose 96-hour refresh point falls the evening of the day this was
installed. If its `last_updated` moves on its own, the daemon works and the loop is closed. If it
does not, the daemon does not refresh on this machine and the fallback is a manual refresh every few
days, with this check as the reminder. As of the last look, nothing had refreshed yet: all three
registrations still have `last_updated` equal to their first install.

## Still open

These stay open until exercised, per the operating model in `CLAUDE.md`:

- [ ] Two unattended refresh cycles observed, each logged as `REFRESHED` with a new expiry.
      Count only lines dated after 2026-09-12 14:55 — the two before that are the test artifacts
      described above, and the `NOTE` line in the log marks them. A `RECORD-CHANGED` line never
      counts.
- [ ] One deliberate USB recovery rehearsed from an expired or near-expired state.
- [ ] One forced failure — phone absent or offline at the refresh point — confirmed to raise the
      alert rather than pass quietly.
Until all three are done, do not describe weekly signing as dependable.
