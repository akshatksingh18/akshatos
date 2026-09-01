# TODO / known gaps

Nothing here is urgent — the app should work as-is once built and sideloaded.
Rough order of what's probably worth doing first if you pick this back up:

- [ ] **No launcher icon.** Currently relies on Android Studio's default
      generated icon (or none, if it doesn't scaffold one for a manifest
      with no `android:icon` set). Cosmetic only — doesn't affect function.
      Add an `ic_launcher` set via Android Studio's Image Asset tool if you
      want a real icon.

- [ ] **Never actually built/run.** This was scaffolded without access to
      Android Studio or an SDK in the environment it was written in — open
      it in Android Studio and do a first build/run pass before trusting it.
      Likely rough edges: exact Compose API surface for the version pins,
      and whether the exact-alarm settings deep link
      (`ACTION_REQUEST_SCHEDULE_EXACT_ALARM`) behaves as expected on your
      specific Android version.

- [ ] **UI doesn't reflect actual notification-delivery capability.** "Running" is read straight
      from the `isRunning` preference, not from whether `POST_NOTIFICATIONS` is actually granted.
      If the user denies/revokes it after starting, the app keeps showing "Running" while
      reminders silently stop arriving. Fix: check
      `ContextCompat.checkSelfPermission` in the UI (not just in `ReminderReceiver`) and surface a
      warning state instead of a bare "Running."

- [ ] **No input validation UI beyond digit-filtering.** The minutes field
      clamps to >= 1 on Start, but there's no visible error state if you
      leave it blank or type 0 — it just silently falls back to 45. A
      small helper/error text would make that less surprising.

- [ ] **No snooze / skip-one-reminder.** If a reminder fires at a bad moment
      (mid-meeting), there's no in-notification action to push it back —
      you just dismiss it and wait for the next one. A notification action
      button calling into `ReminderScheduler.scheduleNext()` with a longer
      delay would cover this.

- [ ] **No "pause without losing today's Start."** Stop fully cancels the
      chain; there's no quick pause/resume within a day. Not clear this is
      wanted — flagging in case it comes up.

- [ ] **Doze / manufacturer battery optimization.** Some OEMs (Samsung,
      Xiaomi, etc.) aggressively kill apps or ignore exact alarms unless the
      app is also exempted from battery optimization. If reminders start
      silently skipping after a few hours, check
      Settings -> Apps -> Squat Reminder -> Battery -> Unrestricted.

Not planned unless you ask for them (deliberately kept out of scope for a
one-job app): reminder history/log, multiple reminder profiles/schedules,
widget.
