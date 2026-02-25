# Dev Setup Progress

## What We Did

### 1. ✅ Fixed Codex Submodule
- Old pin `6e7337af` was force-pushed away from `openai/codex`
- Re-cloned at current `main` (`5163850`)
- Applied `patches/codex/ios-exec-hook.patch` — still applies cleanly
- Committed and pushed new submodule pin

### 2. ✅ Fixed Cargo / Rust Toolchain
- Added `~/.cargo/config.toml` with `git-fetch-with-cli = true` (needed because `~/.gitconfig` rewrites HTTPS→SSH)
- Updated Rust to **1.93.0** (matches upstream `rust-toolchain.toml`)
- Updated `native-tls` lock from 0.2.17→0.2.18 to fix build on modern Rust
- **Note:** The `tungstenite` fork rev `9200079d` was force-pushed away from GitHub, but still exists in local cargo git cache after building upstream. Fresh clones on new machines will fail to fetch it — need to eventually update upstream or vendor it.

### 3. ✅ Built Codex App Server on Linux (shuvdev)
- `cargo build --release -p codex-app-server` in `shared/third_party/codex/codex-rs/`
- Binary at `target/release/codex-app-server`
- Running on `ws://0.0.0.0:8390` (matches iOS discovery port)
- Firewall opened: `ufw allow 8390/tcp`
- Added Avahi SSH service (`/etc/avahi/services/ssh.service`) so shuvdev is discoverable via Bonjour

### 4. ✅ Set Up Mac Build Environment (shuvbot)
- **Xcode 26.2** — accepted license, ran first-launch setup
- **iOS 26.2 simulator runtime** downloaded (8.4 GB)
- **xcodegen** installed via Homebrew
- **Rust 1.93.0** + iOS targets (`aarch64-apple-ios`, `aarch64-apple-ios-sim`, `x86_64-apple-ios`)
- Repo cloned, submodule initialized
- `ios_system` frameworks downloaded
- Rust bridge XCFramework built (3 targets → fat simulator lib → xcframework)
- Xcode project generated via xcodegen

### 5. ✅ iOS App Builds and Runs in Simulator
- `Shitter` scheme builds successfully for iPhone 17 Pro simulator
- App launches and discovers shuvdev codex server via Bonjour

### 6. ✅ Replaced Logo
- Swapped the old cat-box logo with demon toilet logo
- Source: `~/Downloads/logo.png` (1024x1536, high-res)
- Generated `brand_logo.png` (1024x1024, transparent bg, tight crop)
- Generated all AppIcon sizes (20→1024) with black bg
- Committed and pushed

### 7. ✅ Changed Bundle ID
- Previous temporary bundle ID → `io.latitudes.shitter` (old one was globally taken)
- Updated `apps/ios/project.yml`

### 8. ✅ App Store Connect Setup (Partial)
- API key created: Key ID `FS8S8T7847`, Issuer `b0a54e26-2771-45ae-8860-61316950e1dd`
- `asc` CLI installed and authenticated (config file mode, bypassing keychain)
- Bundle ID `io.latitudes.shitter` registered
- App "Shitter" created in App Store Connect (manual, via web UI)
- Distribution certificate created: `Apple Distribution: Kevin Crommett (7H54B326YZ)`
- App Store provisioning profile created: `Shitter App Store`
- CI keychain created with cert + WWDR chain — codesign works over SSH

### 9. ✅ Archive Succeeded
- `xcodebuild archive` with automatic signing + API key auth works
- Archive at `apps/ios/build/Shitter.xcarchive`

### 10. ❌ Export / Upload to TestFlight — BLOCKED
Two separate failures:

**a) `xcodebuild -exportArchive` fails with `errSecInternalComponent`**
- Root cause: macOS Security framework needs the SecurityAgent GUI process for codesign during IPA export
- SSH sessions don't have access to SecurityAgent
- The CI keychain trick fixed standalone `codesign` commands but `xcodebuild -exportArchive` uses its own internal codesign flow that still hits this

**b) Manual IPA + `altool --upload-app` fails with "Checksums do not match"**
- Hand-built IPA (zip of re-signed Payload/) uploads but Apple's server rejects every chunk
- Likely because the IPA structure/signing doesn't match what Apple expects (missing `SwiftSupport/`, `Symbols/`, proper `embedded.mobileprovision`, etc.)

---

## Remaining Steps to Get on TestFlight

### Option A: Fix the SSH codesign issue (recommended)
The `xcodebuild -exportArchive` flow is the correct way — it handles re-signing, thinning, symbol stripping, and IPA packaging properly. To make it work over SSH:

1. **Run the export from the GUI session** — either:
   - VNC/Screen Sharing into shuvbot and run the export command from Terminal.app
   - Use `launchctl asuser` with the correct GUI login session (requires the user to be logged in at the console)
   - Set up a LaunchAgent that runs the export when triggered

2. **Or use Fastlane** — `fastlane gym` handles the keychain/codesign dance better than raw xcodebuild for CI:
   ```
   brew install fastlane
   fastlane gym --project Shitter.xcodeproj --scheme Shitter ...
   ```

### Option B: Use Xcode GUI on shuvbot
1. Open the project in Xcode on shuvbot (via VNC/Screen Sharing)
2. Product → Archive
3. Distribute App → App Store Connect → Upload
4. This sidesteps all SSH keychain issues

### After upload succeeds
1. Wait for Apple processing (~5-15 min)
2. Add build to TestFlight internal testing group
3. Install via TestFlight app on iPhone

---

## Key Credentials / Config

| Item | Value |
|------|-------|
| Team ID | `7H54B326YZ` |
| Bundle ID | `io.latitudes.shitter` |
| ASC Key ID | `FS8S8T7847` |
| ASC Issuer ID | `b0a54e26-2771-45ae-8860-61316950e1dd` |
| API key path (shuvbot) | `~/AuthKey_FS8S8T7847.p8` |
| Distribution cert | `Apple Distribution: Kevin Crommett (7H54B326YZ)` |
| CI keychain (shuvbot) | `~/Library/Keychains/ci.keychain-db` (password: `ci`) |
| Provisioning profile | `Shitter App Store` (ID: `4N85L65CHW`) |
| Codex server port | `8390` (matches iOS discovery) |

## File Locations on shuvbot
- Repo: `~/repos/shitter/`
- Archive: `~/repos/shitter/apps/ios/build/Shitter.xcarchive`
- Signing assets: `~/signing/`
- API key: `~/AuthKey_FS8S8T7847.p8` and `~/.private_keys/`
