# ReelVault

A personal, local-only video module of AkshatOS: pick videos you own, add a headline to each, and
browse a vertical reel. WHOOP remains a separate app. No store release, backend, or account.

**Status:** The first iPhone version is implemented in AkshatOS working source 0.9.0 (32) and
cloud-tested and locally validated; it is installed with current-version automatic-refresh
enrollment, and its phone pass is pending. Working source 0.10.0 (33) adds library stills, a
video screen and delete from the feed (not yet built or phone-tested). The Android scaffold below
remains unverified. It lives in the AkshatOS repository's `reelvault/` folder; the former private
`reels` repository keeps the earlier history.

## What the first iPhone version does

- **Adding videos:** from Photos (the system picker, which needs no photo permission) or from Files,
  up to ten at a time from Photos. Each video is copied into AkshatOS, so the original can be moved
  or deleted afterwards. A file that is not a playable video, or a video already in the library
  (recognised by its contents, not its name), is refused with a message and leaves nothing behind.
- **The feed:** one video a page, swiped vertically, full width with the picture fitted. The video
  on screen loops until you swipe; tap it to pause or resume. Only the video on screen plays and
  makes sound, and it plays its sound even with the ring switch on silent (volume buttons apply).
  It pauses when the app is not in front.
- **The order:** a shuffle bag. Every video plays once before any plays again, and the last video of
  one round is never the first of the next, so nothing shows twice in a row unless it is the only
  video. A video added during a round joins that round; one removed drops out.
- **Headlines:** shown over the top of the video. Tap it to write or edit it; it is one line of up
  to 140 characters. The video screen edits them too.
- **Delete:** a trash button at the top right of every video in the feed deletes it after asking
  (naming its headline), with playback held while asking; the next video takes its place.
  Deleting removes only the app's copy, never the original. (From 0.10.0 (33).)
- **Library:** every video with a still from it, its headline, length, size and date. Tapping one
  opens its video screen: the video plays, looping, with tap to pause, so you can see what it is
  while typing its headline (saved on Done or on leaving), and Delete video asks before deleting.
  Swiping left on a row also deletes after asking. (Stills and the video screen from 0.10.0 (33);
  before that a row showed only text and tapping it opened a headline box.)
- **Backup:** Export backup writes a folder with every video and `reelvault.json`; Restore backup
  adds the videos that are missing and gives videos already here the backup's headline, after
  checking every file against its size and checksum, so a damaged backup restores nothing. The hub's
  Backup screen includes ReelVault in Back up everything.
- **Local only:** nothing leaves the phone. No downloader, account, analytics or social feed.
- **Not built, on purpose:** favorites, a manual reshuffle button, a mute toggle, auto-advance,
  and remembering the position inside a video.

## iPhone plan

See [iphone-plan.md](iphone-plan.md) for native SwiftUI/AVFoundation, proposed Photos/Files
copy-on-import, headline/shuffle/playback behavior, export/restore, cloud builds, and device gates.
Windows signs and refreshes the hub's cached unsigned Release IPA with Sideloadly; ReelVault has no
separate IPA or installed bundle identity. Media stays local; this is deployment coordination, not cloud media synchronization.

The selected model uses two slots: native hub plus WHOOP, leaving one slot unallocated. No paid
membership or rotation is required. See `../hub-plan.md` for the source/build-owner and
identity contract; `../` owns the hub build.

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
