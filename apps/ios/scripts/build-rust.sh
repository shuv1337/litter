#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$IOS_DIR/../.." && pwd)"
BRIDGE_DIR="$REPO_DIR/shared/rust-bridge/codex-bridge"
FRAMEWORKS_DIR="$IOS_DIR/Frameworks"
SUBMODULE_DIR="$REPO_DIR/shared/third_party/codex"
IOS_CLANGXX_WRAPPER="$SCRIPT_DIR/ios-clangxx-wrapper.sh"
PATCH_FILES=(
  "$REPO_DIR/patches/codex/ios-exec-hook.patch"
  "$REPO_DIR/patches/codex/realtime-transcript-deltas.patch"
  "$REPO_DIR/patches/codex/client-controlled-handoff.patch"
)

SYNC_MODE="--preserve-current"
BUILD_INTEL_SIM=0
for arg in "$@"; do
  case "$arg" in
    --preserve-current|--recorded-gitlink)
      SYNC_MODE="$arg"
      ;;
    --with-intel-sim)
      BUILD_INTEL_SIM=1
      ;;
    *)
      echo "usage: $(basename "$0") [--preserve-current|--recorded-gitlink] [--with-intel-sim]" >&2
      exit 1
      ;;
  esac
done

PATCHES_WERE_APPLIED=()
for PATCH_FILE in "${PATCH_FILES[@]}"; do
  if git -C "$SUBMODULE_DIR" apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
    PATCHES_WERE_APPLIED+=("$PATCH_FILE")
  fi
done

cleanup_patch() {
  for PATCH_FILE in "${PATCH_FILES[@]}"; do
    local was_pre_applied=0
    for pre in "${PATCHES_WERE_APPLIED[@]+"${PATCHES_WERE_APPLIED[@]}"}"; do
      if [ "$pre" = "$PATCH_FILE" ]; then
        was_pre_applied=1
        break
      fi
    done
    if [ "$was_pre_applied" -eq 0 ] && git -C "$SUBMODULE_DIR" apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
      echo "==> Reverting $(basename "$PATCH_FILE")..."
      git -C "$SUBMODULE_DIR" apply --reverse "$PATCH_FILE"
    fi
  done
}

trap cleanup_patch EXIT

mkdir -p "$FRAMEWORKS_DIR"

for tool in meson ninja; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool is required for webrtc-audio-processing bundled builds" >&2
    exit 1
  fi
done

if ! rustup component list --installed | grep -q '^llvm-tools'; then
  echo "error: llvm-tools is required for rust-objcopy during webrtc-audio-processing builds" >&2
  echo "run: rustup component add llvm-tools" >&2
  exit 1
fi

export CXX_aarch64_apple_ios="$IOS_CLANGXX_WRAPPER"
export CXX_aarch64_apple_ios_sim="$IOS_CLANGXX_WRAPPER"
export CXX_x86_64_apple_ios="$IOS_CLANGXX_WRAPPER"

echo "==> Preparing codex submodule..."
"$SCRIPT_DIR/sync-codex.sh" "$SYNC_MODE"

cd "$BRIDGE_DIR"

echo "==> Installing iOS targets..."
if [ "$BUILD_INTEL_SIM" -eq 1 ]; then
  rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
else
  rustup target add aarch64-apple-ios aarch64-apple-ios-sim
fi

echo "==> Building for aarch64-apple-ios (device)..."
cargo rustc --release --target aarch64-apple-ios --crate-type staticlib

echo "==> Building for aarch64-apple-ios-sim (Apple Silicon simulator)..."
cargo rustc --release --target aarch64-apple-ios-sim --crate-type staticlib

SIMULATOR_LIB="target/aarch64-apple-ios-sim/release/libcodex_bridge.a"
if [ "$BUILD_INTEL_SIM" -eq 1 ]; then
  echo "==> Building for x86_64-apple-ios (Intel simulator)..."
  cargo rustc --release --target x86_64-apple-ios --crate-type staticlib

  echo "==> Creating fat simulator lib..."
  mkdir -p target/ios-sim-fat/release
  lipo -create \
    target/aarch64-apple-ios-sim/release/libcodex_bridge.a \
    target/x86_64-apple-ios/release/libcodex_bridge.a \
    -output target/ios-sim-fat/release/libcodex_bridge.a
  SIMULATOR_LIB="target/ios-sim-fat/release/libcodex_bridge.a"
fi

echo "==> Creating xcframework..."
rm -rf "$FRAMEWORKS_DIR/codex_bridge.xcframework"
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libcodex_bridge.a \
  -headers include/ \
  -library "$SIMULATOR_LIB" \
  -headers include/ \
  -output "$FRAMEWORKS_DIR/codex_bridge.xcframework"

echo "==> Done: $FRAMEWORKS_DIR/codex_bridge.xcframework"
