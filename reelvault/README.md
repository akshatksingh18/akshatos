# ReelVault

A personal, local-only video app: pick owned videos, add a headline to each, and browse a vertical
reel. ReelVault is planned as a module in one native iPhone hub with Squat Reminder and PageVault;
WHOOP remains a separate app. The two apps use the shared Sideloadly workflow. No store release, backend, or account is planned.

**Status:** iPhone plan only; no iOS source, workflow, or IPA exists. The Android scaffold below
remains unverified. It lives in the AkshatOS repository's `reelvault/` folder; the former private
`reels` repository keeps the earlier history.

## iPhone plan

See [iphone-plan.md](iphone-plan.md) for native SwiftUI/AVFoundation, proposed Photos/Files
copy-on-import, headline/shuffle/playback behavior, export/restore, cloud builds, and device gates.
Windows will sign/refresh the shared hub's cached unsigned Release IPA with Sideloadly, following
Squat Reminder's pipeline pattern; ReelVault gets no separate IPA or installed bundle identity. Media stays local; this is deployment coordination, not cloud media synchronization.

The selected model uses two slots: native hub plus WHOOP, leaving one slot unallocated. No paid
membership or rotation is required. See `../hub-plan.md` for the source/build-owner and
identity contract; `../` owns the hub build. ReelVault implementation remains deferred.

## Android fallback setup (not the iPhone path)

1. Open this folder in Android Studio (`File -> Open`).
2. Let Gradle sync. Validate the scaffold's dependency compatibility before upgrading;
   an IDE upgrade banner is not proof that a new toolchain works.
3. Run on your phone:
   - Enable Developer Options + USB debugging on the phone.
   - Plug in via USB, select "Allow" on the RSA prompt.
   - Hit Run in Android Studio, pick your device.
4. A Gradle wrapper is not stored yet. Add and commit it when the project is
   activated before relying on `./gradlew assembleDebug` outside Android Studio.

## Android scaffold behavior (unverified)

- **Adding videos**: the library screen (tap the video-library icon top
  right of the reel) opens Android's system file picker (Storage Access
  Framework) filtered to `video/*`. Nothing is copied - the app stores a
  reference (URI) to the file plus a persisted read permission, so it can
  keep playing the file from wherever it lives in your gallery/storage.
- **Shuffle**: a Fisher-Yates "shuffle bag" (`shuffle/ShuffleBag.kt`).
  Every video plays exactly once before any repeat, and the boundary
  between one shuffled cycle and the next is checked so you never get the
  same video twice in a row. This is deliberately not a per-swipe random
  pick - true per-pick randomness is what causes the "same video keeps
  showing up" feeling.
- **Headline**: tap the text at the top of a video to edit it in place.
  Commits on the keyboard's Done button or when you swipe away. Same
  editable field is available in the library list for bulk editing.
- **Playback**: only the current page and its immediate neighbors get a
  live ExoPlayer instance (see `isActive` in `ReelScreen.kt` /
  `VideoPage.kt`) so scrolling through a big library doesn't spin up a
  pile of players at once. Each video loops on repeat until you swipe.
  Tap anywhere on a video to pause/resume.

## Android limitations / possible later additions

- No resume position: swiping away and back to a video restarts it from
  0:00 rather than remembering where you paused.
- No thumbnails in the library list - just the headline text field. Room
  for a `Coil` + `ContentResolver.loadThumbnail()` addition if you want
  visual browsing there.
- Import is one-way: if you delete the original video from your gallery,
  the app will just fail to play that entry rather than auto-cleaning it up.
