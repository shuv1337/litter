#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$SCRIPT_DIR/../Frameworks/ios_system}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sanitize_libssh2_xcframework() {
    local xcframework="$DEST/libssh2.xcframework"
    local source_variant="$xcframework/ios-arm64_arm64e"
    local source_framework="$source_variant/libssh2.framework"
    local source_binary="$source_framework/libssh2"
    local dest_variant="$xcframework/ios-arm64"
    local dest_framework="$dest_variant/libssh2.framework"
    local dest_binary="$dest_framework/libssh2"
    local framework_plist="$dest_framework/Info.plist"
    local root_plist="$xcframework/Info.plist"
    local root_json="$TMP/libssh2-root.json"
    local root_json_updated="$TMP/libssh2-root-updated.json"
    local stripped_binary="$TMP/libssh2-arm64"
    local minos

    [[ -d "$source_framework" ]] || return 0
    [[ -f "$source_binary" ]] || return 0

    rm -rf "$dest_variant"
    mkdir -p "$dest_variant"
    cp -R "$source_framework" "$dest_framework"

    if lipo -archs "$dest_binary" | tr ' ' '\n' | grep -qx 'arm64e'; then
        lipo "$dest_binary" -remove arm64e -output "$stripped_binary"
        mv "$stripped_binary" "$dest_binary"
        chmod 755 "$dest_binary"
    fi

    minos="$(
        xcrun vtool -show-build "$dest_binary" 2>/dev/null |
            awk '/architecture arm64/{seen=1} seen && /minos /{print $2; exit}'
    )"
    minos="${minos:-14.0}"

    plutil -replace MinimumOSVersion -string "$minos" "$framework_plist" 2>/dev/null ||
        plutil -insert MinimumOSVersion -string "$minos" "$framework_plist"

    plutil -convert json -o "$root_json" "$root_plist"
    jq '
        .AvailableLibraries |= map(
            if .LibraryIdentifier == "ios-arm64_arm64e" then
                .LibraryIdentifier = "ios-arm64"
                | .SupportedArchitectures = ["arm64"]
            else
                .
            end
        )
    ' "$root_json" >"$root_json_updated"
    plutil -convert xml1 -o "$root_plist" "$root_json_updated"

    rm -rf "$source_variant"

    echo "==> Sanitized libssh2.xcframework for App Store distribution"
}

sanitize_libssh2_xcframework
