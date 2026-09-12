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

Explicitly **not** success: the daemon process running, its log file changing, the check exiting
cleanly, or an app merely not being expired yet.

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

## What this has already found

At the time it was installed, all three registrations had `last_updated` still equal to their
original install time: the daemon had never refreshed anything. The retired **Squat Reminder**
registration had expired two days earlier with `failures_count: 0` and an empty `last_error` —
it did not fail, it simply was never attempted.

That one is the historical smoke app Akshat removed from the phone, so the daemon may be correctly
skipping something that no longer exists; it is suggestive, not proof. Remove that stale
registration from Sideloadly anyway: it is dead, it occupies one of the three free app slots, and
it will otherwise raise a critical alert every run forever.

**The real test is WHOOP**, whose 96-hour refresh point falls the day after this was installed. If
its `last_updated` moves on its own, the daemon works and the loop is closed. If it does not, the
daemon does not refresh on this machine and the fallback is a manual refresh every few days, with
this check as the reminder.

## Still open

These stay open until exercised, per the operating model in `CLAUDE.md`:

- [ ] Two unattended refresh cycles observed, each logged as `REFRESHED` with a new expiry.
- [ ] One deliberate USB recovery rehearsed from an expired or near-expired state.
- [ ] One forced failure — phone absent or offline at the refresh point — confirmed to raise the
      alert rather than pass quietly.
- [ ] The stale Squat Reminder registration removed from Sideloadly.

Until all four are done, do not describe weekly signing as dependable.
