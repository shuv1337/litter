# Shared Scripts

Cross-platform automation scripts for building, deploying, and managing the Shitter app.

## Scripts

### build-android-rust.sh

Builds Android Rust bridge JNI libs into `apps/android/core/bridge/src/main/jniLibs`.

```bash
./tools/scripts/build-android-rust.sh
```

### deploy-android-ondevice.sh

Builds Rust JNI libs, assembles `onDeviceDebug`, installs on a target device, and launches the app.

```bash
# Full build and deploy to auto-detected device
./tools/scripts/deploy-android-ondevice.sh

# Deploy to specific device
./tools/scripts/deploy-android-ondevice.sh --serial emulator-5554

# Skip Rust rebuild
./tools/scripts/deploy-android-ondevice.sh --skip-rust

# Preview what would be done
./tools/scripts/deploy-android-ondevice.sh --dry-run
```

Options:
- `-s, --serial <serial>` - Target specific ADB device (or set `ANDROID_SERIAL`)
- `--skip-rust` - Skip Rust bridge rebuild
- `--no-launch` - Install only, don't launch
- `--dry-run` - Preview without executing
- `-h, --help` - Show help

### switch-app-identity.sh (DEPRECATED)

**This script is deprecated.** The app now uses fixed identifiers:

- iOS: `io.latitudes.shitter` / `io.latitudes.shitter.remote`
- Android: `io.latitudes.shitter.android`

To modify identifiers for local development:
- iOS: Edit `apps/ios/project.yml` and regenerate with `xcodegen`
- Android: Edit `apps/android/app/build.gradle.kts`

## iOS Scripts

See `apps/ios/scripts/` for iOS-specific scripts:

- `testflight-setup.sh` - Creates TestFlight internal beta group
- `testflight-upload.sh` - Archives, exports, and uploads to TestFlight
- `build-rust.sh` - Builds iOS Rust XCFramework
- `download-ios-system.sh` - Downloads ios_system frameworks
