#!/usr/bin/env bash

set -euo pipefail

UDID="${1:-}"
DERIVED_PATH="${2:-}"

if [[ -n "$UDID" ]]; then
  echo "🧹 Cleaning up simulator: $UDID"
  if xcrun simctl shutdown "$UDID" 2>&1 | grep -v "Unable to shutdown device in current state"; then
    echo "   Shutdown completed"
  fi
  if xcrun simctl delete "$UDID" 2>&1; then
    echo "   ✅ Deleted simulator: $UDID"
  else
    echo "   ⚠️ Failed to delete simulator (may already be gone): $UDID"
  fi
fi

if [[ -n "$DERIVED_PATH" && -d "$DERIVED_PATH" ]]; then
  echo "🧹 Removing derived data: $DERIVED_PATH"
  rm -rf "$DERIVED_PATH"
  echo "   ✅ Removed derived data"
fi

if [[ -z "$UDID" && -z "$DERIVED_PATH" ]]; then
  echo "ℹ️  No simulator or derived data to clean up"
fi
