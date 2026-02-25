# PLAN: Rename Litter → Shitter (Full Rebrand, Reviewed + Revised v3)

> Goal: replace every tracked `Litter` / `litter` / `LITTER` reference in this repo with
> `Shitter` / `shitter` / `SHITTER`, including paths, symbols, package names, build settings,
> scripts, CI, docs, and bridge integration points.

---

## Review Fixes Incorporated

This revision includes previous fixes plus additional review-driven updates:

- Canonical identity model is explicit and consistent:
  - **Brand/symbols:** `Shitter` / `shitter` / `SHITTER`
  - **iOS bundle IDs:** `io.latitudes.shitter` and `io.latitudes.shitter.remote`
  - **Android package/namespace/appId root:** `io.latitudes.shitter.android`
- Removed conflicting `sigkitten` → `shuv1337` guidance from this plan.
- Added inventory lock workflow (`before` + `after` case-insensitive occurrence lists).
- Clarified Android package-tree destination paths (must end in `/io/latitudes/shitter/android/...`).
- Strengthened script scope and validation:
  - `switch-app-identity.sh` must be migrated off `com.<id>.litter` assumptions (or deprecated in this change).
  - script checks now include dry-run functional checks, not just help text.
  - if `switch-app-identity.sh` is deprecated in this pass, use explicit non-zero deprecation-path validation criteria (instead of dry-run success criteria).
- Added explicit fix for current `apps/ios/scripts/testflight-upload.sh` project-generation bug:
  - use `xcodegen generate --spec "$REPO_DIR/project.yml" --project "$PROJECT_PATH"` (project file path), not `--project "$PROJECT_DIR"` (directory path).
- Expanded path-residue validation from `apps/`-only checks to repo-wide checks (excluding approved out-of-scope paths + this plan file).
- Added optional before/after inventory diff command for audit artifact generation.
- Added explicit Option A (fresh local state) acceptance criteria for iOS keychain + Android SharedPreferences.
- Added explicit `git mv` sequencing notes for path/file moves.

---

## 0) Preflight Decisions (Required)

- [ ] Create a working branch and ensure clean index (excluding intentional submodule noise).
- [ ] Confirm strict rebrand mode: **zero remaining `litter` or `sigkitten` references in tracked source/docs/paths** (except this plan file).
- [ ] Confirm canonical identity model for this plan:
  - iOS IDs remain `io.latitudes.shitter(.remote)`
  - Android IDs/packages remain `io.latitudes.shitter.android`
  - No `com.*.shitter` or `shuv1337` detours in this rebrand pass.
- [ ] Confirm data compatibility policy:
  - **Option A (required for this plan):** rename storage/property keys to `shitter` and accept fresh local state.

### 0.1 Inventory Lock (Before Changes)

- [ ] Capture pre-change occurrence inventory:

```bash
mkdir -p .tmp/rebrand
rg -l -i --hidden 'litter|sigkitten' \
  --glob '!.git/**' \
  --glob '!shared/third_party/codex/**' \
  --glob '!shared/rust-bridge/codex-bridge/target/**' \
  --glob '!PLAN-rename-litter-to-shitter.md' \
  | sort > .tmp/rebrand/occurrences.before.txt
```

---

## 1) Content Updates (Do Before Path Renames)

## 1.1 iOS Config / Build Files

- [ ] `apps/ios/project.yml`
  - `name: Litter` → `name: Shitter`
  - `bundleIdPrefix: com.litter` (and any `com.sigkitten.*` remnants) → `bundleIdPrefix: io.latitudes`
  - Target names: `LitterRemote`/`Litter` → `ShitterRemote`/`Shitter`
  - Paths: `Sources/Litter/...` → `Sources/Shitter/...`
  - `LITTER_DISABLE_ON_DEVICE_CODEX` → `SHITTER_DISABLE_ON_DEVICE_CODEX`
  - Scheme names/target refs updated to `Shitter*`
- [ ] `Package.swift`
  - Package/library/target names: `Litter` → `Shitter`
  - Target path: `apps/ios/Sources/Litter` → `apps/ios/Sources/Shitter`

## 1.2 iOS Swift Source Content

Apply across iOS Swift sources:

- [ ] `LitterTheme` → `ShitterTheme`
- [ ] `LitterApp` → `ShitterApp`
- [ ] `LITTER_DISABLE_ON_DEVICE_CODEX` → `SHITTER_DISABLE_ON_DEVICE_CODEX`
- [ ] Lowercase markdown theme names in `apps/ios/Sources/Litter/Views/MessageBubbleView.swift`
  - `.litter(...)` → `.shitter(...)`
  - `.litterSystem(...)` → `.shitterSystem(...)`
  - `static func litter` → `static func shitter`
  - `static func litterSystem` → `static func shitterSystem`
  - comment header `Litter Markdown Theme` → `Shitter Markdown Theme`
- [ ] Keychain service name in `apps/ios/Sources/Litter/Models/ConnectionTarget.swift`
  - `com.litter.ssh.credentials` → `io.latitudes.shitter.ssh.credentials`

## 1.3 Android Kotlin / Gradle / Manifest Content

### Package/import + symbol changes

- [ ] All Kotlin package/import refs:
  - `com.litter.android` → `io.latitudes.shitter.android`
  - `com.sigkitten.litter.android` → `io.latitudes.shitter.android` (e.g., `R` class imports)
- [ ] UI/state symbol renames:
  - `LitterTheme` → `ShitterTheme`
  - `LitterAppTheme` → `ShitterAppTheme`
  - `LitterAppShell` → `ShitterAppShell`
  - `LitterAppState` → `ShitterAppState`
  - `DefaultLitterAppState` → `DefaultShitterAppState`
  - `rememberLitterAppState` → `rememberShitterAppState`
  - `LitterTypography` → `ShitterTypography`
  - `LitterColorScheme` → `ShitterColorScheme`

### Android app/build/runtime identifiers

- [ ] `apps/android/app/build.gradle.kts`
  - `com.sigkitten.litter.android` → `io.latitudes.shitter.android` (namespace + applicationId)
- [ ] `apps/android/settings.gradle.kts`
  - `LitterAndroid` → `ShitterAndroid`
- [ ] Module namespaces in:
  - `apps/android/core/bridge/build.gradle.kts`
  - `apps/android/core/network/build.gradle.kts`
  - `apps/android/feature/conversation/build.gradle.kts`
  - `apps/android/feature/discovery/build.gradle.kts`
  - `apps/android/feature/sessions/build.gradle.kts`
- [ ] Android manifests:
  - `com.litter.android.runtime.*` → `io.latitudes.shitter.android.runtime.*`
  - `com.litter.android.MainActivity` → `io.latitudes.shitter.android.MainActivity`
  - feature manifest package attrs `com.litter.android.feature.*` → `io.latitudes.shitter.android.feature.*`

### Missing literal keys (critical additions)

- [ ] `apps/android/core/bridge/src/main/java/com/litter/android/core/bridge/CodexRpcClient.kt`
  - `APP_BUILD_CONFIG_CLASS = "com.sigkitten.litter.android.BuildConfig"` → `"io.latitudes.shitter.android.BuildConfig"`
  - `SYSTEM_PROPERTY = "litter.android.on_device_bridge.enabled"` → `"shitter.android.on_device_bridge.enabled"`
  - `ENV_VARIABLE = "LITTER_ANDROID_ON_DEVICE_BRIDGE_ENABLED"` → `"SHITTER_ANDROID_ON_DEVICE_BRIDGE_ENABLED"`
- [ ] `apps/android/app/src/main/java/com/litter/android/state/ServerManager.kt`
  - `"litter_saved_servers"` → `"shitter_saved_servers"`
- [ ] `apps/android/app/src/main/java/com/litter/android/state/SshCredentialStore.kt`
  - `"litter_ssh_credentials_secure"` → `"shitter_ssh_credentials_secure"`
  - `"litter_ssh_credentials"` → `"shitter_ssh_credentials"`
- [ ] `apps/android/app/src/test/java/com/litter/android/RuntimeFlavorConfigTest.kt`
  - BuildConfig import package updated to `io.latitudes.shitter.android.BuildConfig`

## 1.4 Rust Bridge JNI Symbols (Critical)

- [ ] `shared/rust-bridge/codex-bridge/src/android_jni.rs`
  - `Java_com_litter_android_core_bridge_NativeCodexBridge_nativeStartServerPort`
    → `Java_io_latitudes_shitter_android_core_bridge_NativeCodexBridge_nativeStartServerPort`
  - `Java_com_litter_android_core_bridge_NativeCodexBridge_nativeStopServer`
    → `Java_io_latitudes_shitter_android_core_bridge_NativeCodexBridge_nativeStopServer`

Without this, renamed Android package/class paths will break native symbol resolution.

## 1.5 Scripts, CI, Docs, and Repo Metadata

### Scripts

- [ ] `apps/ios/scripts/testflight-setup.sh`
  - `com.sigkitten.litter` → `io.latitudes.shitter`
  - add explicit `-h/--help`
  - add `--dry-run` mode for safe functional validation
- [ ] `apps/ios/scripts/testflight-upload.sh`
  - default scheme/project/profile naming: `Litter*` → `Shitter*`
  - `com.sigkitten.litter` → `io.latitudes.shitter`
  - fix xcodegen invocation to target project file path: use `--project "$PROJECT_PATH"` (not `"$PROJECT_DIR"`)
  - add explicit `-h/--help`
  - add `--dry-run` mode for safe functional validation
- [ ] `tools/scripts/deploy-android-ondevice.sh`
  - `APP_ID` and `MAIN_ACTIVITY` to `io.latitudes.shitter.android` package names
  - add `--dry-run` mode for safe functional validation
- [ ] `tools/scripts/switch-app-identity.sh`
  - remove `com.<id>.litter` / `sigkitten` assumptions from detection + replacement
  - canonical mode should derive IDs from a domain prefix (default `io.latitudes`) using `.shitter` suffixes
  - update all `Litter.xcodeproj` refs → `Shitter.xcodeproj`
  - add `--dry-run`
  - **fallback if migration is too risky in this pass:** deprecate script with clear error + remove its usage from docs in same PR
- [ ] `tools/scripts/README.md`
  - update script usage examples to the canonical `io.latitudes.shitter*` model

### CI + gitignore

- [ ] `.github/workflows/ios.yml`
  - project path/scheme/step names `Litter*` → `Shitter*`
- [ ] `.gitignore`
  - `apps/ios/Litter.xcodeproj/Litter.xcodeproj/` → `apps/ios/Shitter.xcodeproj/Shitter.xcodeproj/`

### Docs

- [ ] `README.md`
- [ ] `AGENTS.md`
- [ ] `apps/android/README.md`
- [ ] `docs/architecture/ios-android-monorepo-migration-plan.md`
- [ ] `docs/ios/quickstart.md`
- [ ] `docs/releases/ios-testflight-checklist.md`
- [ ] `docs/dev-setup-progress.md`
- [ ] `docs/ios-signing-status.md`

Update all naming, paths, scheme names, package names, and command snippets to `Shitter` / `shitter` / `io.latitudes`.

---

## 2) Path + File Renames (After Content Pass)

## 2.0 Sequencing Notes (Use `git mv`)

- [ ] Complete content replacements first.
- [ ] Perform file/path moves in isolated commit chunks with `git mv` (no mixed logic edits).
- [ ] Regenerate generated artifacts after moves (do not hand-edit final pbxproj).

## 2.1 iOS Renames

- [ ] `apps/ios/Sources/Litter/` → `apps/ios/Sources/Shitter/`
- [ ] `apps/ios/Sources/Shitter/LitterApp.swift` → `apps/ios/Sources/Shitter/ShitterApp.swift`
- [ ] Remove old generated project: `apps/ios/Litter.xcodeproj`

## 2.2 Android Package Tree Renames (7 trees)

All destination trees must include `/android/`:

- [ ] `apps/android/app/src/main/java/com/litter/android/` → `apps/android/app/src/main/java/io/latitudes/shitter/android/`
- [ ] `apps/android/app/src/test/java/com/litter/android/` → `apps/android/app/src/test/java/io/latitudes/shitter/android/`
- [ ] `apps/android/core/bridge/src/main/java/com/litter/android/` → `apps/android/core/bridge/src/main/java/io/latitudes/shitter/android/`
- [ ] `apps/android/core/network/src/main/java/com/litter/android/` → `apps/android/core/network/src/main/java/io/latitudes/shitter/android/`
- [ ] `apps/android/feature/conversation/src/main/java/com/litter/android/` → `apps/android/feature/conversation/src/main/java/io/latitudes/shitter/android/`
- [ ] `apps/android/feature/discovery/src/main/java/com/litter/android/` → `apps/android/feature/discovery/src/main/java/io/latitudes/shitter/android/`
- [ ] `apps/android/feature/sessions/src/main/java/com/litter/android/` → `apps/android/feature/sessions/src/main/java/io/latitudes/shitter/android/`

## 2.3 Android File Renames

- [ ] `LitterAppShell.kt` → `ShitterAppShell.kt`
- [ ] `LitterAppState.kt` → `ShitterAppState.kt`
- [ ] `LitterTheme.kt` → `ShitterTheme.kt`

---

## 3) Regenerate / Rebuild Generated Artifacts

- [ ] Regenerate iOS project from updated spec:

```bash
xcodegen generate --spec apps/ios/project.yml --project apps/ios/Shitter.xcodeproj
```

- [ ] Rebuild Android Rust JNI libs (required after JNI function rename):

```bash
./tools/scripts/build-android-rust.sh
```

- [ ] Rebuild iOS Rust libs (to ensure paths and references are clean):

```bash
./apps/ios/scripts/build-rust.sh
```

---

## 4) Validation Gates

## 4.0 Inventory Exhaustion Check

- [ ] Capture post-change inventory:

```bash
rg -l -i --hidden 'litter|sigkitten' \
  --glob '!.git/**' \
  --glob '!shared/third_party/codex/**' \
  --glob '!shared/rust-bridge/codex-bridge/target/**' \
  --glob '!PLAN-rename-litter-to-shitter.md' \
  | sort > .tmp/rebrand/occurrences.after.txt
```

- [ ] Validate it is empty:

```bash
test ! -s .tmp/rebrand/occurrences.after.txt
```

- [ ] (Recommended) capture before/after inventory diff artifact:

```bash
comm -3 .tmp/rebrand/occurrences.before.txt .tmp/rebrand/occurrences.after.txt \
  > .tmp/rebrand/occurrences.diff.txt
```

## 4.1 Zero-Reference Scan

Tracked-file authoritative check:

```bash
git grep -n -i 'litter\|sigkitten' -- . ':(exclude)PLAN-rename-litter-to-shitter.md'
```

Expected: **no matches**.

Working-tree check (including docs/scripts not yet committed):

```bash
rg -n -i --hidden 'litter|sigkitten' \
  --glob '!.git/**' \
  --glob '!shared/third_party/codex/**' \
  --glob '!shared/rust-bridge/codex-bridge/target/**' \
  --glob '!PLAN-rename-litter-to-shitter.md'
```

Expected: **no matches**.

Path residue checks (repo-wide, aligned to strict mode; exclude out-of-scope paths + this plan file):

```bash
find . \
  -path './.git' -prune -o \
  -path './shared/third_party/codex' -prune -o \
  -path './shared/rust-bridge/codex-bridge/target' -prune -o \
  -path './PLAN-rename-litter-to-shitter.md' -prune -o \
  -iname '*litter*' -print

find . \
  -path './.git' -prune -o \
  -path './shared/third_party/codex' -prune -o \
  -path './shared/rust-bridge/codex-bridge/target' -prune -o \
  -path './PLAN-rename-litter-to-shitter.md' -prune -o \
  -iname '*sigkitten*' -print

find . \
  -path './.git' -prune -o \
  -path './shared/third_party/codex' -prune -o \
  -path './shared/rust-bridge/codex-bridge/target' -prune -o \
  -type d -path '*com/litter*' -print
```

Expected: **no matches**.

## 4.2 Build / Test Validation

### iOS

```bash
xcodebuild -project apps/ios/Shitter.xcodeproj -scheme ShitterRemote -configuration Debug -destination 'generic/platform=iOS Simulator' build
xcodebuild -project apps/ios/Shitter.xcodeproj -scheme Shitter -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

### Android

```bash
gradle -p apps/android :app:assembleOnDeviceDebug :app:assembleRemoteOnlyDebug
gradle -p apps/android :app:testOnDeviceDebugUnitTest :app:testRemoteOnlyDebugUnitTest
```

## 4.3 Script Validation (Syntax + Functional Dry-Run / Deprecation Path)

Dry-run contract (for scripts that support `--dry-run`):
- [ ] `--dry-run` must perform validation/planning only (no uploads, installs, device launches, project-regeneration side effects, or mutable external API calls).
- [ ] `--help` must explicitly document dry-run behavior and expected exit code.

```bash
bash -n tools/scripts/switch-app-identity.sh
bash -n tools/scripts/deploy-android-ondevice.sh
bash -n apps/ios/scripts/testflight-setup.sh
bash -n apps/ios/scripts/testflight-upload.sh
```

Common script checks:

```bash
./apps/ios/scripts/testflight-setup.sh --help
./apps/ios/scripts/testflight-setup.sh --dry-run

./apps/ios/scripts/testflight-upload.sh --help
./apps/ios/scripts/testflight-upload.sh --dry-run

./tools/scripts/deploy-android-ondevice.sh --help
./tools/scripts/deploy-android-ondevice.sh --dry-run --skip-rust --no-launch --serial emulator-5554
```

`switch-app-identity.sh` validation — choose one branch for this PR:

**Branch A (script migrated in this pass)**

```bash
./tools/scripts/switch-app-identity.sh --help
./tools/scripts/switch-app-identity.sh --dry-run
```

Expected: explicit help and successful dry-run with no side effects.

**Branch B (script deprecated in this pass)**

```bash
./tools/scripts/switch-app-identity.sh --help || true
if ./tools/scripts/switch-app-identity.sh --dry-run; then
  echo "error: expected deprecated script to exit non-zero for --dry-run" >&2
  exit 1
fi
git grep -n 'switch-app-identity.sh' -- . \
  ':(exclude)tools/scripts/switch-app-identity.sh' \
  ':(exclude)PLAN-rename-litter-to-shitter.md'
```

Expected: script exits non-zero with clear deprecation guidance; repo docs/automation no longer instruct script usage (grep returns no matches).

## 4.4 Option A Data-Reset Acceptance (Required)

### iOS (Keychain service rename)
- [ ] From a pre-rename build, save SSH credentials.
- [ ] Upgrade/install renamed build.
- [ ] Confirm old credentials are not auto-loaded (fresh local state).
- [ ] Save new credentials and relaunch; confirm new credentials persist.

### Android (SharedPreferences key rename + app ID/package rename)
- [ ] From a pre-rename build, save server entries + SSH credentials.
- [ ] Upgrade/install renamed build.
- [ ] Confirm old entries are not loaded (fresh local state).
- [ ] Save new entries and relaunch; confirm new entries persist.

- [ ] Release note explicitly states local saved server/credential state resets as part of rebrand.

---

## 5) Out of Scope / Preserved

- `shared/third_party/codex/` submodule contents
- Build artifacts (`**/target/`, generated APK/IPA/intermediates)
- Git history rewrite

---

## Implementation Notes

- Prefer targeted replacements (`rg -l` + portable edits) over one giant blanket replacement.
- For bulk automation, avoid ungrouped `find ... -o ...`; always use explicit grouping and file type constraints.
- Since iOS project files are generated from `apps/ios/project.yml`, do not hand-edit pbxproj for final state; regenerate after updates.
- Keep move-only commits separate from logic/content edits where possible for easier review.
