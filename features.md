# Squat Reminder feature plan

**State:** Accepted iPhone-first product plan; none of these iPhone features is implemented or
physically verified yet. The existing Android scaffold remains a separate unverified fallback and
does not imply feature parity.

## Product promise

Squat Reminder is a local-only daily movement companion. It should take one tap to begin a day,
reliably remind Akshat at a default 45-minute cadence, make interruptions easy to handle, record
completed squat breaks honestly, and finish with a useful daily overview. It is not a fitness social
network, coaching service, location tracker, or health-data platform.

The core loop is:

1. Tap **Start my day**.
2. Receive an ordinary local reminder every 45 minutes by default.
3. Tap **Done** after completing a squat break, or use **Pause** / **Remind me in 10 min** when the
   moment is inconvenient.
4. Resume after returning from an interruption.
5. Tap **End my day** and review the day's completed sets and timing.

The interval remains configurable in whole minutes while no active day exists; 45 minutes is the
default. The canonical v1 count is **completed squat sets/breaks**, not an inferred number of
individual squat repetitions. Each explicit Done action records one set. A configurable reps-per-set
or per-set rep editor is a later option; until then the app must not label a set count as total reps.

## Daily lifecycle and state

The UI and scheduler share an explicit state machine:

- **Not started:** no active day and no recurring reminder. The primary action is Start my day.
- **Running:** an active day exists, notification permission is usable, and the correct recurring
  request is pending. The UI shows the next scheduled reminder and Pause / Done controls.
- **Paused:** the active day remains open, but the recurring request is cancelled. Completions may
  still be logged manually. Resume starts a fresh interval, so the first normal reminder is one full
  interval after Resume.
- **Ended:** the day's recurring and snooze requests are cancelled, the session is finalized, and
  the daily overview is shown. An ended session cannot be resumed; starting again creates a new
  session only after an explicit confirmation if it is still the same local day.
- **Blocked:** notification permission/settings cannot currently deliver reminders. The app keeps
  the data truthful, shows the reason, and links to Settings rather than pretending to run.
- **Repair required:** stored intent and actual pending requests disagree. The app explains the
  mismatch and offers an idempotent repair/re-arm action.

Start, Pause, Resume, End, and Done must all be idempotent. Repeated taps or duplicate callbacks
cannot create duplicate schedules, duplicate sessions, or duplicate completion events.

## Dashboard and visual direction

The main screen should feel calm, polished, and immediately readable rather than like a settings
form. The first implementation should establish a small reusable visual system instead of hard-coded
one-off styling.

- A large hero card shows the current state, a circular time-until-next-reminder treatment while
  running, and a clear paused/blocked/ended illustration in other states. The time is labelled as
  **scheduled**, because Focus and other iOS settings can delay actual presentation.
- A prominent count card shows **sets completed today** with a one-tap **Done +1** control. An Undo
  affordance is available after an accidental tap and from the day's event list.
- The primary lifecycle control changes with state: Start my day, Pause, Resume, or View summary.
  **End my day** remains visually separate and requires confirmation so it is not hit accidentally.
- A compact Today timeline lists completion times plus pause/resume/snooze events. It should be
  useful at a glance without turning the app into a detailed workout tracker.
- Small quick controls expose Remind me in 10 min, Pause, Resume, and notification settings only
  when relevant. Disabled controls explain why they are unavailable.
- Motion, gradients, haptics, and celebratory feedback may add warmth, but respect Reduce Motion,
  Dynamic Type, VoiceOver, contrast, and one-handed use. Meaning must never depend on color alone.
- The app uses a small number of locally bundled reminder-message variations to avoid feeling
  robotic. Messages remain clear and never claim that a set was completed automatically.

No widget, Live Activity, Watch target, or notification-content extension is required for this
dashboard. Those would add signing/capability complexity without improving the core loop enough.

## Reminder and notification actions

Use one stable repeating `UNTimeIntervalNotificationTrigger` request for the normal cadence and a
registered actionable-notification category. The normal request begins one full interval after Start
or Resume and continues until Pause or End removes it.

The reminder category provides these actions:

1. **Done** — record exactly one completed set for the active day without requiring the app UI to
   open. It does not change the regular 45-minute cadence.
2. **Pause** — cancel the recurring request and move the active day to Paused. This is the escape
   hatch when the first inconvenient reminder arrives while away from home.
3. **Remind me in 10 min** — schedule or replace one one-off snooze request ten minutes later. The
   underlying regular cadence remains active, so the following normal reminder is still based on the
   original interval. Snooze never records a completed set.

iOS may show only the first two category actions in compact space, so Done and Pause receive the
first two positions; the 10-minute action is available from the expanded notification and the
dashboard. Physical-device testing must confirm the actual lock-screen/banner presentation on the
target iPhone.

Notification actions run through the same domain commands as dashboard buttons. Action handling must
be safe while the phone is locked, persist an idempotent event before returning control to iOS, and
merge any small pending-action inbox into the main day log on the next foreground reconciliation.

Only one normal recurring request and one snooze request may exist. Pause cancels the normal request
and any obsolete snooze. End cancels all project-owned pending and delivered reminders. A delivery
already in flight can race with Pause or End; the app documents observed behavior rather than
promising atomic recall.

## Pausing, returning, and forgotten-away cases

The dependable baseline never guesses location:

- The dashboard offers Pause until I resume.
- The notification offers Pause when an inconvenient reminder is already visible.
- Resume always requires an explicit app, notification, Siri, or Shortcut action and starts a fresh
  interval.
- For a short interruption such as dinner, Remind me in 10 min is preferred over pausing the day.
  Repeated snoozes replace the existing snooze instead of accumulating notifications.

After the core loop works, expose local App Intents for **Start my day**, **Pause reminders**,
**Resume reminders**, **Log completed set**, and **End my day**. They make optional Siri/Shortcuts
workflows possible without making Shortcuts a runtime dependency.

Recommended optional personal automations are:

- **Leave Home → Pause reminders**, but only if a day is currently Running.
- **Arrive Home → Resume reminders**, but only when that day was paused by the matching away
  automation; it must not restart an ended day or override a deliberate manual pause.
- **Fitness Focus / workout starts → Pause**, and its matching end event → Resume, if that better
  matches Akshat's routine.
- A bedtime or chosen Time of Day automation may run End my day, with the final confirmation
  behavior decided during physical testing.

The app records the source/reason for a pause so an arrival automation cannot resume the wrong kind
of pause. Shortcut failures or disabled automations leave the dashboard state truthful and recoverable.
Native always-on location/geofencing is deferred: it would add location permission, privacy and
background-behavior costs to an app that does not otherwise need them. Reconsider it only if the
Shortcuts route proves inadequate on the actual phone.

## Counting, overview, and lightweight history

Every explicit Done action creates a timestamped completion event tied to the active day. A
completion can come from the dashboard, notification, Siri, or Shortcut, and all paths use the same
deduplication rules. The user can undo/delete an accidental completion with confirmation where
appropriate.

Ending the day presents a clean overview containing:

- completed set count;
- start and end times;
- active and paused duration;
- completion timeline;
- number of snoozes and pause segments;
- interval used for that day.

The summary must not claim how many notifications iOS actually showed or calculate a completion rate
from unobservable deliveries. Scheduled notifications can be delayed or suppressed by user/system
settings, so only explicit user actions count as completions.

Keep finalized daily summaries locally so the user can revisit recent days. A simple history screen
may show daily set counts and open an individual day; streaks, charts, goals, achievements, sharing,
HealthKit, and detailed workout analytics remain later decisions. There is no account, cloud sync,
remote analytics, or server. Data deletion and any future export must be explicit and local.

## Settings

V1 settings are intentionally small:

- reminder interval in whole minutes, default 45, editable only when no active day exists;
- notification permission/status and a route to iOS Settings;
- sound/haptic preference only where ordinary notification APIs permit it;
- optional reminder-message variation toggle;
- Shortcuts setup guidance after App Intents are implemented;
- local history deletion with destructive confirmation.

A daily set goal, reps-per-set, end-of-day reminder time, scheduled quiet window, and more snooze
durations are candidate polish—not prerequisites for the first reliable release.

## V1 scope and sequencing

The first usable release includes:

- the polished dashboard and explicit lifecycle states;
- default/configurable interval;
- Start, Pause, Resume, and End;
- Done +1 from dashboard and notification;
- one 10-minute snooze;
- current-day event log, end-of-day overview, and lightweight local daily summaries;
- permission/pending-request reconciliation and truthful blocked/repair states;
- accessible design and physical-iPhone verification.

App Intents plus Leave/Arrive/Focus automation guidance follow immediately after the core state,
notification actions, and persistence paths pass on-device testing. Native geofencing, widgets,
social features, remote services, HealthKit, detailed rep tracking, goals/streaks, and advanced
analytics are not part of the initial reliability gate.

## Feature acceptance

A feature is complete only when its state transition, persisted data, notification requests, and UI
agree after relaunch and foreground reconciliation. Notification actions must be tested while locked,
backgrounded, force-quit, and under representative Focus/Scheduled Summary settings. Shortcuts must
be tested with the actual Leave/Arrive or Focus automation and with automation disabled or failing.
No intended behavior is described as working until it passes on the physical iPhone.
