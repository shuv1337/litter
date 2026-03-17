# shitter

<p align="center">
  <img src="apps/ios/Sources/Shitter/Resources/brand_logo.png" alt="shitter logo" width="180" />
</p>

`shitter` is a native iOS + Android client for Codex.

## Screenshots (iPhone 17 Pro)

| Dark (Default) | Light |
|---|---|
| ![Dark default](docs/screenshots/iphone17pro/01-dark-default.png) | ![Light mode](docs/screenshots/iphone17pro/02-light.png) |

| Accessibility XXL Text | Dark + High Contrast |
|---|---|
| ![Accessibility content size XXXL](docs/screenshots/iphone17pro/03-accessibility-xxxl.png) | ![Dark with high contrast](docs/screenshots/iphone17pro/04-dark-high-contrast.png) |

## Repository layout

- `apps/ios`: iOS app (`ShitterRemote` and `Shitter` schemes)
- `apps/android`: Android app
  - `app`: Compose UI shell, app state, server manager, SSH/auth flows
  - `core/bridge`: native bridge bootstrapping and core RPC client
  - `core/network`: discovery services (Bonjour/Tailscale/LAN probing)
  - `docs/qa-matrix.md`: Android parity QA matrix
- `shared/rust-bridge/codex-bridge`: shared Rust bridge crate
- `shared/third_party/codex`: upstream Codex submodule
- `patches/codex`: local Codex patch set
- `tools/scripts`: cross-platform helper scripts

iOS supports:

- `ShitterRemote`: remote-only mode (default scheme; no bundled on-device Rust server)
- `Shitter`: includes the on-device Rust bridge (`codex_bridge.xcframework`)

Generated iOS framework artifacts under `apps/ios/Frameworks/` are not stored in git.
Bootstrap them locally before building:

```bash
./apps/ios/scripts/download-ios-system.sh
./apps/ios/scripts/build-rust.sh
```

## Prerequisites

- Xcode.app (full install, not only CLT)
- Rust + iOS targets:

  ```bash
  rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
  ```

- `xcodegen` (for regenerating `Shitter.xcodeproj`):

  ```bash
  brew install xcodegen
  ```

## Connect Your Mac to Shitter Over SSH

Use this flow to make Codex sessions from your Mac visible in the iOS/Android app.

1) Enable SSH on the Mac.

- Preferred (UI): `System Settings` -> `General` -> `Sharing` -> enable `Remote Login`.
- CLI option:
  ```bash
  sudo systemsetup -setremotelogin on
  sudo systemsetup -getremotelogin
  ```
- If you get `setremotelogin: Turning Remote Login on or off requires Full Disk Access privileges`, grant Full Disk Access to your terminal app in:
  `System Settings` -> `Privacy & Security` -> `Full Disk Access`, then fully restart terminal and retry.

2) Verify SSH and Codex binaries from a non-interactive SSH shell.

```bash
ssh <mac-user>@<mac-host-or-ip> 'echo ok'
ssh <mac-user>@<mac-host-or-ip> 'command -v codex || command -v codex-app-server'
```

If the second command prints nothing, install Codex and/or fix shell PATH startup files (`.zprofile`, `.zshrc`, `.profile`).

3) Connect from the Shitter app.

- Keep phone and Mac on the same LAN (or same Tailnet if using Tailscale).
- In Discovery:
  - If host shows `codex running`, tap to connect directly.
  - If host shows `SSH`, tap and enter SSH credentials; Shitter will start remote server via SSH and connect.

4) Fallback: run app-server manually on Mac and add server manually in app.

```bash
codex app-server --listen ws://0.0.0.0:8390
```

Then in app choose `Add Server` and enter `<mac-ip>` + `8390`.

5) Session visibility note.

Thread/session listing is `cwd`-scoped. If expected sessions are missing, choose the same working directory used when those sessions were created.

## Codex source (submodule + patch)

This repo now vendors upstream Codex as a submodule:

- `shared/third_party/codex` -> `https://github.com/openai/codex`

On-device iOS exec hook changes are kept as a local patch:

- `patches/codex/ios-exec-hook.patch`

Sync/apply patch (idempotent):

```bash
./apps/ios/scripts/sync-codex.sh
```

This preserves the current `shared/third_party/codex` checkout by default, applies the iOS patch, and fails if the patch no longer matches that checkout cleanly.
Pass `--recorded-gitlink` if you explicitly want to reset the submodule to the commit recorded in the superproject.

## Build the Rust bridge

```bash
./apps/ios/scripts/build-rust.sh
```

By default this builds device + Apple Silicon simulator slices. Pass `--with-intel-sim` only if you need an Intel Mac simulator slice too.

This script:

1. Preserves the current `shared/third_party/codex` checkout by default, applies the iOS hook patch for the build, and restores the prior patch state afterward
2. Builds `shared/rust-bridge/codex-bridge` for device + simulator targets
3. Repackages `apps/ios/Frameworks/codex_bridge.xcframework`

## Build and run iOS app

Regenerate project if `apps/ios/project.yml` changed:

```bash
xcodegen generate --spec apps/ios/project.yml --project apps/ios/Shitter.xcodeproj
```

Open in Xcode:

```bash
open apps/ios/Shitter.xcodeproj
```

Schemes:

- `ShitterRemote` (default): no on-device Rust bridge
- `Shitter`: uses bundled `codex_bridge.xcframework`

CLI build example:

```bash
xcodebuild -project apps/ios/Shitter.xcodeproj -scheme ShitterRemote -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Build and run Android app

Prerequisites:

- Java 17
- Android SDK + build tools for API 35
- Gradle 8.x (or use `apps/android/gradlew`)

Open in Android Studio (macOS):

```bash
open -a "Android Studio" apps/android
```

Rebuild and reopen Android project:

```bash
./apps/android/scripts/rebuild-and-reopen.sh
```

Build Android flavors:

```bash
gradle -p apps/android :app:assembleOnDeviceDebug :app:assembleRemoteOnlyDebug
```

Run Android unit tests:

```bash
gradle -p apps/android :app:testOnDeviceDebugUnitTest :app:testRemoteOnlyDebugUnitTest
```

Start emulator and install on-device debug build:

```bash
ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools \
  $ANDROID_SDK_ROOT/emulator/emulator -avd shitterApi35

adb -e install -r apps/android/app/build/outputs/apk/onDevice/debug/app-onDevice-debug.apk
adb -e shell am start -n io.latitudes.shitter.android/io.latitudes.shitter.android.MainActivity
```

Build Android Rust JNI libs (optional bridge runtime step):

```bash
./tools/scripts/build-android-rust.sh
```

## TestFlight (iOS)

1) Authenticate `asc` once with your App Store Connect API key:

```bash
asc auth login \
  --name "Shitter ASC" \
  --key-id "<KEY_ID>" \
  --issuer-id "<ISSUER_ID>" \
  --private-key "$HOME/AppStore.p8" \
  --network
```

1) Bootstrap TestFlight defaults (internal group, optional review contact metadata):

```bash
APP_BUNDLE_ID=<BUNDLE_ID> \
./apps/ios/scripts/testflight-setup.sh
```

1) Build and upload to TestFlight:

```bash
APP_BUNDLE_ID=<BUNDLE_ID> \
APP_STORE_APP_ID=<APP_STORE_CONNECT_APP_ID> \
TEAM_ID=<APPLE_TEAM_ID> \
ASC_KEY_ID=<KEY_ID> \
ASC_ISSUER_ID=<ISSUER_ID> \
ASC_PRIVATE_KEY_PATH="$HOME/AppStore.p8" \
MARKETING_VERSION=1.0.0 \
./apps/ios/scripts/testflight-upload.sh
```

Notes:

- `testflight-upload.sh` auto-increments build number from the latest App Store Connect build.
- It archives, exports an IPA, uploads via `asc builds upload`, and assigns the build to `Internal Testers` by default.
- Override `SCHEME` to `ShitterRemote` if you are shipping the remote-only target.

## Important paths

- `apps/ios/project.yml`: source of truth for Xcode project/schemes
- `shared/rust-bridge/codex-bridge/`: Rust staticlib wrapper exposing `codex_start_server`/`codex_stop_server`
- `shared/third_party/codex/`: upstream Codex source (submodule)
- `patches/codex/ios-exec-hook.patch`: iOS-specific hook patch applied to submodule
- `apps/ios/Sources/Shitter/Bridge/`: Swift bridge + JSON-RPC client
- `apps/android/app/src/main/java/io/latitudes/shitter/android/ui/`: Android Compose UI shell and screens
- `apps/android/app/src/main/java/io/latitudes/shitter/android/state/`: Android state, transports, session/server orchestration
- `apps/android/core/bridge/`: Android bridge bootstrap and core websocket client
- `apps/android/core/network/`: discovery services
- `apps/android/app/src/test/java/`: Android unit tests (runtime mode + transport policy scaffolding)
- `apps/android/docs/qa-matrix.md`: Android parity checklist
- `tools/scripts/build-android-rust.sh`: builds Android JNI Rust artifacts into `jniLibs`
- `apps/ios/Sources/Shitter/Resources/brand_logo.svg`: source logo (SVG)
- `apps/ios/Sources/Shitter/Resources/brand_logo.png`: in-app logo image used by `BrandLogo`
- `apps/ios/Sources/Shitter/Assets.xcassets/AppIcon.appiconset/`: generated app icon set

## Branding assets

- Home/launch branding uses `BrandLogo` (`apps/ios/Sources/Shitter/Views/BrandLogo.swift`) backed by `brand_logo.png`.
- The app icon is generated from the same logo and stored in `AppIcon.appiconset`.
- If logo art changes, regenerate icon sizes from `Icon-1024.png` (or re-run your ImageMagick resize pipeline) before building.
