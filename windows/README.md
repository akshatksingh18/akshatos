# AkshatOS Study Desk for Windows

Native Windows study timer. Portable candidate 0.1.0 passes cloud checks and native finish review;
a packaged candidate is not a physical-device pass. `../cloud-build.md` owns the current source,
run, local candidate path and checksum.
The WPF app uses .NET 10; CI publishes a self-contained x64 build, so using the packaged application
does not require installing an SDK or a separate runtime. The ZIP is unsigned.

## Use

Extract the complete portable ZIP to a local folder and open `AkshatOS.StudyDesk.exe`. Keep the
application outside iCloud/OneDrive folders; link only a dedicated transfer folder if desired.
Drag the title bar, resize/maximize normally, or select Stay on top. Customize controls timer text
size, the aim for future study days and an optional next-block topic. Settings and window placement
are remembered. The countdown scales down to fit narrow widths; controls remain reachable by scrolling.

Start records a timestamp. Pause ends the block. Lock, sleep, minimize and X pause; returning never
automatically resumes. Reading or video playback without keyboard activity is not treated as idle.
An unexpected interruption recovers paused at the last saved checkpoint (normally within 15 seconds),
never counts the entire offline gap and reports the recovery. A blocked UI/clock discontinuity also
pauses at the last visible update. These guards are conservative; they do not prove attention.

No tray timer, startup task, remote server, account sign-in, analytics or automatic cloud write.
Only one Study Desk process may run per Windows user.

## Local data and recovery

Local state is `%LOCALAPPDATA%\AkshatOS\StudyDesk\state.json`, with a previous-file recovery copy.
The executable folder contains no live records. A failed save retains the previous state and shows
an error; a normal close is blocked if the pause cannot be saved. Invalid existing data is not reset.
Keep recovery files local. There is no delete/reset command in this first build.

The study day and date heading roll over at 03:00. Sessions keep their originating IANA time zone and daily aim; duration
uses absolute timestamps, including DST. Changing the aim does not rewrite the current recorded day.
Closed sessions are read-only in exchange version 1. Independent cross-device corrections/deletions
are deliberately unsupported: changed IDs stop import, and absence never deletes history.

## Transfer with AkshatOS

This requires the companion exchange importer in updated AkshatOS source (Build 40). The previously
delivered Build-39 IPA cannot import this format; it remains the SideStore/display test candidate.
No Build-40 IPA is produced by normal source verification.

1. Export sessions in Study Desk, move the JSON to iPhone Files yourself, then use AkshatOS
   Apps > Settings & backup > Linked folder > Import laptop file and review before confirming.
2. For the reverse direction use Export phone sessions for Study Desk, then Import phone sessions
   on Windows. The separate roadmap `study-sessions.json` is a different format, not this exchange.
3. Optionally choose the same dedicated folder through iCloud Drive on each device. Windows writes
   `study-laptop-<source UUID>.json`; iPhone writes `study-iphone-<source UUID>.json`. Each origin
   owns its file. Send and Check are explicit actions. iPhone checks availability on foreground
   opening but does not automatically accept an import. Manual selection remains the fallback.
4. Use one timer at a time. Duplicate IDs add no time; overlapping blocks, changed sessions, wrong
   direction, future/invalid records and older imported revisions are refused. Whole files validate
   before save; a rejected file cannot partly replace local data. Import never re-exports someone
   else's records as new sessions. A disconnected device cannot know the other timer is running;
   this transport prevents overlap entering a combined history, not simultaneous offline starts.
5. Optional SHA-256 sidecars detect incomplete/mismatched delivery. They do not authenticate a writer.
   Wait and retry when JSON/checksum deliveries disagree. Missing/offline files never mean deletion.

Apple's iCloud for Windows supports marking a folder Always keep on this device. Enable iCloud Drive
on both devices under the same Apple Account, then pin the dedicated transfer folder on Windows.
Cloud delivery speed, offline placeholders and re-signing access still require actual device tests.
Folder write success is not proof the other device has received or imported the record.

## Acceptance checklist

- Save/read a short Start/Pause/Resume sequence with a real break excluded; reopen and compare totals.
- Resize, maximize, large timer text, optional pin, monitor disconnect and Windows display scaling.
- Lock/sleep/minimize/X while running; reopen/unlock paused and manually Resume. Test clock changes.
- Use disposable data to verify crash recovery and save failures without resetting the live store.
- On both devices import the same file twice, a stale file and overlapping times; totals never double.
- Confirm earlier phone data and imported provenance survive Study/full backup and restore.
- Time new-file and changed-file delivery in both directions, with iCloud/provider open and closed,
  offline/reconnected, after permission revocation/re-linking and same-ID phone re-signing.
- Keep SideStore/signing acceptance separate. No signing ownership changes come from file transfer.

## Build and checks

CI uses SDK 10.0.402 from `global.json`: Linux runs core persistence/clock/exchange assertions, Windows
compiles WPF, renders only synthetic native states and publishes the portable ZIP and checksum.
Shared JSON fixtures in `tests/fixtures/` are read by the Windows and Swift domain tests. The iOS
CI Gate independently checks persistence/backup and app compilation. No local full build is required.
