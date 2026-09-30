# TODO / known gaps

The iPhone plan is primary; iOS implementation is not activated. Android remains an unverified
fallback. `iphone-plan.md` owns the proposed implementation and physical acceptance details.

## iPhone activation and delivery gates

- [x] Shared hub source/build owner and identity selected in `../hub-plan.md`: `../`.
      ReelVault implementation is still deferred; Squats comes first and WHOOP stays separate.
- [x] Consolidated into the AkshatOS repository's `reelvault/` folder (the former private `reels`
      repository keeps the earlier history); the Android source is preserved here.
- [ ] On activation, integrate ReelVault as a native module under `../ios/AkshatOS/features/`
      rather than a standalone target, with media and signing exclusions checked first.
- [ ] Build/download/checksum the common hub Release IPA and pass its manual Sideloadly USB open test.

- [ ] Prove file-based Photos/Files import and AVFoundation playback with actual large-video,
      offline, memory, interruption, corrupt-media, and low-storage tests.
- [ ] Implement the accepted library/headline/shuffle/loop/pause flow and versioned local storage;
      test zero/one/many-video shuffle and additions/deletions/headline updates mid-cycle.
- [ ] Implement full media+metadata export and clean-install restore before daily use/rotation, and
      join the hub's full backup with a `HubBackupPart` (`../hub-plan.md` § Full backup); CI blocks
      the module until it does.
- [ ] Verify same-ID refresh, upgrade/migration, expiry repair, approved portfolio coexistence,
      two refresh cycles, alerts, USB recovery, and retained video/headline data.

## Android fallback gaps (deferred)

Rough order to evaluate if Android is activated:

- [ ] **Clean build and core-behavior verification.** Add a Gradle wrapper, build from a clean
      checkout, then verify the no-repeat shuffle invariant and basic add/edit/delete/playback
      flow before trusting the scaffold.

- [ ] **Headline edits may not refresh queued videos.** The database-backed collection can
      receive a new `Video` value while the shuffle queue still holds an older object. Verify
      queued/current UI state after an edit and rebuild or remap the play order if necessary.

- [ ] **Persisted URI permission failure is swallowed.** Do not store a URI as durable when
      `takePersistableUriPermission()` fails. Surface the failure or reject that import.

- [ ] **Resume position per video.** Currently every video restarts at
      0:00 when you swipe back to it. Fix would be a small in-memory
      `Map<videoId, positionMs>` in `MainViewModel`, read/written from
      `VideoPage.kt`'s player listener. Doesn't need to survive app
      restart, just the current session.

- [ ] **Thumbnails in the library list.** `LibraryScreen.kt` currently
      shows only the headline text field per row — no visual reference
      for which video is which. `ContentResolver.loadThumbnail()` (API
      29+) or a Coil `AsyncImage` pointed at the video URI would cover
      it. Minor complexity: needs a fallback for API 26-28 devices below
      `loadThumbnail`'s floor (current `minSdk` is 26).

- [ ] **Dead-URI cleanup.** If the original video is deleted/moved from
      wherever it lived (gallery, downloads, etc.), the stored `content://`
      URI just fails silently on playback. No detection or auto-removal
      exists yet. Could catch the `ExoPlayer` error listener in
      `VideoPage.kt` and prompt to remove the entry.

- [ ] **Advance to next video on playback completion**, instead of
      looping forever (`Player.REPEAT_MODE_ONE` in `VideoPage.kt`). This
      was a deliberate choice, not an oversight — flip it if you decide
      you'd rather have videos auto-advance like a real feed. Would need
      a `Player.Listener` calling back up to `ReelScreen.kt` to trigger
      `pagerState.animateScrollToPage(...)`.

- [ ] **Undo on delete.** `LibraryScreen.kt`'s delete button is
      immediate/irreversible. A `Snackbar` with an undo action (hold the
      deleted `Video` for a few seconds before actually calling
      `dao.delete`) would be a cheap safety net.

Not planned unless you ask for them (were explicitly cut during design):
favorites, manual reshuffle button, mute toggle.
