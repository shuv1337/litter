# Android App

Native Android app scaffold with module boundaries aligned to iOS feature flows:

- `app`: Android entrypoint/activity.
- `core:network`: discovery/network primitives.
- `core:bridge`: JSON-RPC bridge surface placeholders.
- `feature:discovery`: server discovery flow.
- `feature:sessions`: session listing/resume flow.
- `feature:conversation`: turn/message flow.

## Runtime Transport Lanes

- Canonical app-runtime websocket transport: `app/src/main/java/io/latitudes/shitter/android/state/BridgeRpcTransport.kt`.
  - Used by `ServerManager` for session/message/account flows against local or remote Codex servers.
- On-device bootstrap transport: `core/bridge/src/main/java/io/latitudes/shitter/android/core/bridge/JsonRpcWebSocketClient.kt` via `CodexRpcClient`.
  - Used to start/connect the embedded on-device bridge server and support legacy callers.

## Runtime Startup Flavors

- `onDeviceDebug` / `onDeviceRelease`
  - `BuildConfig.ENABLE_ON_DEVICE_BRIDGE=true`
  - Startup mode: `hybrid` (remote + on-device startup paths available)
- `remoteOnlyDebug` / `remoteOnlyRelease`
  - `BuildConfig.ENABLE_ON_DEVICE_BRIDGE=false`
  - Startup mode: `remote_only` (on-device startup path is blocked in `CodexRpcClient`)

Examples:

```bash
./gradlew :app:assembleOnDeviceDebug
./gradlew :app:assembleRemoteOnlyDebug
```

Open in Android Studio (macOS):

```bash
open -a "Android Studio" apps/android
```

Rebuild + reopen workflow:

```bash
./apps/android/scripts/rebuild-and-reopen.sh
```

Optional variants:

```bash
./apps/android/scripts/rebuild-and-reopen.sh --on-device
./apps/android/scripts/rebuild-and-reopen.sh --remote-only
./apps/android/scripts/rebuild-and-reopen.sh --both --with-rust
./apps/android/scripts/rebuild-and-reopen.sh --no-open
```

QA matrix and regression command list: `apps/android/docs/qa-matrix.md`.

## Rust Bridge (Android)

The Android bridge module loads a Rust shared library named `libcodex_bridge.so`.

Build and copy JNI artifacts into `core:bridge`:

```bash
./tools/scripts/build-android-rust.sh
```

Prerequisites:

- Android NDK (`ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT` set)
- `cargo-ndk` (`cargo install cargo-ndk`)
