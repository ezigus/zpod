#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: archive-test-results.sh <artifact-name>" >&2
  exit 1
fi

ARTIFACT_NAME="$1"
TARGET_DIR="artifacts/${ARTIFACT_NAME}"

mkdir -p "$TARGET_DIR"

if ls TestResults >/dev/null 2>&1; then
  find TestResults -maxdepth 1 -mindepth 1 \( -name "TestResults_*.xcresult" -o -name "TestResults_*.log" \) \
    -exec cp -R {} "$TARGET_DIR"/ \;
fi

if ls ~/Library/Logs/DiagnosticReports/*.crash >/dev/null 2>&1; then
  cp ~/Library/Logs/DiagnosticReports/*.crash "$TARGET_DIR"/
fi
