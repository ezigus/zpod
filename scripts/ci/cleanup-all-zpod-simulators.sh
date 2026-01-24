#!/usr/bin/env bash

set -euo pipefail

echo "🧹 Cleaning up all zpod-* simulators from previous runs..."

# Get all zpod-* simulators
ZPOD_SIMS=$(xcrun simctl list devices | grep "zpod-" | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' || true)

if [[ -z "$ZPOD_SIMS" ]]; then
  echo "✅ No zpod-* simulators found to clean up"
  exit 0
fi

COUNT=0
while IFS= read -r UDID; do
  if [[ -n "$UDID" ]]; then
    echo "   Deleting simulator: $UDID"
    xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
    xcrun simctl delete "$UDID" >/dev/null 2>&1 || true
    ((COUNT++))
  fi
done <<< "$ZPOD_SIMS"

echo "✅ Cleaned up $COUNT old zpod-* simulator(s)"

# Report current simulator count for monitoring
TOTAL_SIMS=$(xcrun simctl list devices | grep -c "(" || true)
echo "📊 Current total simulator count: $TOTAL_SIMS"
