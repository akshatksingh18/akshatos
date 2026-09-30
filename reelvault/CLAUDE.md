# ReelVault

Personal, local-only ReelVault feature for the planned native iPhone hub: select owned videos,
add a headline to each, and browse them as a vertical reel alongside Squats and PageVault. The existing Kotlin/Compose Android scaffold is preserved
as an unverified fallback. Personal sideloading only: no backend, analytics, account, or store release.

**Status:** iPhone planning — no iOS source, cloud workflow, IPA, or device verification exists.
Android remains an unverified scaffold. Moves to iOS Scaffold only when Akshat activates the
shared hub cloud-build/install spike; daily use additionally requires media/recovery and signing gates.

## Files

- `README.md` — intended user behavior and activation/setup instructions.
- `iphone-plan.md` — iPhone feature plan, shared portfolio capacity gate, proposed media/storage
  design, private cloud-build/Sideloadly workflow, and physical-device acceptance phases.
- `architecture.md` — stack, source layout, and non-obvious design decisions; read before changing
  playback, shuffle, persistence, or UI structure.
- `todo.md` — current known gaps and implementation risks; update in place as gaps are resolved or
  priorities change.
- `build.gradle.kts` — root Android build configuration and plugin versions.
- `settings.gradle.kts` — Gradle project and repository configuration.
- `gradle.properties` — project-wide Gradle and Android settings.
- `app/` — Android application module, manifest, resources, and Kotlin source.

## Working agreement

- Treat the iPhone plan and Android scaffold separately; neither is verified. Do not port Android
  URI permissions or ExoPlayer APIs directly into the native iOS design.
- Read `iphone-plan.md`, `../../CLAUDE.md`, and `../hub-plan.md` before iPhone work. ReelVault,
  PageVault, and Squat Reminder are selected as three modules in one native hub; WHOOP stays separate.
  This uses two app slots. No standalone ReelVault target/identity is planned. The hub source/build
  owner and permanent identity are defined in `../hub-plan.md` and `../`; do not rename targets, buy
  membership, or remove an app as a side effect of this plan.
- This folder is part of the AkshatOS repository (currently public). It was merged in from the former
  private `reels` repository at Akshat's request after a privacy review; that repository keeps the
  earlier history. The AkshatOS `.gitignore` covers its Android build output, signing files and IPAs.
  Never commit personal videos, exports, credentials, profiles, or release IPAs.
- Preserve the local-only, single-user scope unless Akshat explicitly changes it.
- Read `architecture.md` before changing a documented invariant, and update that file in place if
  the current design changes.
- Keep actionable implementation gaps in `todo.md`; remove or rewrite an item when its current
  state changes instead of appending dated progress notes.
- Automatically synchronize affected owning sources: this file, README, architecture, iPhone plan,
  and TODO. Update the shared hub plan only for integration impacts; parent/root indexes change
  only for their own routing or shared rules, not ReelVault progress. Keep accepted scope, proposed technical
  details, implemented behavior, and physically verified results distinct.
- **Whenever a new file is added to this folder**, add a bullet for it under `## Files` above,
  in the same edit, with a one-line description of what it's for.
