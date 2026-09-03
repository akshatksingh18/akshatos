# TODO / known gaps

This is current-state work, not a claim that either platform is already usable. The iPhone path is
primary; Android remains a separate fallback scaffold.

## iPhone-primary work

- [ ] **Choose activation inputs.** Confirm the permanent unique bundle ID, Apple Account/team,
      compatible Mac/Xcode build path, Windows IPA-cache/backup locations, and refresh-alert method.
- [ ] **Create the separate SwiftUI target.** Keep the Android module intact and add one minimal iOS
      application target with no extensions or unnecessary entitlements.
- [ ] **Implement permission/status UI.** Cover not-determined, authorized, denied, later-revoked,
      Focus/Summary caveats, and the Settings route without displaying a false Running state.
- [ ] **Implement one repeating request.** Validate whole minutes (minimum one), use one stable
      request ID, make Start idempotent, and make Stop cancel the request and stored intent.
- [ ] **Implement foreground reconciliation.** Compare `UserDefaults`, actual notification settings,
      and pending requests on launch/foreground return; expose missing/stale request repair.
- [ ] **Add logic tests.** Cover interval validation, state reconciliation, duplicate Start, Stop,
      permission transitions, and request replacement. Simulator tests do not replace hardware tests.
- [ ] **Run the physical-iPhone matrix.** Permission allow/deny/revoke, one-minute test interval,
      foreground/background, explicit force-quit, reboot, Low Power Mode, Focus, Scheduled Summary,
      external notification-setting changes, and Stop near a delivery boundary.
- [ ] **Produce a portable release IPA.** Build on Mac/Xcode, inspect minimal capabilities, record
      version/source/hash, and cache current plus previous known-good artifacts on Windows.
- [ ] **Prove refresh and recovery.** Install with Sideloadly/Local Anisette, verify same-bundle Wi-Fi
      and USB refresh preserves state/reconciliation, exercise early alerts and expired-profile
      recovery, and pass multiple cycles without uninstalling.

## Current Android fallback gaps

- [ ] **Never built or run.** Add a Gradle wrapper, complete a clean build, and run on the fallback
      Android phone before trusting any intended behavior.
- [ ] **Running UI ignores actual delivery capability.** It reads `isRunning` without reconciling
      `POST_NOTIFICATIONS` or exact-alarm access; surface a blocked/warning state.
- [ ] **Input validation is silent.** Blank or zero input currently falls back/clamps without a
      visible error; add explicit validation feedback.
- [ ] **No verified launcher icon.** Add a proper `ic_launcher` resource if the scaffold lacks one.
- [ ] **Reboot and OEM behavior unverified.** Test exact-alarm re-arm after reboot and battery-policy
      behavior on the actual fallback device; document any required settings honestly.

## Optional ideas (not committed scope)

- Snooze/skip-one action.
- Pause/resume within a day.
- Reminder history, multiple profiles/schedules, or a widget remain out of scope unless Akshat
  explicitly expands the one-purpose product.

## Documentation synchronization

When an item changes product/platform behavior or becomes implemented/verified, update
`README.md`, `architecture.md`, and `CLAUDE.md` in the same change; remove or rewrite the item rather
than appending a dated progress log.
