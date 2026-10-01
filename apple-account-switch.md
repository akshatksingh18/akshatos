# Moving signing to a separate Apple Account

Plan for signing AkshatOS and WHOOP with a dedicated Apple Account instead of Akshat's main one.
`setup.md` owns weekly signing; this file owns only the one-time switch.

**Status:** Planned, not started. Waits for Build 31 (which has the full backup) to be installed and checked, then Akshat creates the new
account and gives the go-ahead. Nothing is blocked today: AkshatOS 0.6.0 installed on 2026-09-29 and
WHOOP was refreshed by the daemon on 2026-09-27 under the current account.

## Why

Since September 2026, installs signed by some free developer teams fail with `0xe8008024` or
`0xe8008018` ("the provisioning profile is banned"). Public reports (checked 2026-09-30) say the
block sits on the free developer team, not the Apple Account itself: sign-in, iCloud and purchases
keep working, apps already installed keep running until their seven-day signature ends, and a
different free account on the same phone has installed normally in every report so far. What
triggers it and whether Apple extends it to new accounts are unknown. Moving signing to a separate
account keeps the main account out of sideloading entirely and gives a clean team if the current
one is blocked.

## What changes

- **App identity.** Sideloadly appends the team ID to each bundle ID (`scripts/signing-apps.json`).
  A new team means new final IDs, so iOS sees two new apps. Their containers start empty; nothing
  carries over by itself.
- **Data.** AkshatOS's data goes across in one folder through the hub's **Backup** screen (Back up
  everything, then Restore everything in the new app — `hub-plan.md` § Full backup; from Build 30).
  WHOOP uses its own encrypted export, owned by `../whoop/guides/IOS_SIDELOAD.md`.
  Not in any backup and redone by hand: notification and location permissions, the Pushups Home
  area, and WHOOP's band pairing.
- **Slots.** A free account allows 3 sideloaded apps per device and 10 App IDs per 7 days. The phone
  has 2 today, so the switch goes one app at a time: new AkshatOS (3rd slot), remove the old one,
  then the same for WHOOP.
- **Health check.** `signing-apps.json` gets the new final IDs, and the old IDs are retired by exact
  ID in `scripts/read-signing-state.py` (a prefix would also retire the new ones), since Sideloadly
  keeps old rows forever.

## Steps

1. **Akshat — new account.** At <https://account.apple.com>, create an Apple Account with an email
   used for nothing else at Apple (a new Gmail is fine). Two-factor needs a trusted phone number;
   your usual number can be used. Do not sign in to it on the iPhone's Settings or iCloud — it is used
   only inside Sideloadly. Claude cannot create the account or enter its password.
2. **Akshat — backups on the phone.** End any running Pushups day. In AkshatOS, Backup → Back up
   everything, and in WHOOP its encrypted export, both into OneDrive in Files; confirm the folders
   are there. Do this
   before anything else, and redo it if a day passes.
3. **AkshatOS.** In Sideloadly, add the new account, then install the cached Build 31 (or later) IPA,
   which has the full backup, with the usual settings (automatic bundle-ID mode, automatic refresh on). Trust the new developer under
   Settings → General → VPN & Device Management. The new AkshatOS opens empty — use Backup →
   Restore everything there, turn notifications back on, set up Home again, and check the data. Only then delete
   the old AkshatOS (the one still showing your data before the restore); deleting it removes its
   copy of the data.
4. **WHOOP.** Same pattern with its exact mode and a new override,
   `com.akshat.personal.whoop.<new team ID>`; restore and re-pair per WHOOP's guide, then delete the
   old WHOOP.
5. **Claude — records.** Update `signing-apps.json`, retire the old IDs, then run
   `read-signing-state.py` and require both apps ENROLLED at the new IDs. Update this file,
   `setup.md`, `CLAUDE.md` and WHOOP's docs. Remove the old account from Sideloadly after that.
6. **Proof.** The switch is done after one unattended daemon refresh under the new account, the same
   evidence `setup.md` asks for.

## If the current team is blocked first

Installed apps keep working until their signature ends (AkshatOS 2026-10-06, WHOOP 2026-10-04 as of
this plan), but new installs and refreshes fail. Go straight to step 1; the fresh backups from step
2 are what make that safe, so keep them current until the switch is done.

## Sources

- [Provisioning profile banned (0xe8008024, 0xe8008018)](https://builds.io/blog/technologies/ios-technologies/provisioning-profile-banned-iphone-0xe8008024/)
- [Free Apple IDs hit banned provisioning profile error](https://onejailbreak.com/blog/free-apple-ids-hit-banned-provisioning-profile-error/)
- [Apple free-account limits](https://developer.apple.com/help/account/basics/about-your-developer-account/)
