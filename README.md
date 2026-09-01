# Squat Reminder

A personal, local-only Android app: set an interval, press one button to
start your day, and every N minutes you get a notification reminding you
to squat. Press the other button before bed to stop until tomorrow. Not
meant for the Play Store — sideload only.

This is currently an unverified scaffold, not a finished application.

## Setup

1. Open this folder in Android Studio (`File -> Open`).
2. Let Gradle sync. Dependency versions here match `reels/` (Aug 2026). If
   Android Studio pops up an AGP/Kotlin upgrade banner, it's safe to accept.
3. Run on your phone:
   - Enable Developer Options + USB debugging on the phone.
   - Plug in via USB, select "Allow" on the RSA prompt.
   - Hit Run in Android Studio, pick your device.
4. A Gradle wrapper is not stored yet. Add and commit it when the project is
   activated before relying on `./gradlew assembleDebug` outside Android Studio.

## First run

- The app asks for notification permission (Android 13+) on first launch —
  allow it, or reminders won't show.
- The first time you tap "Start my day," if your phone hasn't already
  granted exact-alarm scheduling (Android 12+), a dialog will send you to a
  system settings screen to turn it on. This is a one-time toggle per
  install, not per day.

## Intended behavior

- **Minutes field**: set your reminder interval before starting (defaults
  to 45). Locked while running — stop first if you want to change it.
- **Start my day**: arms a chain of exact alarms at the interval you set,
  starting N minutes from the moment you tap it.
- **Stop for the night**: cancels the pending alarm and marks the chain as
  stopped, so nothing fires again until you tap Start.
- **Reminders**: a high-priority notification titled "Squat time" —
  tapping it opens the app.
- **Survives reboot**: if your phone restarts while the reminder chain is
  running, it re-arms itself automatically at the same interval (next
  reminder is N minutes from the reboot, not from the original schedule).

## Known limitations

See [todo.md](todo.md).
