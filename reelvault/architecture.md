# ReelVault Architecture

**State:** The first iPhone version shipped in AkshatOS 0.9.0 (32), passed cloud CI and local
artifact validation, and is installed with current-version automatic-refresh enrollment. Its
physical-device pass is pending. Android source is an unverified fallback.

## iPhone implementation

Source: `../ios/AkshatOS/features/reelvault/`.

- `domain/ReelVault.swift` (Foundation-only): `ReelVideo` (id, the app copy's file name, headline,
  import date, duration, size, SHA-256 fingerprint); headline and file-name rules; whole-library
  validation; `ReelShuffleBag`; the backup manifest; and `ReelRestorePlan`, which recognises a video
  by fingerprint so a restore adds what is missing and only updates headlines on what is here.
- `ReelShuffleBag` keeps a queue of ids, the ids already played this round, and the last one shown.
  Each call takes the library's current ids: removed ids drop out, an id neither queued nor played
  is inserted at a random place in the round, an empty queue starts a new shuffled round, and a
  first entry equal to the last one shown is swapped away. The generator is injected, so tests use a
  seeded one.
- `data/`: `ReelVaultSchemaV1` holds one row per video with a JSON payload, in its own `ReelVault`
  store. `ReelVaultStorage` streams a picked file into `Incoming/` in one-megabyte chunks while
  hashing it, promotes a checked copy into `Media/<uuid>.<ext>`, clears abandoned staging at load,
  and stages a backup folder in `Outgoing/` (kept out of device backup). The media copies
  themselves stay in the phone's device backup, like PageVault's PDFs.
- `services/ReelVideoInspector.swift` asks AVFoundation whether the copy is playable, has a video
  track and has a finite length. It sits behind a protocol so storage tests can use a stand-in.
- `ReelVaultStore.swift` (main actor): imports run one after another, so two copies of one video
  cannot both pass the duplicate check; a video is published only after its copy is promoted and
  its record saved, and a failed save removes the copy. Restore stages and verifies every added file
  before the library changes, and rolls back anything it added if a later step fails.
  `ReelVaultBackupPart.swift` is its `HubBackupPart`.
- `ui/`: `ReelFeedView` is a vertically paging scroll view of feed pages, each one appearance of a
  video with its own id, extended from the shuffle two pages ahead. `ReelPlayerPool` gives the page
  on screen and its two neighbours an `AVQueuePlayer` with an `AVPlayerLooper`, releases the rest,
  and plays only the page on screen (unmuted); neighbours wait muted at their first frame.
  `ReelPlayerLayer` shows an `AVPlayerLayer` with no system controls. Playback stops while paused,
  while the headline is being edited, and while the scene is not active. The pool sets the audio
  session to `.playback`/`.moviePlayback` on appear and deactivates it on leaving. No delegate is
  used anywhere in the module.

## Earlier iPhone plan notes

`iphone-plan.md` owns the proposed SwiftUI/AVFoundation/AVKit stack, file-backed Photos/Files
copy-on-import, app-private media, versioned local metadata, export/restore, and device gates.
Use stable IDs in the shuffle queue and at most three live players, with only the visible item
playing. Do not transfer Android SAF URI semantics or ExoPlayer APIs to iOS. The shared product
scope retains looping, tap pause/resume, editable headlines, and no-repeat shuffle; optional
thumbnails/resume/auto-advance and previously cut features remain outside the required MVP.

The hub's currently public GitHub macOS job produces a conventional unsigned Release IPA,
then Windows Sideloadly signs/refreshes the shared native hub. Pushup Reminder, PageVault, Lift Log,
Body and ReelVault share one SwiftUI app, with WHOOP standalone: two installed apps. ReelVault's
iOS implementation and its preserved Android fallback live in the AkshatOS repository. The canonical
hub source/build owner is `../`; do not create a competing standalone target. Shared
identity, lazy module loading, data separation, and update/recovery rules are in `../hub-plan.md`.

Keep platform, import ownership, persistence, recovery, and deployment changes synchronized with
`CLAUDE.md`, `iphone-plan.md`, README, and TODO. Confirm proposed technical choices at the spike.

## Android fallback stack

- Kotlin 2.2.20 and Jetpack Compose with Material3
- Media3 / ExoPlayer 1.11.0 for playback
- Room 2.8.4 using `kapt`
- AGP 9.2.1, compileSdk/targetSdk 36, minSdk 26
- No navigation-compose; `MainActivity` uses one Boolean to switch between the two screens

The versions above are scaffold selections, not verified build results. Re-check compatibility
when the project is activated. Room 3 drops `kapt`, so moving beyond Room 2.x requires an explicit
KSP migration.

## Android source layout

```text
app/src/main/java/com/akshat/reelvault/
├── MainActivity.kt          # Compose host, toggles Reel and Library
├── MainViewModel.kt         # Bridges Room, ShuffleBag, and UI state
├── data/
│   ├── Video.kt             # Room entity
│   ├── VideoDao.kt          # CRUD and headline updates
│   └── AppDatabase.kt       # Room singleton
├── shuffle/
│   └── ShuffleBag.kt        # Fisher-Yates shuffle bag
└── ui/
    ├── ReelScreen.kt        # VerticalPager over the shuffled queue
    ├── VideoPage.kt         # ExoPlayer page
    ├── HeadlineOverlay.kt   # Tap-to-edit headline
    └── LibraryScreen.kt     # Picker, library, edits, and deletion
```

## Android design decisions

### Shuffle bag instead of per-swipe randomness

`ShuffleBag.next()` drains a shuffled queue and refills it with a Fisher-Yates shuffle. It also
tries to prevent the last item of one cycle from becoming the first item of the next. Preserve
the intended invariant: every video appears once before repeats, with no immediate cycle-boundary
repeat.

### At most three live players

Only the current page and its immediate neighbors should receive a live ExoPlayer. Releasing
players when pages leave that range prevents a large library from creating many simultaneous
players.

### Headline editing is activated on tap

The headline stays as static text until tapped. Keeping an always-active text field inside a
vertical pager can conflict with swipe gestures and text selection.

### Room uses kapt for the scaffold

`kapt` avoids matching a KSP release to the exact Kotlin compiler version during the initial
scaffold. The trade-off is slower incremental compilation. Revisit only if the project grows or
Room is upgraded to a KSP-only release.

### Storage Access Framework instead of copying videos

The intended import flow stores a `content://` URI plus durable read permission rather than
copying videos into app storage. A URI must not be treated as durable if persistable permission
was not successfully acquired.
