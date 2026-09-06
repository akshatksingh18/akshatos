# Squat Reminder feature plan

**State:** Accepted full Squats feature contract inside AkshatOS. The first source implementation
covers the hub picker, dashboard lifecycle/counting/snooze, local sessions, and goal/streak display.
`architecture.md` lists exact implemented and deferred behavior; `cloud-build.md` records build
and device evidence. Notification actions and a durable inbox passed cloud regression tests. Daily
overview/history and local recovery are implemented and passed the build-5 cloud gate. Home
automation and full foreground reconciliation are implemented and cloud-verified: saved lifecycle
intent is compared with notification permission plus recurring/snooze requests, and the protected
Home boundary is compared with the actual system registration. Build 9 chooses an eight-set
initial goal and a 150-meter initial Home radius and expands native-v1 automated coverage.
Build-9 cloud verification passed in PR #4 run #37. Build-10 source implements the accepted countdown
and completion-list refinements and persists the regular cadence anchor after phone testing exposed a
close/reopen countdown reset. PR #7 and main delivery run #43 passed the Build-10 cloud gate;
physical acceptance remains outstanding.
Android is an unverified fallback.

## Hub entry

AkshatOS opens to an app-selection screen. Choose **Squat Reminder** to open this dashboard;
navigate back without changing its active session or reminders. PageVault/ReelVault are visibly
planned entries until their features are implemented, and WHOOP is not embedded.
The hub receives display metadata and injected destinations; it does not own Squats rules or data.
The source-boundary refactor changes no user-facing feature scope or reminder/streak behavior.

## Product promise

Squat Reminder is a local-only daily movement companion. It should take one tap to begin a day,
reliably remind Akshat at a default 45-minute cadence, make interruptions easy to handle, record
completed squat breaks honestly, protect a motivating daily streak, and finish with a useful daily
overview. It is not a fitness social network, coaching service, movement-history tracker, or
health-data platform.

The core loop is:

1. Tap **Start my day**.
2. Receive an ordinary local reminder every 45 minutes by default.
3. Tap **Done** after completing a squat break, or use **Pause** / **Remind me in 10 min** when the
   moment is inconvenient.
4. Optionally let the Home geofence pause the active day on departure and resume it on return.
5. Reach the configured daily set goal to preserve the streak.
6. Tap **End my day** and review the day's completed sets, goal/streak result, and timing.

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
  running, and a clear paused/blocked/ended illustration in other states. With no snooze pending,
  the prominent countdown shows the next regular reminder. While a ten-minute nudge is pending,
  that nearer deadline replaces the regular countdown as the single prominent clock. The persisted
  regular cadence anchor keeps close/reopen and foreground reconciliation from restarting the clock.
  Times are labelled as **scheduled**, because Focus and other iOS settings can delay presentation.
- A prominent count card shows **sets completed today** with a one-tap **Done +1** control. An Undo
  affordance is available after an accidental tap and from the day's event list.
- A motivating streak card shows progress toward the daily set goal, the current streak, and the
  personal-best streak. Before the goal is reached it says exactly how many sets remain; after the
  threshold it changes to a clear protected/completed state without inflating the count again.
- The primary lifecycle control changes with state: Start my day, Pause, Resume, or View summary.
  **End my day** remains visually separate and requires confirmation so it is not hit accidentally.
- The compact **Your day so far** list shows only completed sets and their completion times. Pause,
  resume, snooze and other reminder-maintenance events remain internal lifecycle/history data and
  must not clutter this dashboard list. Undo remains available for the most recent completed set.
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
   ten-minute deadline becomes the dashboard's sole main countdown. The intended next normal cycle
   begins after that postponed reminder rather than competing with it; implementation must not claim
   this is reliable until the delivered-notification schedule passes Build-10 device testing. Snooze
   never records a completed set.

iOS may show only the first two category actions in compact space, so Done and Pause receive the
first two positions; the 10-minute action is available from the expanded notification and the
dashboard. Physical-device testing must confirm the actual lock-screen/banner presentation on the
target iPhone.

Notification actions run through the same domain commands as dashboard buttons. Action handling must
be safe while the phone is locked, persist an idempotent event before returning control to iOS, and
merge any small pending-action inbox into the main day log on the next foreground reconciliation.
The implemented inbox uses atomic protected files available after first unlock. Receipt persistence
survives Undo and process restart; busy callbacks queue instead of disappearing. If primary storage
is temporarily unavailable, Done waits for merge, Pause cancels a matching schedule, and snooze may
be delayed until storage recovers (never beyond its original ten-minute deadline). The dashboard
shows queued actions and a retry control. Inbox write failure is reported rather than represented
as a completed set; reboot-before-first-unlock and locked delivery still require device testing.

Only one normal recurring request and one snooze request may exist. Pause cancels the normal request
and any obsolete snooze. End cancels all project-owned pending and delivered reminders. A delivery
already in flight can race with Pause or End; the app documents observed behavior rather than
promising atomic recall.

## Pausing, returning, and forgotten-away cases

The dependable manual baseline remains available at all times:

- The dashboard offers Pause until I resume.
- The notification offers Pause when an inconvenient reminder is already visible.
- A manual, notification, Siri, or Shortcut pause requires an explicit Resume. Only a pause whose
  recorded reason is `homeAwayAutomation` may auto-resume on the matching Home-entry event; every Resume
  starts a fresh interval.
- For a short interruption such as dinner, Remind me in 10 min is preferred over pausing the day.
  Repeated snoozes replace the existing snooze instead of accumulating notifications.

After the core loop works, expose local App Intents for **Start my day**, **Pause reminders**,
**Resume reminders**, **Log completed set**, and **End my day**. They make optional Siri/Shortcuts
workflows possible without making Shortcuts a runtime dependency.

The accepted native convenience is one optional **Home auto-pause** geofence:

- Let the user choose **Use my current location as Home**, confirm the circular boundary on a map,
  and adjust the conservative 150-meter initial radius during setup. That radius is intended to
  absorb ordinary location jitter without representing a broad neighborhood; physical testing owns
  the final suitability check. Store the coordinate/radius only in the app's local protected storage
  marked excluded from device backup; never upload it, include it in analytics, or retain a trail of
  visited locations.
- Ask for location only when Home auto-pause is enabled. Use a one-shot foreground location to set
  Home, explain why background access is needed, then request the authorization level required for
  reliable region entry/exit delivery when the app is not open.
- Leaving Home pauses only a Running day and records `homeAwayAutomation` as the reason. Entering Home
  resumes only the same still-active day when it is paused for that reason. It cannot start a new
  day, revive an Ended day, or override a manual/notification/Shortcut pause.
- A deliberate Pause received while already auto-paused promotes the reason to that deliberate
  source, preventing arrival from resuming it. If Home is known to be Outside when Start is tapped,
  offer **Start paused until I return** or **Start reminders anyway** instead of silently guessing.
  A confirmed manual Resume while Outside suppresses repeat exit auto-pauses until the next Home
  entry or the day ends.
- Use system geographic-region monitoring rather than continuous GPS updates. Boundary events are
  approximate rather than instant; debounce duplicate/rapid enter-exit events and expose the last
  observed Home state and automation health honestly.
- If permission is denied/reduced, region monitoring is unavailable, Background App Refresh is off,
  the phone has not been unlocked after reboot, or iOS does not deliver an event, keep the app usable
  through dashboard and notification actions and show that Home auto-pause is degraded—not healthy.
- Disabling Home auto-pause unregisters the region and deletes the stored Home coordinate/radius.
  It does not alter an active day's current manual state without confirmation.

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
Shortcuts remain a useful backup or alternate automation even with native geofencing. Native and
Shortcut Home-boundary actions use the same automation reason and idempotent pause/resume commands,
so either matching entry can recover from either exit and receiving both cannot double-transition
the day.

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
- interval and daily set goal used for that day;
- whether that local calendar day protected, extended, or started the streak—or remains at risk
  until the calendar day ends. A missed-day break appears once that day is actually over.

The summary must not claim how many notifications iOS actually showed or calculate a completion rate
from unobservable deliveries. Scheduled notifications can be delayed or suppressed by user/system
settings, so only explicit user actions count as completions.

Keep finalized daily summaries locally so the user can revisit recent days. A simple history screen
shows daily set counts, goal result, and streak status and can open an individual day. Charts,
achievements beyond the streak, sharing, HealthKit, and detailed workout analytics remain later
decisions. There is no account, cloud sync, remote analytics, or server. Data deletion and export/
restore are explicit and local. Restore validates the complete versioned backup before replacing
current Squats sessions and settings; deletion of completed history keeps an active day and preferences.

### Daily goal and streak contract

- A day qualifies when its explicit, non-undone completed-set count is **greater than or equal to**
  the configured daily set goal. New installs start at **eight completed sets**; the setting remains
  configurable from zero through 100, and zero explicitly turns streak tracking off. Eight targets
  roughly one completed movement break per working hour without requiring every 45-minute reminder
  to become a completed set.
- A qualifying local calendar day contributes at most one streak day, no matter how far above the
  goal the count goes or how many same-day sessions are started.
- Show **current streak**, **best streak**, today's `completed / goal` progress, and the number of
  sets remaining. Reaching the goal updates the streak result immediately and may trigger one local
  celebratory animation/haptic; it never creates a fake completion event.
- Today being below goal does not break the displayed existing streak while the local date is still
  current, even after End my day; label it **at risk** and show the shortfall. Once the calendar date
  rolls over, a goal-enabled day below target—or a skipped day after streak tracking has begun—breaks
  the consecutive-day streak.
- Streak tracking begins only after a goal is chosen/enabled. There is no retroactive failure for
  earlier days. Store the goal used with each daily summary; changing the goal applies prospectively
  and never rewrites whether older days qualified.
- Undoing/deleting a completion recomputes that day's qualification and streak deterministically.
  A past-day edit must warn when it will change current/best streak results.
- Use one canonical local-calendar-day policy across sessions, summaries, and streak calculation.
  Handle midnight, daylight-saving changes, manual clock/time-zone changes, and an accidentally
  unended prior-day session explicitly; never award two streak days for one calendar day or silently
  erase a qualification.
- V1 has no grace day, streak freeze, manual mark-as-complete, or purchased recovery. Those would
  weaken the meaning of the explicit Done counter and require a later product decision.

## Settings

V1 settings are intentionally small:

- reminder interval in whole minutes, default 45, editable only when no active day exists;
- notification permission/status and a route to iOS Settings;
- sound/haptic preference only where ordinary notification APIs permit it;
- optional reminder-message variation toggle;
- daily completed-set goal for streak qualification, initially eight sets with zero as opt-out;
- Home auto-pause setup/status, Home boundary edit/disable/delete, and clear location/background-
  refresh recovery guidance;
- Shortcuts setup guidance after App Intents are implemented;
- local history deletion with destructive confirmation.
- local versioned backup export and validated restore with replacement confirmation.

Reps-per-set, an end-of-day streak-risk reminder time, scheduled quiet window, and more snooze
durations are candidate polish—not prerequisites for the first reliable release.

## V1 scope and sequencing

Finish the agreed native v1 implementation and automated/cloud regression coverage first; Akshat
will test it on the phone afterward. Do not block unfinished coding on baseline sideload testing.
Build-6 source adds cloud-verified day/goal/streak edge handling and opt-in Home auto-pause. Build-7
source completes the dashboard/Settings UI and permission/accessibility behavior described above and
under Settings, and its exact source passed its own CI Gate. Foreground reconciliation is also
implemented and cloud-verified. Remaining work is physical validation plus broader automated
coverage. Optional Shortcuts remain
a follow-on, not
a new prerequisite for native v1.

The first usable release includes:

- the polished dashboard and explicit lifecycle states;
- default/configurable interval;
- Start, Pause, Resume, and End;
- Done +1 from dashboard and notification;
- one 10-minute snooze;
- current-day event log, end-of-day overview, and lightweight local daily summaries;
- configurable daily goal plus deterministic current/best streak calculation and goal progress;
- optional native Home geofence auto-pause/resume with local-only storage and manual fallbacks;
- permission/pending-request reconciliation and truthful blocked/repair states;
- accessible design and physical-iPhone verification.

App Intents plus Leave/Arrive/Focus automation guidance follow immediately after the core state,
notification actions, persistence, native geofence, and streak paths pass on-device testing. Widgets,
social features, remote services, HealthKit, detailed rep tracking, streak freezes, and advanced
analytics are not part of the initial reliability gate.

## Feature acceptance

A feature is complete only when its state transition, persisted data, notification requests, and UI
agree after relaunch and foreground reconciliation. Notification actions must be tested while locked,
backgrounded, force-quit, and under representative Focus/Scheduled Summary settings. Shortcuts must
be tested with the actual Leave/Arrive or Focus automation and with automation disabled or failing.
Home geofencing must be tested across authorization states, boundary noise, Background App Refresh,
reboot/unlock, force-quit, duplicate events, Start/Resume while outside, deliberate-pause precedence,
and missed-event recovery. Streaks must be tested at the goal boundary, across missed/skipped days,
Undo, goal changes, midnight, daylight-saving, and time-zone changes. No intended behavior is
described as working until it passes on the physical iPhone.
