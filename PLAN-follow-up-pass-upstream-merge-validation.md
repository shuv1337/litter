# PLAN: Follow-up Pass After Upstream Merge (Build-Tool Machine)

## Context

This plan is for validating merge commit **`f85a880`** (`merge: sync upstream/main and preserve shitter branding`) on a machine that has full mobile build tooling installed (Android SDK/NDK + Xcode/xcodegen).

Primary goals:
1. Confirm the app still builds/tests on iOS + Android after upstream sync.
2. Confirm fork branding (`Shitter`, `io.latitudes.shitter*`) is preserved everywhere relevant.
3. Confirm release/packaging workflows are still functional.
4. Capture any regressions and patch them in follow-up commits.

---

## Phase 0 — Environment and repo prep

- [x] Checkout branch:
  ```bash
  git checkout rebrand/litter-to-shitter
  git pull --ff-only
  ```
- [x] Verify merge commit is present:
  ```bash
  git log --oneline --decorate -n 5
  ```
  Expect to see `f85a880`.

- [x] Sync submodules exactly:
  ```bash
  git submodule sync --recursive
  git submodule update --init --recursive
  git submodule status
  ```
  Expect `shared/third_party/codex` at `8159f05dfd1e2ce70a9dbc043fbbfe1da8782860`.

- [x] Ensure local prerequisites:
  - Android: JDK (Homebrew `openjdk@21`) + SDK (`/opt/homebrew/share/android-commandlinetools`) configured via env vars ✅
  - iOS: Xcode, command line tools, `xcodegen` ✅
  - Rust targets for iOS bridge builds ✅

---

## Phase 1 — Branding and path integrity audit

- [x] Run strict branding scan (exclude third-party and this plan):
  ```bash
  rg -n "litter|Litter|com\.litter|com\.sigkitten|Sources/Litter|Litter\.xcodeproj" \
    --glob '!.git/*' \
    --glob '!shared/third_party/codex/**' \
    --glob '!PLAN-rename-litter-to-shitter.md' \
    --glob '!PLAN-follow-up-pass-upstream-merge-validation.md'
  ```
  Expected: **no results** in first-party app code/docs/config.

- [x] Validate key identity files:
  - `apps/android/app/build.gradle.kts` uses `io.latitudes.shitter.android`
  - `apps/android/app/src/main/AndroidManifest.xml` component names use `io.latitudes.shitter.android.*`
  - `apps/ios/project.yml` has:
    - project/targets/schemes named `Shitter*`
    - bundle identifiers `io.latitudes.shitter` and `io.latitudes.shitter.remote`
  - `README.md` has only Shitter branding

- [x] Validate no stale Litter directories remain (except explicit historical artifacts if any):
  ```bash
  find . -path './.git' -prune -o -iname '*litter*' -print
  ```

---

## Phase 2 — Android validation

- [x] Confirm SDK wiring:
  ```bash
  cat apps/android/local.properties
  ```
  or confirm `ANDROID_HOME` is set.
  - Result: `apps/android/local.properties` missing, but validation was run with:
    - `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`
    - `ANDROID_HOME=/opt/homebrew/share/android-commandlinetools`
    - `ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools`

- [x] Run unit tests:
  ```bash
  ./apps/android/gradlew -p apps/android :app:testOnDeviceDebugUnitTest :app:testRemoteOnlyDebugUnitTest
  ```

- [x] Build both debug flavors:
  ```bash
  ./apps/android/gradlew -p apps/android :app:assembleOnDeviceDebug :app:assembleRemoteOnlyDebug
  ```

- [x] Optional lint pass:
  ```bash
  ./apps/android/gradlew -p apps/android :app:lintOnDeviceDebug :app:lintRemoteOnlyDebug
  ```

- [ ] Optional emulator smoke test:
  1. Install APK.
  2. Launch app.
  3. Verify app label, theme text, login/discovery/sessions flows, and no crash-on-start.
  - Skipped due Android build blocker.

- [x] Capture build outputs and any failures in notes.

---

## Phase 3 — iOS validation

- [x] Regenerate project from spec:
  ```bash
  xcodegen generate --spec apps/ios/project.yml --project apps/ios
  ```

- [x] Ensure required iOS frameworks are present:
  ```bash
  ./apps/ios/scripts/download-ios-system.sh
  ```

- [x] Build Rust bridge artifacts:
  ```bash
  ./apps/ios/scripts/build-rust.sh
  ```

- [x] CLI build both schemes:
  ```bash
  xcodebuild -project apps/ios/Shitter.xcodeproj -scheme ShitterRemote -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  xcodebuild -project apps/ios/Shitter.xcodeproj -scheme Shitter -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  ```

- [x] Run iOS tests:
  ```bash
  xcodebuild test -project apps/ios/Shitter.xcodeproj -scheme Shitter -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
  ```

- [ ] Manual smoke test in simulator:
  - App launches
  - Brand/logo/text are Shitter
  - Discovery and server connect sheet render correctly
  - Conversation/session sidebar flows work
  - Not executed in this CLI pass (requires interactive simulator validation).

---

## Phase 4 — Release workflow sanity checks

- [x] Android release helper scripts sanity:
  - `apps/android/scripts/download-bundled-assets.sh`
  - `apps/android/scripts/play-upload.sh` (dry-run or argument validation if available)

- [x] iOS TestFlight script sanity:
  ```bash
  bash -n apps/ios/scripts/testflight-upload.sh
  ```
  Confirm defaults align with Shitter bundle IDs/schemes.

- [x] Confirm docs checklists are branded and still accurate:
  - `docs/releases/android-play-internal-checklist.md`
  - `docs/releases/ios-testflight-checklist.md`
  - `docs/releases/testflight-whats-new.md`

---

## Phase 5 — Regression triage and patching

If failures are found:

- [x] Create targeted fixes (small atomic commits).
- [x] Re-run only impacted validation steps first, then full phase gate.
- [x] Keep branding invariants intact after every fix.

Suggested commit pattern:
- `fix(android): <issue>`
- `fix(ios): <issue>`
- `docs(release): <issue>`

### Execution notes (2026-03-03)

- iOS regression found + fixed: `Unable to find module dependency: Highlightr` in `CodeBlockView.swift` due stale/generated project state.
- Applied fix by regenerating `apps/ios/Shitter.xcodeproj` from `apps/ios/project.yml` and re-running iOS build/test commands.
- Android release env var branding follow-up:
  - Added `SHITTER_*` primary variables with `LITTER_*` backward-compat fallback in `apps/android/app/build.gradle.kts` and `apps/android/scripts/play-upload.sh`.
  - Updated `docs/releases/android-play-internal-checklist.md` accordingly.
- Android validation now runs successfully when JAVA_HOME/ANDROID_HOME/ANDROID_SDK_ROOT are set to local Homebrew SDK paths.
- Lint follow-up fixes:
  - `ServerManager.kt`: replaced API-33 `URLDecoder.decode(String, Charset)` overload with backward-compatible `decode(String, charset.name())`.
  - `BundledCodexService.kt`: fixed `SuspiciousIndentation` lint error around terminator matching block.

---

## Exit criteria (Definition of Done)

- [x] No unresolved branding regressions (`Litter`/`com.litter`/`com.sigkitten`) in first-party code/docs. (legacy `LITTER_*` env var aliases intentionally retained for compatibility)
- [x] Android unit tests and debug assemblies pass.
- [x] iOS project generation + both scheme builds pass.
- [x] iOS tests pass.
- [ ] Manual smoke checks pass on simulator/emulator.
- [ ] Any follow-up fixes are committed and pushed.

---

## Suggested evidence bundle

Capture and paste into PR/hand-off note:

1. `git rev-parse --short HEAD`
2. Submodule status line for `shared/third_party/codex`
3. Android test/build command outputs (or summary + failure snippets)
4. iOS build/test command outputs (or summary + failure snippets)
5. Branding scan result (`no matches`)
6. Screenshots (optional) for app launch + main shell on both platforms
