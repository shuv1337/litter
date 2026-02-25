#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE_ID="${APP_BUNDLE_ID:-io.latitudes.shitter}"
APP_STORE_APP_ID="${APP_STORE_APP_ID:-}"
INTERNAL_GROUP_NAME="${INTERNAL_GROUP_NAME:-Internal Testers}"

REVIEW_CONTACT_EMAIL="${REVIEW_CONTACT_EMAIL:-}"
REVIEW_CONTACT_FIRST_NAME="${REVIEW_CONTACT_FIRST_NAME:-}"
REVIEW_CONTACT_LAST_NAME="${REVIEW_CONTACT_LAST_NAME:-}"
REVIEW_CONTACT_PHONE="${REVIEW_CONTACT_PHONE:-}"
REVIEW_NOTES="${REVIEW_NOTES:-}"

DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: testflight-setup.sh [options]

Creates or verifies TestFlight internal beta group and optionally updates
beta review contact details.

Options:
  --dry-run       Show what would be done without making API calls
  -h, --help      Show this help message

Environment Variables:
  APP_BUNDLE_ID                   Bundle ID (default: io.latitudes.shitter)
  APP_STORE_APP_ID                App Store Connect app ID (auto-detected if not set)
  INTERNAL_GROUP_NAME             Beta group name (default: Internal Testers)
  REVIEW_CONTACT_EMAIL            Beta review contact email
  REVIEW_CONTACT_FIRST_NAME       Beta review contact first name
  REVIEW_CONTACT_LAST_NAME        Beta review contact last name
  REVIEW_CONTACT_PHONE            Beta review contact phone
  REVIEW_NOTES                    Beta review notes

Examples:
  # Basic setup with auto-detection
  ./testflight-setup.sh

  # Preview what would be done
  ./testflight-setup.sh --dry-run

  # With custom bundle ID
  APP_BUNDLE_ID=io.latitudes.shitter.remote ./testflight-setup.sh
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

require_cmd asc
require_cmd jq

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

if [[ -z "$APP_STORE_APP_ID" ]]; then
    echo "Unable to resolve App Store Connect app id for bundle id: $APP_BUNDLE_ID" >&2
    exit 1
fi

echo "==> Using app id: $APP_STORE_APP_ID"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] Would check for existing beta group: $INTERNAL_GROUP_NAME"
    echo "[dry-run] Would create group if not found"
    group_id="<beta-group-id>"
else
    group_id="$(
        asc testflight beta-groups list --app "$APP_STORE_APP_ID" --output json |
            jq -r --arg name "$INTERNAL_GROUP_NAME" '.data[] | select(.attributes.name == $name) | .id' |
            head -n 1
    )"

    if [[ -z "$group_id" ]]; then
        echo "==> Creating internal TestFlight group: $INTERNAL_GROUP_NAME"
        group_id="$(
            asc testflight beta-groups create --app "$APP_STORE_APP_ID" --name "$INTERNAL_GROUP_NAME" --internal --output json |
                jq -r '.data.id // empty'
        )"
    fi
fi

echo "==> Internal beta group id: $group_id"

if [[ -n "$REVIEW_CONTACT_EMAIL" || -n "$REVIEW_CONTACT_FIRST_NAME" || -n "$REVIEW_CONTACT_LAST_NAME" || -n "$REVIEW_CONTACT_PHONE" || -n "$REVIEW_NOTES" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] Would update TestFlight beta review details:"
        [[ -n "$REVIEW_CONTACT_EMAIL" ]] && echo "  - contact-email: $REVIEW_CONTACT_EMAIL"
        [[ -n "$REVIEW_CONTACT_FIRST_NAME" ]] && echo "  - contact-first-name: $REVIEW_CONTACT_FIRST_NAME"
        [[ -n "$REVIEW_CONTACT_LAST_NAME" ]] && echo "  - contact-last-name: $REVIEW_CONTACT_LAST_NAME"
        [[ -n "$REVIEW_CONTACT_PHONE" ]] && echo "  - contact-phone: $REVIEW_CONTACT_PHONE"
        [[ -n "$REVIEW_NOTES" ]] && echo "  - notes: $REVIEW_NOTES"
    else
        review_id="$(
            asc testflight review get --app "$APP_STORE_APP_ID" --output json |
                jq -r '.data[0].id // empty'
        )"
        if [[ -n "$review_id" ]]; then
            echo "==> Updating TestFlight beta review details"
            cmd=(asc testflight review update --id "$review_id" --output json)
            if [[ -n "$REVIEW_CONTACT_EMAIL" ]]; then
                cmd+=(--contact-email "$REVIEW_CONTACT_EMAIL")
            fi
            if [[ -n "$REVIEW_CONTACT_FIRST_NAME" ]]; then
                cmd+=(--contact-first-name "$REVIEW_CONTACT_FIRST_NAME")
            fi
            if [[ -n "$REVIEW_CONTACT_LAST_NAME" ]]; then
                cmd+=(--contact-last-name "$REVIEW_CONTACT_LAST_NAME")
            fi
            if [[ -n "$REVIEW_CONTACT_PHONE" ]]; then
                cmd+=(--contact-phone "$REVIEW_CONTACT_PHONE")
            fi
            if [[ -n "$REVIEW_NOTES" ]]; then
                cmd+=(--notes "$REVIEW_NOTES")
            fi
            "${cmd[@]}" >/dev/null
        fi
    fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] TestFlight setup validation complete (no changes made)"
else
    echo "==> TestFlight setup complete"
fi
