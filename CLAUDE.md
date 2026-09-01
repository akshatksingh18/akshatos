# Squat Reminder

Personal, local-only Android app scaffold with a Start/Stop control and a user-selected interval
for squat-reminder notifications. It is for personal sideloading only: no backend, analytics, or
Play Store release.

**Status:** Scaffold/prototype — never built or run. Moves to Building after a Gradle wrapper is
added and a clean build succeeds on a physical device.

## Files

- `README.md` — intended user behavior and activation/setup instructions.
- `architecture.md` — stack, source layout, alarm design, permissions, and persistence decisions;
  read before changing scheduling behavior.
- `todo.md` — current known gaps and device-verification checklist; update in place.
- `build.gradle.kts` — root Android build configuration and plugin versions.
- `settings.gradle.kts` — Gradle project and repository configuration.
- `gradle.properties` — project-wide Gradle and Android settings.
- `.gitignore` — Android/Gradle build-output and local-environment exclusions.
- `app/` — Android application module, manifest, resources, and Kotlin source.

## Working agreement

- Treat this as an unverified scaffold until it passes a clean physical-device build and run; do
  not describe intended behavior as tested behavior.
- Preserve the local-only, single-user, one-purpose scope unless Akshat explicitly changes it.
- Read `architecture.md` before changing alarm, reboot, permission, or persistence behavior, and
  update that file in place when the current design changes.
- Keep actionable implementation gaps in `todo.md`; remove or rewrite an item when its current
  state changes instead of appending dated progress notes.
- **Whenever a new file is added to this folder**, add a bullet for it under `## Files` above,
  in the same edit, with a one-line description of what it's for.
