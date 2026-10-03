# TODO / known gaps

The first iPhone version is implemented in AkshatOS working source 0.9.0 (32) and passes nothing
on a phone yet. Android remains an unverified fallback. `iphone-plan.md` owns the plan and the
physical acceptance details; `README.md` says what the first version does.

## iPhone gates

- [x] Shared hub source/build owner and identity selected in `../hub-plan.md`: `../`.
- [x] Consolidated into the AkshatOS repository's `reelvault/` folder (the former private `reels`
      repository keeps the earlier history); the Android source is preserved here.
- [x] Integrated as a native module under `../ios/AkshatOS/features/reelvault/`, not a standalone
      target, with its own versioned store and file folder.
- [x] The library, headline, shuffle, loop and pause flow with versioned local storage, with
      zero/one/many-video shuffle and additions/deletions mid-round covered by tests.
- [x] Full media-and-headline backup and restore, and the hub's full backup through a
      `HubBackupPart` (`../hub-plan.md` § Full backup).
- [x] Pass the cloud build: Build 32 passed PR and main CI and artifact validation.
- [ ] Phone-check installed and enrolled Build 32 using `../todo.md`:
      Photos and Files import with small and large real videos, playback, sound, the silent switch,
      offline use, interruption, memory and stutter under fast swipes.
- [ ] Import feedback for large videos: a copy shows only a spinner, with no percentage or cancel.
- [ ] A cloud-only Photos or Files video that has to download first, corrupt media, an unsupported
      codec and low storage are handled by refusing the import with a message, but only the
      corrupt-file and duplicate paths are tested; try the rest on the phone.
- [ ] Decide whether the video copies stay in the phone's own device backup (they do now, like
      PageVault's PDFs) once the library's real size is known.
- [ ] A clean-install restore, which means uninstalling and is Akshat's call; it comes for free with
      the Apple Account switch.
- [ ] Verify same-ID refresh, upgrade/migration, expiry repair, two refresh cycles and retained
      video/headline data.

Not built, by the accepted scope: favorites, a manual reshuffle button, a mute toggle, auto-advance
when a video ends, remembering the position inside a video, and thumbnails in the library.

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
