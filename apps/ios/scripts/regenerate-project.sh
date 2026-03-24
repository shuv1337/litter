#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_DIR/Shitter.xcodeproj"
NESTED_PROJECT="$PROJECT_FILE/Shitter.xcodeproj"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found; install xcodegen first" >&2
  exit 1
fi

if [[ -d "$NESTED_PROJECT" ]]; then
  backup_path="${TMPDIR:-/tmp}/Shitter-nested-xcodeproj-$(date +%Y%m%d-%H%M%S)"
  echo "warning: found nested generated project at $NESTED_PROJECT" >&2
  echo "warning: moving it to $backup_path" >&2
  mv "$NESTED_PROJECT" "$backup_path"
fi

echo "==> Regenerating $PROJECT_FILE"
xcodegen generate --spec "$PROJECT_DIR/project.yml" --project "$PROJECT_DIR"

if [[ -d "$NESTED_PROJECT" ]]; then
  echo "error: nested project still exists at $NESTED_PROJECT" >&2
  exit 1
fi
