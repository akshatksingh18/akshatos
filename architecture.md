# Squat Reminder Architecture

## Stack

- Kotlin 2.2.20 and Jetpack Compose with Material3
- AGP 9.2.1, compileSdk/targetSdk 36, minSdk 26
- `AlarmManager.setExactAndAllowWhileIdle` for reminder scheduling
- SharedPreferences for running state, interval, and next trigger time
- No database, navigation framework, media stack, backend, or analytics

The versions above are scaffold selections, not verified build results. Re-check compatibility
when the project is activated.

## Source layout

```text
app/src/main/java/com/akshat/squatreminder/
├── MainActivity.kt        # Interval field, Start/Stop, and next-reminder display
├── ReminderScheduler.kt   # Starts, stops, schedules, and cancels alarms
├── ReminderReceiver.kt    # Shows a notification and schedules the next alarm
├── BootReceiver.kt        # Re-arms the chain after reboot when marked running
└── ReminderPrefs.kt       # SharedPreferences wrapper
```

## Design decisions

### The interval is user-settable

The interval is stored in preferences and should be editable only while stopped. The scheduler
reads it again for each new alarm so the next started chain uses the current value.

### Exact alarms instead of periodic work

The intended behavior requires reminders near the selected interval even while the phone is
idle. WorkManager periodic work has a minimum interval and intentionally batches execution; a
foreground service would add persistent-notification and lifecycle complexity. Exact alarms fit
the intended personal reminder behavior, subject to Android permission and OEM restrictions.

### A self-rescheduling chain

Each receiver invocation schedules the next alarm only when the stored running state remains
true. This avoids an inexact repeating alarm and keeps only one alarm in flight.

### Permission-aware state

The manifest permission alone is insufficient. The app must account for exact-alarm access and
notification permission. Displayed “Running” state should not imply successful delivery when a
required permission is absent.

### Reboot recovery

Exact alarms disappear on reboot. When the stored running state is true, the boot receiver is
intended to schedule the next reminder using the stored interval. This behavior remains
unverified until physical-device testing.

### SharedPreferences instead of a database

The product needs only running state, next-trigger time, and interval. There is no history or
multi-profile data that would justify a database.
