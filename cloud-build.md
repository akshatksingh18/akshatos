# Squat Reminder cloud build and iPhone smoke install

**State:** The Windows-authored GitHub Actions path has passed simulator compilation, unsigned-device
compilation, packaging, metadata inspection, artifact upload, Windows download, and SHA-256
verification. The remaining activation gate is signing, installing, and opening that exact IPA on
Akshat's physical iPhone.

## What the pipeline does

The repository keeps human-readable Swift source and `ios/project.yml`. A private-repository GitHub
Actions job runs on macOS, installs the pinned XcodeGen release, generates the `.xcodeproj`, compiles
both simulator and unsigned device builds, packages the device `.app` into an IPA, records its SHA-256
and build metadata, and uploads the files as a 14-day workflow artifact.

The workflow intentionally receives no Apple Account password, two-factor code, certificate,
provisioning profile, device identifier, or Sideloadly data. GitHub compiles the ordinary app;
Sideloadly on the trusted Windows computer performs personal signing and installation later.

Current smoke-build identity:

- display name: **Squat Reminder**;
- bundle identifier: `com.akshatksingh18.squatreminder`;
- version/build: `0.1.0 (1)`;
- minimum deployment target: iOS 17.0;
- target: iPhone only;
- capabilities: none beyond an ordinary application target;
- content: a static screen proving the binary launched; reminders, persistence, streaks, location,
  and other product behavior are not implemented yet.

Keep the bundle identifier unchanged after the first successful phone installation unless Akshat
explicitly approves a migration. It is one of the permanent identities in the three-app free-signing
portfolio.

Current verified cloud artifact:

- source commit: `714ec81c6049c76b349cb198ce839b15e83b80c1`;
- successful workflow: **iOS Cloud Build #2**;
- GitHub artifact: `squat-reminder-ios-2`;
- downloaded ZIP SHA-256: `50539c3d45b093036ee1979faba704cfbe2e93dfc3bbfebd7c47c8143ce15c32`;
- unsigned IPA SHA-256: `a2b7fc4c5b78ed9276d6657a8d7c406465fab1e956fb9e00109a856f7d4759c1`.

The artifact is still a smoke candidate rather than a known-good release cache entry until the
physical open test passes.

## Download the cloud artifact

1. Open the private GitHub repository and select **Actions**.
2. Open the latest green **iOS Cloud Build** run for `main`.
3. In **Artifacts**, download `squat-reminder-ios-<run number>`.
4. Extract the downloaded ZIP. It contains:
   - `SquatReminder-unsigned.ipa`;
   - `SquatReminder-unsigned.ipa.sha256`;
   - `build-info.txt`.
5. Compare the IPA's Windows SHA-256 with the value in the `.sha256` file before installation:

   ```powershell
   Get-FileHash -Algorithm SHA256 .\SquatReminder-unsigned.ipa
   Get-Content .\SquatReminder-unsigned.ipa.sha256
   ```

The hexadecimal values must match. The filename says `unsigned` deliberately: never treat the
GitHub artifact as containing personal signing material.

## First Sideloadly installation

1. On the iPhone, enable Developer Mode under **Settings → Privacy & Security → Developer Mode** if
   it is not already enabled.
2. Connect the iPhone to Windows over USB for the first proof and accept the computer trust prompt.
3. Open Sideloadly, select the connected iPhone, and choose `SquatReminder-unsigned.ipa`.
4. Use the same Apple Account intended for the three-app portfolio. Keep the custom bundle ID fixed
   at `com.akshatksingh18.squatreminder`; do not let retries invent a new identity.
5. Start the sideload and complete Apple's authentication/verification prompts locally. Never put
   those credentials or codes in GitHub, project files, screenshots, or chat.
6. If iOS asks for trust, open **Settings → General → VPN & Device Management**, select the personal
   developer entry, and trust it.
7. Open **Squat Reminder**. Success means the placeholder icon is visible and the app opens to
   **Cloud build installed successfully — Smoke build 0.1.0 (1)** without immediately closing.

For this first proof, use USB rather than Wi-Fi refresh. Do not uninstall on later builds; overwrite
using the same Apple Account and bundle ID so preservation behavior can be tested.

## Failure handoff

- Red GitHub run: preserve the failing step and log; fix the build rather than weakening validation.
- Missing artifact: the build is not successful even if earlier compile output is green.
- Hash mismatch: do not install; download the artifact again.
- Sideloadly signing/install error: preserve the exact non-secret error text and the relevant log
  section. Do not paste an Apple password, two-factor code, session data, or provisioning material.
- App installs but closes on launch: keep it installed and capture the visible behavior/device iOS
  version. Do not change the bundle ID or delete local state as the first troubleshooting step.

The physical open test is the gate. A green cloud build proves compilation and packaging only.
