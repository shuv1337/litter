#!/usr/bin/env bash
set -euo pipefail

args=()
for arg in "$@"; do
  case "$arg" in
    -mmacos-version-min=*)
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

exec xcrun clang++ "${args[@]}"
