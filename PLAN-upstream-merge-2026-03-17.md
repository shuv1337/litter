# PLAN: Upstream Merge + Port 9234 Migration (Reviewed + Revised 2026-03-17)

> **Goal:** merge the remaining 13 commits from `upstream/main` into our current rebrand branch,
> keep the repo on the `Shitter` identity model, update the Codex submodule, and change the
> default Codex discovery / SSH-tunnel port from `8390` → `9234` while retaining `8390` only as
> a backward-compat discovery fallback.

---

## Plan Review Summary

**Assessment:** feasible, but the original draft needed revision before implementation.

### Critical issues found in the original draft

1. **Wrong merge baseline**
   - The repo is currently on `rebrand/litter-to-shitter` at `43c4ad3`, not `main`.
   - `HEAD...upstream/main` is currently `31 ahead / 13 behind`, so the merge must start from the
     rebrand branch, not from `main`.

2. **Conflict inventory was incomplete**
   - Upstream adds first-party files not listed in the draft, including:
     - `apps/ios/Sources/Litter/Bridge/CodexBridge.swift`
     - `apps/ios/Sources/Litter/Bridge/CodexChannel.swift`
     - `apps/ios/Sources/Litter/Bridge/IosSystemBridge.m`
     - `apps/ios/Sources/Litter/Bridge/codex_bridge_objc.h`
     - `apps/ios/Sources/Litter/Views/ConversationComposerContextBarView.swift`
     - `apps/ios/Sources/Litter/Views/SubagentCardView.swift`
     - `apps/ios/Tests/CodexIOSTests/NetworkDiscoveryTests.swift`
     - `apps/ios/scripts/sanitize-ios-frameworks.sh`
     - `apps/android/feature/discovery/src/main/java/com/litter/android/feature/discovery/DiscoveryFeature.kt`
     - `apps/android/feature/sessions/src/main/java/com/litter/android/feature/sessions/SessionsFeature.kt`

3. **Validation grep commands were too noisy**
   - Broad `8390|9234` scans match unrelated values like theme hex colors and lockfile checksums.
   - Broad `litter` scans currently hit `services/push-proxy/bun.lock`, even though
     `services/push-proxy/package.json` is already correctly branded as `shitter-push-proxy`.

### Important issues found

1. **Generated iOS project files are already dirty locally**
   - `apps/ios/Shitter.xcodeproj/project.pbxproj`
   - `apps/ios/Shitter.xcodeproj/xcuserdata/shuv.xcuserdatad/xcschemes/xcschememanagement.plist`
   - Treat these as disposable/generated artifacts and do not use them as merge truth.

2. **Port migration needs exact file coverage**
   - iOS still defaults to `8390` in:
     - `apps/ios/Sources/Shitter/Models/NetworkDiscovery.swift:6`
     - `apps/ios/Sources/Shitter/Models/NetworkDiscovery.swift:759`
     - `apps/ios/Sources/Shitter/Models/SSHSessionManager.swift:16`
     - `apps/ios/Sources/Shitter/Views/DiscoveryView.swift:13`
     - `apps/ios/Sources/Shitter/Views/DiscoveryView.swift:527`
     - `apps/ios/Sources/Shitter/Views/PreviewSupport.swift:13`
   - Android still defaults to `8390` in:
     - `apps/android/core/network/src/main/java/io/latitudes/shitter/android/core/network/ServerDiscoveryService.kt:24`
     - `apps/android/core/network/src/main/java/io/latitudes/shitter/android/core/network/ServerDiscoveryService.kt:70`
     - `apps/android/app/src/main/java/io/latitudes/shitter/android/state/SshSessionManager.kt:30`
     - `apps/android/app/src/main/java/io/latitudes/shitter/android/ui/ShitterAppState.kt:97`
     - `apps/android/app/src/main/java/io/latitudes/shitter/android/ui/ShitterAppState.kt:1373`
     - `apps/android/app/src/main/java/io/latitudes/shitter/android/ui/ShitterAppState.kt:1447`

3. **Submodule is still on the old revision**
   - `shared/third_party/codex` is currently at `029aab5563caed2f2bbea8a1815a42cbf22b79a2`.
   - The submodule update must be treated as a real implementation step, not assumed complete.

### Approval status

**NEEDS REVISION → revised below**

---

## Current repo state (verified before implementation)

- [x] Current branch is `rebrand/litter-to-shitter`
- [x] Current HEAD is `43c4ad3`
- [x] `upstream/main` is 13 commits ahead of current HEAD
- [x] Shitter branding is already the canonical local identity:
  - iOS project name / schemes / bundle IDs are `Shitter*` / `io.latitudes.shitter*`
  - Android namespace and app id are `io.latitudes.shitter.android`
  - Source trees are `Sources/Shitter`, `Sources/ShitterLiveActivity`, and
    `io/latitudes/shitter/android/...`
- [x] Default Codex port is still `8390` in both platforms and tests
- [x] Codex submodule still needs update
- [x] Working tree is clean

---

## Codebase alignment

### Already aligned with the desired identity model
- `apps/ios/project.yml`
- `apps/android/app/build.gradle.kts`
- `apps/android/settings.gradle.kts`
- `tools/scripts/switch-app-identity.sh` (already deprecated in favor of fixed IDs)
- `services/push-proxy/package.json`

### Not yet aligned with the desired port migration
- `apps/ios/Sources/Shitter/Models/NetworkDiscovery.swift`
- `apps/ios/Sources/Shitter/Models/SSHSessionManager.swift`
- `apps/ios/Sources/Shitter/Views/DiscoveryView.swift`
- `apps/ios/Sources/Shitter/Views/PreviewSupport.swift`
- `apps/ios/Tests/CodexIOSTests/HomeDashboardSupportTests.swift`
- `apps/android/core/network/src/main/java/io/latitudes/shitter/android/core/network/ServerDiscoveryService.kt`
- `apps/android/app/src/main/java/io/latitudes/shitter/android/state/SshSessionManager.kt`
- `apps/android/app/src/main/java/io/latitudes/shitter/android/ui/ShitterAppState.kt`
- `apps/android/app/src/test/java/io/latitudes/shitter/android/state/ServerConfigPersistenceTest.kt`

### Incoming upstream merge areas that require explicit handling
- iOS generated project + schemes:
  - `apps/ios/Litter.xcodeproj/**`
  - `apps/ios/Shitter.xcodeproj/**`
- iOS bridge and view additions:
  - `apps/ios/Sources/Litter/Bridge/**`
  - `apps/ios/Sources/Litter/Views/ConversationComposerContextBarView.swift`
  - `apps/ios/Sources/Litter/Views/SubagentCardView.swift`
- iOS tests / scripts:
  - `apps/ios/Tests/CodexIOSTests/NetworkDiscoveryTests.swift`
  - `apps/ios/scripts/sanitize-ios-frameworks.sh`
- Android feature package regressions:
  - `apps/android/feature/discovery/**`
  - `apps/android/feature/sessions/**`
- Repo metadata / packaging / CI:
  - `.github/workflows/*`
  - `Package.swift`
  - `README.md`
  - `AGENTS.md`
  - `apps/android/scripts/*`
  - `apps/android/app/src/main/play/**`

---

## Revised execution plan

## Phase 1 — Prep from the correct baseline

- [x] **1.1** Commit or stash all current local changes, including generated iOS project churn.
- [x] **1.2** Create a merge branch from `rebrand/litter-to-shitter`, not `main`:
  ```bash
  git checkout rebrand/litter-to-shitter
  git pull --ff-only origin rebrand/litter-to-shitter
  git checkout -b merge/upstream-2026-03-17
  ```
- [x] **1.3** Capture merge inputs for the handoff note:
  ```bash
  git rev-parse --short HEAD
  git rev-list --left-right --count HEAD...upstream/main
  git diff --name-status HEAD..upstream/main
  git submodule status --recursive
  ```
- [x] **1.4** Back up Shitter brand assets before the merge:
  - `apps/ios/Sources/Shitter/Assets.xcassets/AppIcon.appiconset/`
  - `apps/ios/Sources/Shitter/Assets.xcassets/brand_logo.imageset/brand_logo.png`
  - `apps/ios/Sources/Shitter/Resources/brand_logo.png`
  - `apps/ios/Sources/ShitterLiveActivity/Assets.xcassets/brand_logo.imageset/brand_logo.png`

## Phase 2 — Merge upstream/main

- [x] **2.1** Run the merge without auto-committing:
  ```bash
  git merge upstream/main --no-commit
  ```
- [x] **2.2** Resolve rename conflicts by keeping our canonical destination paths:
  - iOS app sources stay under `apps/ios/Sources/Shitter/`
  - iOS widget sources stay under `apps/ios/Sources/ShitterLiveActivity/`
  - Android app/core/feature sources stay under `io/latitudes/shitter/android/...`
- [x] **2.3** Do **not** preserve upstream `Litter.xcodeproj` as the final artifact.
  - Use it only as a reference if needed.
  - Final iOS project must be regenerated from `apps/ios/project.yml`.
- [x] **2.4** Explicitly carry over newly added upstream files into Shitter paths:
  - `CodexBridge.swift`
  - `CodexChannel.swift`
  - `IosSystemBridge.m`
  - `codex_bridge_objc.h`
  - `ConversationComposerContextBarView.swift`
  - `SubagentCardView.swift`
  - `NetworkDiscoveryTests.swift`
  - `sanitize-ios-frameworks.sh`
  - Android `DiscoveryFeature.kt`
  - Android `SessionsFeature.kt`
- [x] **2.5** Resolve high-risk merge targets with bias toward upstream behavior but local identity:
  - `apps/ios/project.yml`
  - `Package.swift`
  - `apps/android/app/build.gradle.kts`
  - `apps/android/settings.gradle.kts`
  - `apps/android/core/*/build.gradle.kts`
  - `apps/android/feature/*/build.gradle.kts`
  - `.github/workflows/*`
  - `apps/android/scripts/*`
  - `apps/ios/scripts/*`

## Phase 3 — Re-apply Shitter identity after the merge

### 3.1 iOS
- [x] Keep project / target / scheme names as `Shitter`, `ShitterRemote`, `ShitterLiveActivity`
- [x] Keep bundle identifiers under `io.latitudes.shitter*`
- [x] Keep app group as `group.io.latitudes.shitter`
- [x] Move any upstream `Sources/Litter/**` content into `Sources/Shitter/**`
- [x] Delete any leftover `apps/ios/Litter.xcodeproj/` and `apps/ios/Sources/Litter/`
- [x] Restore backed-up Shitter app icons and logos after conflict resolution

### 3.2 Android
- [x] Keep namespace / applicationId as `io.latitudes.shitter.android`
- [x] Move any upstream `com/litter/android/**` content into `io/latitudes/shitter/android/**`
- [x] Fix feature module source trees if the merge reintroduces `com/litter` paths:
  - `apps/android/feature/conversation/**`
  - `apps/android/feature/discovery/**`
  - `apps/android/feature/sessions/**`
- [x] Keep display strings and Play metadata branded as `Shitter`

### 3.3 Docs / scripts / workflows
- [x] Re-check `README.md`, `AGENTS.md`, workflows, release scripts, and store metadata for any reintroduced `Litter` / `com.litter` / `com.sigkitten` references
- [x] If `services/push-proxy/bun.lock` reintroduces stale package-name branding, regenerate it from the current `package.json`

## Phase 4 — Port migration: 8390 → 9234

**Policy:** `9234` becomes the default/manual/SSH-tunnel port. `8390` remains only as a discovery fallback for older servers.

### 4.1 iOS
- [x] `apps/ios/Sources/Shitter/Models/NetworkDiscovery.swift`
  - `codexDiscoveryPorts` → `[9234, 8390, 4222]`
  - sender-port fallback → `9234`
- [x] `apps/ios/Sources/Shitter/Models/SSHSessionManager.swift`
  - `defaultRemotePort` → `9234`
- [x] `apps/ios/Sources/Shitter/Views/DiscoveryView.swift`
  - manual default port → `"9234"`
  - ordered port list → `[9234, 8390, 4222]`
- [x] `apps/ios/Sources/Shitter/Views/PreviewSupport.swift`
  - preview fixture ports → `9234`
  - preview fallback target default → `9234`

### 4.2 Android
- [x] `apps/android/core/network/src/main/java/io/latitudes/shitter/android/core/network/ServerDiscoveryService.kt`
  - `CODEX_DISCOVERY_PORTS` → `intArrayOf(9234, 8390, 4222)`
  - local fixture/discovered default port → `9234`
- [x] `apps/android/app/src/main/java/io/latitudes/shitter/android/state/SshSessionManager.kt`
  - `defaultRemotePort` → `9234`
- [x] `apps/android/app/src/main/java/io/latitudes/shitter/android/ui/ShitterAppState.kt`
  - manual CODEX default → `"9234"`
  - CODEX reset path uses `"9234"`
  - keep OpenCode default at `"4096"`

### 4.3 Tests
- [x] `apps/ios/Tests/CodexIOSTests/HomeDashboardSupportTests.swift`
  - update explicit `8390` expectations → `9234`
- [x] `apps/ios/Tests/CodexIOSTests/NetworkDiscoveryTests.swift`
  - update to new default/fallback semantics
- [x] `apps/android/app/src/test/java/io/latitudes/shitter/android/state/ServerConfigPersistenceTest.kt`
  - update persisted default port → `9234`

## Phase 5 — Update Codex submodule + patch compatibility

- [x] **5.1** Update `shared/third_party/codex` to `d37dcca7e`
- [x] **5.2** Re-stage the submodule pointer
- [x] **5.3** Verify `patches/codex/ios-exec-hook.patch` still applies or rebase it if needed
- [x] **5.4** Re-run any Rust bridge builds needed after the submodule bump

## Phase 6 — Regenerate generated artifacts

- [x] **6.1** Regenerate the iOS project from spec:
  ```bash
  xcodegen generate --spec apps/ios/project.yml --project apps/ios/Shitter.xcodeproj
  ```
- [x] **6.2** Rebuild the iOS Rust bridge if the merge or submodule bump changed native inputs:
  ```bash
  ./apps/ios/scripts/build-rust.sh
  ```
- [x] **6.3** Rebuild Android Rust/native artifacts if required:
  ```bash
  ./tools/scripts/build-android-rust.sh
  ```

## Phase 7 — Validation

### 7.1 Branding audit (scoped, low-noise)
- [x] Run first-party branding scan excluding generated/third-party noise:
  ```bash
  rg -n "Litter|litter|com\.litter|com\.sigkitten" \
    . \
    --glob '!.git/**' \
    --glob '!shared/third_party/codex/**' \
    --glob '!apps/**/build/**' \
    --glob '!apps/android/.gradle/**' \
    --glob '!services/push-proxy/bun.lock' \
    --glob '!PLAN-*.md'
  ```
- [x] Confirm no leftover source directories remain:
  ```bash
  find apps/ios -path '*Litter*' -print
  find apps/android -path '*com/litter*' -print
  ```

### 7.2 Port audit (targeted, not global)
- [x] Verify `9234` is the default in the expected first-party files only:
  ```bash
  rg -n '\b(8390|9234)\b' \
    apps/ios/Sources/Shitter \
    apps/ios/Tests/CodexIOSTests \
    apps/android/app/src/main \
    apps/android/app/src/test \
    apps/android/core/network/src/main
  ```
- [x] Confirm `8390` only remains as an explicit backward-compat discovery fallback

### 7.3 Build + test
- [x] iOS build:
  ```bash
  xcodebuild -project apps/ios/Shitter.xcodeproj -scheme Shitter -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  ```
- [x] iOS tests:
  ```bash
  xcodebuild test -project apps/ios/Shitter.xcodeproj -scheme Shitter \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
  ```
- [x] Android build:
  ```bash
  gradle -p apps/android :app:assembleOnDeviceDebug :app:assembleRemoteOnlyDebug
  ```
- [x] Android tests:
  ```bash
  gradle -p apps/android :app:testOnDeviceDebugUnitTest :app:testRemoteOnlyDebugUnitTest
  ```

## Phase 8 — Commit strategy

- [ ] **8.1** Commit the merge + conflict resolution separately from the pure port migration if practical
- [ ] **8.2** Recommended commit split:
  - `merge: sync upstream/main into shitter fork`
  - `feat: move default codex port to 9234 with 8390 fallback`
  - `fix: restore shitter branding after upstream sync` (only if still needed)
- [ ] **8.3** Include evidence in the final note:
  - merge base / branch used
  - submodule status line
  - branding scan result
  - port scan result
  - iOS build/test summary
  - Android build/test summary

---

## Risk areas

| Risk | Mitigation |
|------|------------|
| Upstream regenerates `Litter.xcodeproj` and clobbers our generated project | Treat pbxproj as generated; regenerate final `Shitter.xcodeproj` from `apps/ios/project.yml` |
| Android feature modules reintroduce `com/litter` paths | Explicitly inspect `feature/conversation`, `feature/discovery`, and `feature/sessions` after merge |
| Port change accidentally alters OpenCode defaults | Only change CODEX defaults; keep OpenCode manual default at `4096` |
| Broad grep audits produce false positives | Use targeted path scopes and explicit exclusions |
| Brand assets get overwritten by upstream PNGs | Back up first, restore after merge resolution |
| Submodule patch breaks after bump | Rebase `patches/codex/ios-exec-hook.patch` before final verification |

---

## Exit criteria

- [x] Repo is merged with the 13 upstream commits on top of `rebrand/litter-to-shitter`
- [x] No first-party `Litter` / `com.litter` / `com.sigkitten` regressions remain
- [x] Default Codex port is `9234` on both platforms
- [x] `8390` remains only as a discovery fallback where intended
- [x] Codex submodule is updated and patch-compatible
- [x] iOS build + tests pass
- [x] Android build + tests pass
