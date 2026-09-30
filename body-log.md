# Body module

Local-only body-composition tracking inside AkshatOS: a daily morning weigh-in, a weekly tape
measurement of eight sites, and progress photos every two weeks. It exists to support a calorie
deficit in which the weekly weight trend, the waist and the photos decide — not any single day.

**Status:** In Build 29 (0.6.0), which passed PR/main CI and artifact validation (`cloud-build.md`); not yet installed or phone-verified. The
private coaching logs in the workspace's `health/fitness/` project remain the source of truth until
Akshat explicitly switches entry to the phone (see Acceptance gates). No personal measurement,
height, weight or photo is bundled in source or belongs in this public repository.

## Product contract

- **Weight:** one entry per day in pounds, logged in the morning after the bathroom and before food
  or water; logging again the same day replaces it. The screen shows today's entry, the rolling
  seven-day average, and this weekly block's average with its change from the previous block.
  Weekly blocks start on the measurement weekday so a week's average and its tape session line up.
- **Weekly tape (inches), in this order:** waist at the navel, lower belly (about 2 in below the
  navel), hips (widest part of the glutes), neck, chest (nipple line), shoulders (widest point), right
  upper arm (flexed), right thigh (widest point below the glutes). Together they cover where fat loss
  shows, where muscle gain shows, and the neck the body-fat estimate needs. Each field shows where
  the tape goes; blank sites are skipped; values are checked (5–80 in) and rounded to 0.01 in. Each
  site shows its change since the most recent earlier session that measured it. Sessions can be
  edited or deleted. The stored site keys are fixed identifiers (`BodySite` raw values); an unknown
  key written by a newer build is preserved on edit.
- **Estimates, labelled as estimates:** the US Navy circumference body-fat estimate (male formula:
  86.010·log10(waist − neck) − 70.041·log10(height) + 36.76, inches) and waist-to-height ratio, both
  from the latest session with the needed sites. Height is entered once in the module's settings and
  stays on the phone; without it no estimate is shown. The trend matters, not the exact number.
- **Progress photos:** front and side, due every 14 days from the latest photo. Taken with the
  camera (the app's only use of the camera permission) or chosen from Photos without any photo
  permission. Stored only in the app's storage as JPEGs re-encoded to at most 2048 px, which also
  drops the original's location metadata. The screen shows the first and latest photo of a pose side
  by side. Like PageVault's PDFs, photos are included in the phone's own device backup.
- **Weekly reminder:** optional, on the measurement weekday (Saturday by default) at a chosen morning
  hour. It uses the `akshatos.body.` notification namespace, which the app layer routes to this
  module, and never touches Pushup Reminder's requests. Without notification permission the toggle
  stays off and says why.
- **Backup and CSV:** the backup is a plain folder, `body-log.json` plus `photos/`, validated in full
  (version, unique records, one weigh-in per day, real dates, value ranges) before a confirmed restore
  replaces everything; a failed restore changes nothing, photos included. From 0.7.0 it also carries
  height and measurement day (optional, so older backups still read and leave them as they are); the
  reminder setting is not carried, since it needs permission on the phone. The hub's Backup screen
  includes this folder as `body/` (`hub-plan.md` § Full backup). CSV export is one row per
  day, oldest first: `date, weight_lb` then one inch column per site, blank where not measured.
- Local-only, single-user: no account, HealthKit write, analytics, cloud sync or server.

## Current source layout

- `ios/AkshatOS/features/body/domain/BodyLog.swift` — sites, records, validation, day/week
  arithmetic, averages, change, Navy estimate, photo cadence, CSV and backup contract (Foundation
  only).
- `ios/AkshatOS/features/body/data/` — versioned SwiftData store (one JSON payload per record) and
  the photo file storage with its swap/roll-back restore.
- `ios/AkshatOS/features/body/services/BodyReminderService.swift` — the weekly notification.
- `ios/AkshatOS/features/body/BodyLogStore.swift` — save-before-show commands, derived values,
  settings, reminder, export and restore.
- `ios/AkshatOS/features/body/ui/` — the Body screen, the measurement form, photos (camera, picker,
  comparison), history and detail, and settings.
- `ios/tests/body/main.swift`, `ios/UnitTests/BodyLogPersistenceTests.swift` and
  `ios/UITests/BodyUITests.swift` — registered domain, persistence/photo/backup/reminder and
  navigation coverage.

## Acceptance gates

- The exact source must pass its PR and clean-main `CI Gate`, and the artifact its checksum and IPA
  validation, before it is installed.
- Phone pass: log a weigh-in and replace it the same day; complete and edit a weekly session and see
  the changes; set height and see the estimates; take a camera photo and choose one from Photos,
  compare first and latest; enable the reminder and receive it on the measurement day, tapping it
  opens Body; export a backup folder and a CSV; restore the backup onto a changed library.
- Until Akshat explicitly confirms the switch, weigh-ins and waist measurements continue to be
  recorded in the private `health/fitness/` logs; afterwards the phone is primary for new entries and
  the CSV export is the bridge for the weekly review. Existing private rows are never copied into
  this public repository.
