#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SCHEME="${SCHEME:-Shitter}"
CONFIGURATION="${CONFIGURATION:-Release}"
PROJECT_DIR="${PROJECT_DIR:-$REPO_DIR}"
PROJECT_PATH="${PROJECT_PATH:-$PROJECT_DIR/Shitter.xcodeproj}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-io.latitudes.shitter}"
APP_STORE_APP_ID="${APP_STORE_APP_ID:-}"
TEAM_ID="${TEAM_ID:-}"
PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_SPECIFIER:-Shitter App Store}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
BETA_GROUP_NAME="${BETA_GROUP_NAME:-Internal Testers}"
ASSIGN_BETA_GROUP="${ASSIGN_BETA_GROUP:-1}"
WAIT_FOR_PROCESSING="${WAIT_FOR_PROCESSING:-0}"
BUILD_POLL_TIMEOUT_SECONDS="${BUILD_POLL_TIMEOUT_SECONDS:-900}"
BUILD_POLL_INTERVAL_SECONDS="${BUILD_POLL_INTERVAL_SECONDS:-15}"
WHAT_TO_TEST="${WHAT_TO_TEST:-}"
WHAT_TO_TEST_LOCALE="${WHAT_TO_TEST_LOCALE:-en-US}"

AUTH_KEY_PATH="${AUTH_KEY_PATH:-${ASC_PRIVATE_KEY_PATH:-}}"
AUTH_KEY_ID="${AUTH_KEY_ID:-${ASC_KEY_ID:-}}"
AUTH_ISSUER_ID="${AUTH_ISSUER_ID:-${ASC_ISSUER_ID:-}}"

BUILD_DIR="${BUILD_DIR:-$REPO_DIR/build/testflight}"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"
IPA_PATH="$BUILD_DIR/$SCHEME.ipa"

DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: testflight-upload.sh [options]

Archives the iOS app, exports an IPA, and uploads to TestFlight.

Options:
  --dry-run       Show what would be done without building or uploading
  -h, --help      Show this help message

Environment Variables:
  SCHEME                          Xcode scheme (default: Shitter)
  CONFIGURATION                   Build configuration (default: Release)
  PROJECT_DIR                     Directory containing xcodeproj (default: apps/ios)
  PROJECT_PATH                    Path to xcodeproj (default: $PROJECT_DIR/Shitter.xcodeproj)
  APP_BUNDLE_ID                   Bundle ID (default: io.latitudes.shitter)
  APP_STORE_APP_ID                App Store Connect app ID (auto-detected)
  TEAM_ID                         Development team ID (auto-detected)
  PROVISIONING_PROFILE_SPECIFIER  Provisioning profile name (default: Shitter App Store)
  MARKETING_VERSION               Marketing version (default: 1.0.0)
  BUILD_NUMBER                    Build number (auto-incremented if not set)
  BETA_GROUP_NAME                 Beta group to assign build to (default: Internal Testers)
  ASSIGN_BETA_GROUP               Assign build to beta group (default: 1)
  WAIT_FOR_PROCESSING             Wait for App Store processing (default: 0)
  WHAT_TO_TEST                    Test notes for testers
  AUTH_KEY_PATH                   Path to App Store Connect API key
  AUTH_KEY_ID                     App Store Connect API key ID
  AUTH_ISSUER_ID                  App Store Connect API issuer ID

Examples:
  # Basic upload
  ./testflight-upload.sh

  # Preview what would be done
  ./testflight-upload.sh --dry-run

  # Custom version and build
  MARKETING_VERSION=2.0.0 BUILD_NUMBER=100 ./testflight-upload.sh
EOF
}

while [ "${1:-}" != "" ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

if [[ "$DRY_RUN" -eq 0 ]]; then
    require_cmd asc
    require_cmd jq
    require_cmd xcodebuild
    require_cmd xcodegen
fi

mkdir -p "$BUILD_DIR"

if [[ -z "$APP_STORE_APP_ID" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] Would resolve App Store Connect app ID for bundle: $APP_BUNDLE_ID"
        APP_STORE_APP_ID="<resolved-app-id>"
    else
        APP_STORE_APP_ID="$(
            asc apps list --bundle-id "$APP_BUNDLE_ID" --output json |
                jq -r '.data[0].id // empty'
        )"
    fi
fi

if [[ -z "$TEAM_ID" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] Would detect DEVELOPMENT_TEAM from project"
        TEAM_ID="<detected-team-id>"
    else
        TEAM_ID="$(
            xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings |
                awk -F' = ' '/ DEVELOPMENT_TEAM = / {print $2; exit}'
        )"
    fi
fi

if [[ -z "$APP_STORE_APP_ID" ]]; then
    echo "Unable to resolve App Store Connect app id for bundle id: $APP_BUNDLE_ID" >&2
    exit 1
fi

if [[ -z "$BUILD_NUMBER" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] Would fetch latest build number and increment"
        BUILD_NUMBER="<auto-incremented>"
    else
        latest_build="$(
            asc builds list --app "$APP_STORE_APP_ID" --limit 1 --sort "-uploadedDate" --output json |
                jq -r '.data[0].attributes.version // empty'
        )"
        if [[ "$latest_build" =~ ^[0-9]+$ ]]; then
            BUILD_NUMBER="$((latest_build + 1))"
        else
            BUILD_NUMBER="$(date +%Y%m%d%H%M)"
        fi
    fi
fi

echo "==> Regenerating Xcode project"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] Would run: xcodegen generate --spec $REPO_DIR/project.yml --project $PROJECT_PATH"
else
    xcodegen generate --spec "$REPO_DIR/project.yml" --project "$PROJECT_PATH"
fi

echo "==> Archiving $SCHEME ($MARKETING_VERSION/$BUILD_NUMBER)"
archive_cmd=(
    xcodebuild
    -project "$PROJECT_PATH"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "generic/platform=iOS"
    -archivePath "$ARCHIVE_PATH"
    -allowProvisioningUpdates
    clean archive
    MARKETING_VERSION="$MARKETING_VERSION"
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)

if [[ -n "$TEAM_ID" ]]; then
    archive_cmd+=(DEVELOPMENT_TEAM="$TEAM_ID")
fi

if [[ -n "$AUTH_KEY_PATH" && -n "$AUTH_KEY_ID" && -n "$AUTH_ISSUER_ID" ]]; then
    archive_cmd+=(
        -authenticationKeyPath "$AUTH_KEY_PATH"
        -authenticationKeyID "$AUTH_KEY_ID"
        -authenticationKeyIssuerID "$AUTH_ISSUER_ID"
    )
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] Would run: ${archive_cmd[*]}"
else
    "${archive_cmd[@]}"
fi

echo "==> Creating ExportOptions.plist"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] Would create $EXPORT_OPTIONS_PLIST with:"
    echo "  - method: app-store-connect"
    echo "  - teamID: $TEAM_ID"
    echo "  - provisioningProfiles[$APP_BUNDLE_ID]: $PROVISIONING_PROFILE_SPECIFIER"
else
    cat >"$EXPORT_OPTIONS_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

    if [[ -n "$TEAM_ID" ]]; then
        /usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$EXPORT_OPTIONS_PLIST"
    fi
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$EXPORT_OPTIONS_PLIST"
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$APP_BUNDLE_ID string $PROVISIONING_PROFILE_SPECIFIER" "$EXPORT_OPTIONS_PLIST"
fi

echo "==> Exporting IPA"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] Would run: xcodebuild -exportArchive -archivePath $ARCHIVE_PATH -exportPath $BUILD_DIR -exportOptionsPlist $EXPORT_OPTIONS_PLIST"
    exported_ipa="$IPA_PATH"
else
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$BUILD_DIR" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

    exported_ipa="$(find "$BUILD_DIR" -maxdepth 1 -name "*.ipa" | head -n 1)"
    if [[ -z "$exported_ipa" ]]; then
        echo "No IPA produced in $BUILD_DIR" >&2
        exit 1
    fi
    if [[ "$exported_ipa" != "$IPA_PATH" ]]; then
        cp "$exported_ipa" "$IPA_PATH"
    fi
fi

echo "==> Uploading IPA to App Store Connect (app: $APP_STORE_APP_ID)"
upload_cmd=(
    asc builds upload
    --app "$APP_STORE_APP_ID"
    --ipa "$IPA_PATH"
    --version "$MARKETING_VERSION"
    --build-number "$BUILD_NUMBER"
    --output json
)
if [[ "$WAIT_FOR_PROCESSING" == "1" ]]; then
    upload_cmd+=(--wait)
fi
if [[ "$WAIT_FOR_PROCESSING" == "1" && -n "$WHAT_TO_TEST" ]]; then
    upload_cmd+=(--test-notes "$WHAT_TO_TEST" --locale "$WHAT_TO_TEST_LOCALE")
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] Would run: ${upload_cmd[*]}"
    build_id="<uploaded-build-id>"
else
    upload_json="$("${upload_cmd[@]}")"
    echo "$upload_json" >"$BUILD_DIR/upload_result.json"

    build_id="$(
        echo "$upload_json" |
            jq -r '.data.id // .data[0].id // empty'
    )"
    if [[ -z "$build_id" ]]; then
        build_id="$(
            asc builds list --app "$APP_STORE_APP_ID" --limit 20 --sort "-uploadedDate" --output json |
                jq -r --arg num "$BUILD_NUMBER" '.data[] | select(.attributes.version == $num) | .id' |
                head -n 1
        )"
    fi

    if [[ -z "$build_id" && "$ASSIGN_BETA_GROUP" == "1" ]]; then
        deadline="$(( $(date +%s) + BUILD_POLL_TIMEOUT_SECONDS ))"
        while [[ -z "$build_id" && "$(date +%s)" -lt "$deadline" ]]; do
            sleep "$BUILD_POLL_INTERVAL_SECONDS"
            build_id="$(
                asc builds list --app "$APP_STORE_APP_ID" --limit 50 --sort "-uploadedDate" --output json |
                    jq -r --arg num "$BUILD_NUMBER" '.data[] | select(.attributes.version == $num) | .id' |
                    head -n 1
            )"
        done
    fi
fi

if [[ "$ASSIGN_BETA_GROUP" == "1" && -n "$build_id" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] Would assign build to beta group: $BETA_GROUP_NAME"
    else
        beta_group_id="$(
            asc testflight beta-groups list --app "$APP_STORE_APP_ID" --output json |
                jq -r --arg name "$BETA_GROUP_NAME" '.data[] | select(.attributes.name == $name) | .id' |
                head -n 1
        )"

        if [[ -z "$beta_group_id" ]]; then
            beta_group_id="$(
                asc testflight beta-groups create --app "$APP_STORE_APP_ID" --name "$BETA_GROUP_NAME" --internal --output json |
                    jq -r '.data.id // empty'
            )"
        fi

        if [[ -n "$beta_group_id" ]]; then
            echo "==> Assigning build $build_id to beta group '$BETA_GROUP_NAME'"
            asc builds add-groups --build "$build_id" --group "$beta_group_id" --output json >/dev/null
        fi
    fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] TestFlight upload validation complete (no changes made)"
    echo "    App ID:      $APP_STORE_APP_ID"
    echo "    Scheme:      $SCHEME"
    echo "    Version:     $MARKETING_VERSION"
    echo "    Build:       $BUILD_NUMBER"
else
    echo "==> TestFlight upload complete"
    echo "    App ID:      $APP_STORE_APP_ID"
    echo "    Scheme:      $SCHEME"
    echo "    Version:     $MARKETING_VERSION"
    echo "    Build:       $BUILD_NUMBER"
    echo "    IPA:         $IPA_PATH"
    if [[ -n "${build_id:-}" ]]; then
        echo "    Build record: $build_id"
    fi
fi
