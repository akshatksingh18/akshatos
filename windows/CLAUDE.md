# Study Desk for Windows

Native WPF companion to AkshatOS Study Log. Read the parent instructions first.

**Status:** First portable 0.1.0 candidate passes cloud checks and native finish review; physical
Windows/iPhone/provider acceptance remains open. `../cloud-build.md` owns exact artifact evidence.

## Files

- `global.json` — pinned .NET SDK used by CI; no SDK installation is required on this laptop.
- `core/` — platform-independent timestamp clock, atomic local records and versioned exchange.
- `app/` — native draggable/resizable WPF timer, lock/sleep/close handling and explicit Files transfer.
- `tests/` — synthetic domain/recovery/exchange regressions, run in Linux CI.
- `README.md` — operation, data location, transfer limits and device test checklist.
- `../.github/workflows/windows-study.yml` — Linux checks and Windows portable build/native renders.

## Working agreement

- Remaining time is primary, studied time below. The implemented styling is graphite/copper; the
  accepted but unbuilt direction is Tungsten with a violet accent (`../look-and-feel.md`). Either
  way, keep native Windows controls.
- The window must snap like any other app, including the Snap Layouts hover grid, so it can live on
  half the screen beside other work. Snapping is not minimising, so a snapped window keeps running.
  The accepted chrome is a tinted caption with real minimise/maximise/close buttons, never frameless;
  `../desktop-study-plan.md` owns the requirement and the hit-testing it needs.
- Lock, sleep, minimize and close pause; resuming is manual. No hidden running/tray timer.
- Save local state before reporting success. Keep records outside the executable directory.
- Never merge overlapping intervals or silently replace another device's history. Exchange is
  finished-session import, not backup restore or a distributed lock.
- Only synthetic fixtures/captures enter Git/CI; do not run against private/cloud folders as an agent.
- Full builds/tests run in GitHub Actions. Do not install runtimes or run a heavy build locally.
- Whenever a new working file or routed subfolder is added, index it here in the same change.
