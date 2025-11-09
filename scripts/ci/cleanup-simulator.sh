#!/usr/bin/env bash

set -euo pipefail

UDID="${1:-}"
DERIVED_PATH="${2:-}"

if [[ -n "$UDID" ]]; then
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl delete "$UDID" >/dev/null 2>&1 || true
fi

if [[ -n "$DERIVED_PATH" && -d "$DERIVED_PATH" ]]; then
  rm -rf "$DERIVED_PATH"
fi
