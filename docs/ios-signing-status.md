# iOS Signing & Device Build Status

_Updated: 2025-02-24_

## Current State

### What works
- **Xcode 26.2** installed on shuvbot, project opens and compiles Swift code fine
- **Rust bridge** (`codex_bridge.xcframework`) built for device + simulator
- **Two signing identities** in the login keychain:
  - `Apple Development: Created via API (FS8S8T7847)` — for device builds
  - `Apple Distribution: Kevin Crommett (7H54B326YZ)` — for App Store / TestFlight
- **Provisioning profiles** installed (`io.latitudes.shitter`)
- **App Store Connect** API key at `~/AuthKey_FS8S8T7847.p8`
- **Signing assets** backed up in `~/signing/` (cert, key, p12, provisioning profile)

### What's broken
- **CodeSign fails with `errSecInternalComponent`** when Xcode tries to sign embedded frameworks (`ios_system.framework`, `files.framework`, `shell.framework`, etc.)
- Root cause: the **login keychain locks itself** and becomes inaccessible to codesign — even from the Xcode GUI
- The old **CI keychain** (`ci.keychain-db`) was deleted because the password was lost — it is no longer on the system
- The login keychain currently reports `User interaction is not allowed` over SSH, which means it may still be locked or the security daemon needs a GUI unlock

## What Needs to Happen

### Step 1: Unlock the login keychain (from the Mac GUI)
On shuvbot, open **Keychain Access.app** and make sure the `login` keychain is unlocked. Then set it to stay unlocked:

```bash
# From Terminal.app on the Mac (not SSH):
security unlock-keychain ~/Library/Keychains/login.keychain-db
security set-keychain-settings ~/Library/Keychains/login.keychain-db
# (no -t flag = no auto-lock timeout)
```

### Step 2: Verify codesign works
```bash
# Quick codesign smoke test — pick any framework:
codesign --force --sign "Apple Development: Created via API (FS8S8T7847)" \
  ~/repos/shitter/apps/ios/Frameworks/ios_system/files.xcframework/ios-arm64/files.framework
```
If this succeeds, signing is fixed.

### Step 3: Build to device
1. Plug iPhone into shuvbot via USB
2. In Xcode, select the iPhone as the run destination (not a simulator)
3. Select the **Shitter** scheme (not ShitterRemote)
4. Hit **▶ Run**

### Step 4 (optional): Recreate CI keychain for SSH/CI builds
If we need headless (SSH) builds again later, recreate the CI keychain:

```bash
# Create a new CI keychain with a known password
security create-keychain -p "ci" ~/Library/Keychains/ci.keychain-db

# Add it to the search list
security list-keychains -s ~/Library/Keychains/login.keychain-db \
  ~/Library/Keychains/ci.keychain-db \
  /Library/Keychains/System.keychain

# Import the distribution cert + key
security import ~/signing/dist.p12 -k ~/Library/Keychains/ci.keychain-db \
  -P "" -T /usr/bin/codesign -T /usr/bin/security

# Allow codesign access without prompt
security set-key-partition-list -S apple-tool:,apple: -s -k "ci" \
  ~/Library/Keychains/ci.keychain-db

# Disable auto-lock
security set-keychain-settings ~/Library/Keychains/ci.keychain-db
```

This is only needed for SSH-based builds (TestFlight upload scripts, CI). For plugging in a phone and hitting Run in Xcode, the login keychain is sufficient.

## Key Files on shuvbot

| Path | Contents |
|------|----------|
| `~/signing/dist.p12` | Distribution cert + private key (PKCS12) |
| `~/signing/dist.cer` | Distribution certificate |
| `~/signing/dist.key` | Private key (PEM) |
| `~/signing/shitter.mobileprovision` | App Store provisioning profile |
| `~/AuthKey_FS8S8T7847.p8` | App Store Connect API key |
| `~/.private_keys/AuthKey_FS8S8T7847.p8` | Same API key (alt location) |
