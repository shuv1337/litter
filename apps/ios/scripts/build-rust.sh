#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$IOS_DIR/../.." && pwd)"
BRIDGE_DIR="$REPO_DIR/shared/rust-bridge/codex-bridge"
FRAMEWORKS_DIR="$IOS_DIR/Frameworks"
SUBMODULE_DIR="$REPO_DIR/shared/third_party/codex"
PATCH_FILE="$REPO_DIR/patches/codex/ios-exec-hook.patch"

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

PATCH_WAS_APPLIED=0
if git -C "$SUBMODULE_DIR" apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
  PATCH_WAS_APPLIED=1
fi

cleanup_patch() {
  if [ "$PATCH_WAS_APPLIED" -eq 0 ] && git -C "$SUBMODULE_DIR" apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
    echo "==> Restoring clean codex submodule worktree..."
    git -C "$SUBMODULE_DIR" apply --reverse "$PATCH_FILE"
  fi
}

trap cleanup_patch EXIT

mkdir -p "$FRAMEWORKS_DIR"

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
