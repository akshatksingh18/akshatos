# ReelVault iPhone plan

**State:** ReelVault is a feature module of the AkshatOS hub; WHOOP stays standalone. Its first
version shipped in AkshatOS 0.9.0 (32), passed cloud CI/artifact validation and is installed
with current-version automatic-refresh enrollment; its phone pass is pending;
`README.md` says what it does and `architecture.md` how. Where the first version differs from the
proposals below, the difference is listed under "First version versus this plan". The existing
Android scaffold is unverified. This plan is not authorization to change build identities, enroll in
paid signing, or remove installed apps.

## First version versus this plan

- Built as planned: copy-on-import from Photos and Files as files (never one large in-memory
  value), a streamed fingerprint with duplicate detection, a playability check before a video
  enters the library, staging then promotion with interrupted copies cleaned at launch, a versioned
  SwiftData record per video, stable ids in the shuffle queue, at most three live players with only
  the visible one playing, looping, tap to pause, headline editing, removal of the app's copy only,
  and a full backup validated by size and checksum.
- Different: the proposed "explain duplicated storage before importing large videos" is a line in
  the empty state and the library, not a prompt per import. Import shows a spinner, with no
  percentage or cancel. The backup is a plain folder restored by adding and updating, not an archive
  with conflict prompts. The audio session is `.playback`, so sound plays with the ring switch on
  silent; that choice is open to change after the phone pass.
- Not done: the physical feasibility run in step 3 below, a low-storage or cloud-only-source test,
  and the device-backup exclusion decision. `todo.md` lists them.

## Product scope

Bring the existing personal reel concept to iPhone, retaining the accepted behavior:

- Import videos Akshat already owns, add/edit a headline, and browse a vertical full-screen feed.
- Keep a separate library for adding, editing, and removing entries. Use a restrained native UI
  with readable headline overlays and accessible controls; visual styling can be refined at build time.
- Use a Fisher-Yates shuffle bag: each eligible video appears once per cycle, with no immediate
  cross-cycle repeat when at least two videos exist. A one-video library necessarily repeats;
  an empty library presents an import prompt. Specify/test additions and deletions mid-cycle.
- Loop the current video until a swipe; tap the video to pause/resume. Only the visible video
  plays audio. Headline edits commit on Done or leaving the item and survive relaunch.
- Keep media and metadata local after import. No account, backend, analytics, advertising,
  social feed, Instagram/TikTok downloader, or mandatory media-sync service.
- Preserve prior cuts: favorites, manual reshuffle, and a mute toggle are not planned unless
  requested. Auto-advance and per-video playback-position resume remain optional later work
  (library stills arrived in 0.10.0 (33) at Akshat's request), not requirements silently added to the iPhone MVP.
- Add versioned export/restore as a daily-driver gate because app-private media is lost on uninstall.

## Accepted two-app packaging

`../hub-plan.md` owns the accepted package boundary: one native hub for Squats, PDFs, and
Reels plus standalone WHOOP. Two installed apps fit the free three-app allowance; the third slot is
unallocated. Free seven-day signing still requires refresh. No paid membership, rotation, guest-app
container, or Flutter embedding is needed.

ReelVault has no standalone install identity or separate iOS IPA in this plan. Settle the shared
hub repository/source layout and permanent bundle identity before implementation. This folder
continues to own ReelVault's product details and Android fallback until that explicit reconciliation.
Do not confuse shared deployment with cloud media sync.

## Proposed native implementation

Use SwiftUI plus AVFoundation/AVKit, initially targeting iOS 17+ to align with the Squat Reminder
smoke pipeline. Confirm the actual phone/SDK before scaffolding. Integrate iOS source as a module
in the selected hub source tree; do not create an independent iOS entry point here. Leave Android
source/configuration unchanged until any separately approved source consolidation.

- One common hub application target: ReelVault adds no widget, Watch app, App Group, push, iCloud
  entitlement, share extension, injected library, JIT, or background playback mode. Squats owns the
  hub's notification/geofence services; video navigation must not disable or delay those services.
- A bounded AVPlayer pool: current item and at most its immediate neighbors; start conservatively
  with fewer if memory testing warrants it. Release detached players and observers. Pause when
  backgrounded, interrupted, or editing; verify silent switch/audio-route behavior explicitly.
- Maintain play order as stable video IDs, resolving current metadata from the store so queued
  headlines cannot become stale. Handle deletion of the current/queued video deterministically.
- A versioned local SwiftData store is the proposed metadata layer; SQLite/Core Data is an
  acceptable fallback after the spike. Records need UUID, internal filename, headline, import time,
  validated media metadata, and a streamed content fingerprint. No whole-video database blobs.

### Import and storage proposal

Unlike Android's SAF-reference approach, the proposed iPhone default is **copy on import** for
reliable offline playback. Explain duplicated storage before importing large videos.

1. Offer system Photos selection filtered to videos and a Files importer for owned video files.
   Prefer selected-item picker access; do not request the whole photo library unnecessarily.
2. Transfer as files (for example `Transferable`/`FileRepresentation`), not one giant `Data` buffer.
   Copy temporary picker files while available; balance security-scoped Files access when required.
3. Stage a bounded file copy in app-private storage. Show loading/progress where available, cancel,
   and retry. A cloud-only Photos/Files item must finish downloading before it is marked ready.
4. Validate AVFoundation readability and compute the fingerprint off the UI thread. Detect duplicate
   content and show a clear result rather than silently multiplying storage.
5. Promote the completed file into Application Support and commit metadata with a recovery strategy
   for interrupted file/database operations. Clean partial files at launch. Never create a playable
   library entry for an incomplete import.

After a successful copy, moving/deleting the source must not break playback. “Remove from library”
deletes only the app-owned copy and metadata after confirmation, never the Photos/Files original.
Test insufficient storage, cancellation, corruption, unsupported codec, slow provider download,
and termination during import. Do not promise every container/codec is playable or add a transcoder
without evidence that the actual library needs one.

### Recovery proposal

Provide a versioned export manifest containing IDs, filenames, headlines, schema version, and
checksums; a full export also includes the videos. A metadata-only export is not a media backup.
Use the system exporter to put a recoverable copy outside the app container, with no required server.
Restore must validate paths/schema/hashes, handle conflicts with confirmation, and avoid loading a
whole archive into RAM. Test with a disposable library before touching real data.

Choose the automatic device/cloud backup exclusion policy before daily use; if large private copies
are excluded, clearly direct the user to full export. Do not claim Sideloadly or Git backs up media.
Before rotation, reinstall, team change, or migration, verify off-device media plus metadata recovery.
Ordinary expiry is repaired with same-account/team, same-bundle overwrite, not uninstall.

## Shared cloud-build and Sideloadly plan

Use the single native-hub pipeline in `../hub-plan.md`: currently public GitHub macOS/Xcode compilation,
standard unsigned Release IPA with source/version/capability/SHA-256 metadata, and Windows
Sideloadly signing. Do not create a ReelVault-specific workflow or reserve a standalone bundle ID.
The previous standalone candidate is not an active installation identity.

ReelVault now lives in the AkshatOS repository's `reelvault/` folder (currently public); the hub
repository is the source/build owner, and the Android fallback is preserved here. GitHub contains
source/docs only, never videos, exports, Apple credentials,
profiles, device identifiers, or IPAs committed to Git.

Keep the accepted hub IPA and one pending candidate outside Git using the shared backup/testing cache. Refresh the same cached binary without a
source rebuild, using the same Apple Account/team and hub identity. Follow daily/48-hour checks,
three-day refresh buffer, two-day escalation, final-day USB recovery, and two-cycle validation.
One hub refresh updates every module; confirm videos/headlines, PDFs/progress, and squat
state/actions survive. Neither Sideloadly nor Git is a backup of the user library.

The hub's permanent identity is selected and installed. Build 31 is the accepted recovery IPA;
Build 32 includes ReelVault and is installed pending its phone pass. `../cloud-build.md` owns the
artifact evidence and `../../final-ipas/README.md` the one-slot backup/testing cache model.
The old standalone Squat Reminder smoke IPA is historical and must never be relabeled as the hub.

## Implementation sequence and acceptance

1. **Lock the hub transition:** the display name is **AkshatOS** per `../hub-plan.md`;
   use `../` as common source/build owner and its selected permanent bundle identity. Packaging is already chosen;
   no fourth-slot or paid-membership decision is required.
2. **Activate hub scaffold:** private build, module boundaries, ordinary hub icon/screen, artifact
   metadata, and successful phone launch. Retain the old standalone Squat download as smoke only.

3. **Prove media feasibility:** import/play small and large actual-library samples, H.264/HEVC where
   applicable, portrait/landscape, cloud-only sources, airplane mode after import, rapid swipes,
   lock/background/interruption, and memory/storage pressure. Keep test media outside Git.
4. **Implement the daily loop:** library/import/remove, headline editing, persistent metadata,
   shuffle invariants, bounded players, pause/resume, graceful errors, and accessible UI. Add unit
   tests for shuffle (zero/one/many items and mutations), metadata updates, and import recovery.
5. **Protect and deploy:** full export/clean restore, same-hub-IPA refresh, schema upgrade, controlled
   expiry repair, and coexistence with standalone WHOOP. Verify two refresh cycles plus failed-refresh/USB
   recovery before calling it dependable. Test migration only with disposable data first.

## References

Policy/pricing checked 2026-09-03; re-check before deployment or spending. API choices above are
proposals to validate against the actual SDK/device, not claims of implemented behavior.

- [Apple Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account/).
- [Apple Developer Program enrollment/pricing](https://developer.apple.com/programs/enroll/).
- [Sideloadly signing, refresh, limits, and overwrite FAQ](https://sideloadly.io/faq.html).
- [Apple Photos picker: selected media and file-backed transfers](https://developer.apple.com/videos/play/wwdc2022/10023/).
- [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer).

Keep this plan synchronized with `CLAUDE.md`, `README.md`, `architecture.md`, `todo.md`, and
`../../CLAUDE.md`; mark each phase implemented/verified only after its evidence exists.
