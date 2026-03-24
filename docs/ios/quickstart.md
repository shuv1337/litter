# iOS Quickstart

## Prerequisites
- Xcode.app
- xcodegen (`brew install xcodegen`)
- Rust iOS targets:
  - `aarch64-apple-ios`
  - `aarch64-apple-ios-sim`
  - `x86_64-apple-ios` only if you need Intel Mac simulator support

## Build Steps
1. Sync Codex submodule + apply iOS patch:
   - `./apps/ios/scripts/sync-codex.sh`
   - This preserves the current submodule checkout by default. Use `--recorded-gitlink` only if you want to reset to the commit recorded in the parent repo.
2. Build Rust bridge XCFramework:
   - `./apps/ios/scripts/build-rust.sh`
   - Add `--with-intel-sim` only if you need an Intel Mac simulator slice.
3. Generate project:
   - `./apps/ios/scripts/regenerate-project.sh`
4. Build app:
   - `xcodebuild -project apps/ios/Shitter.xcodeproj -scheme Shitter -configuration Debug -destination 'generic/platform=iOS Simulator' build`

## Schemes
- `ShitterRemote`: remote-only mode.
- `Shitter`: includes on-device Rust bridge XCFramework.
