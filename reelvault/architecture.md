# ReelVault Architecture

**State:** iPhone-first plan; no iOS implementation exists. Android source is an unverified fallback.

## Planned iPhone architecture

`iphone-plan.md` owns the proposed SwiftUI/AVFoundation/AVKit stack, file-backed Photos/Files
copy-on-import, app-private media, versioned local metadata, export/restore, and device gates.
Use stable IDs in the shuffle queue and at most three live players, with only the visible item
playing. Do not transfer Android SAF URI semantics or ExoPlayer APIs to iOS. The shared product
scope retains looping, tap pause/resume, editable headlines, and no-repeat shuffle; optional
thumbnails/resume/auto-advance and previously cut features remain outside the required MVP.

The build proposal is a private macOS cloud job producing a conventional unsigned Release IPA,
then Windows Sideloadly signing/refresh of the shared native hub, not a standalone ReelVault IPA.
The accepted model is Squats + PageVault + ReelVault in one SwiftUI application and standalone
WHOOP: two installed apps. This project lives in the AkshatOS repository but has no iOS implementation yet. The canonical
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
