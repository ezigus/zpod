#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: restore-host-app.sh <derived-data-path> <artifact-dir>" >&2
  exit 1
fi

DERIVED_PATH="$1"
ARTIFACT_DIR="$2"

if [[ ! -d "$ARTIFACT_DIR" ]]; then
  echo "❌ Artifact directory '$ARTIFACT_DIR' not found" >&2
  exit 1
fi

CHECKSUM_FILE="$ARTIFACT_DIR/host-app.tar.gz.sha256"
ARCHIVE_FILE="$ARTIFACT_DIR/host-app.tar.gz"
ARTIFACT_ROOT="$ARTIFACT_DIR"

if [[ ! -f "$CHECKSUM_FILE" || ! -f "$ARCHIVE_FILE" ]]; then
  if [[ -f "$ARTIFACT_DIR/artifacts/host-app.tar.gz.sha256" && -f "$ARTIFACT_DIR/artifacts/host-app.tar.gz" ]]; then
    CHECKSUM_FILE="$ARTIFACT_DIR/artifacts/host-app.tar.gz.sha256"
    ARCHIVE_FILE="$ARTIFACT_DIR/artifacts/host-app.tar.gz"
    ARTIFACT_ROOT="$ARTIFACT_DIR/artifacts"
  else
    echo "❌ Host app artifacts not found in '$ARTIFACT_DIR'" >&2
    exit 1
  fi
fi

pushd "$ARTIFACT_ROOT" >/dev/null
if ! shasum -a 256 -c "$(basename "$CHECKSUM_FILE")"; then
  echo "❌ Artifact checksum verification failed" >&2
  exit 1
fi
popd >/dev/null

TEMP_DIR=$(mktemp -d)
tar -xzf "$ARCHIVE_FILE" -C "$TEMP_DIR"

PARENT_DIR=$(dirname "$DERIVED_PATH")
mkdir -p "$PARENT_DIR"
rm -rf "$DERIVED_PATH"
mkdir -p "$DERIVED_PATH"

shopt -s dotglob
mv "$TEMP_DIR"/* "$DERIVED_PATH"/
shopt -u dotglob
rm -rf "$TEMP_DIR"

HOST_DIR="$DERIVED_PATH/Build/Products/Debug-iphonesimulator"

if [[ ! -d "$HOST_DIR/zpod.app" ]]; then
  echo "❌ Restored derived data missing zpod.app at $HOST_DIR/zpod.app" >&2
  exit 1
fi

if [[ ! -f "$HOST_DIR/zpod.app/zpod" && -f "$HOST_DIR/zpod.app/zpod.debug.dylib" ]]; then
  ln -sf zpod.debug.dylib "$HOST_DIR/zpod.app/zpod"
fi

if [[ ! -f "$HOST_DIR/zpod.app/zpod" ]]; then
  echo "❌ Main binary missing after restoration" >&2
  ls -la "$HOST_DIR/zpod.app/" || true
  exit 1
fi

# Verify .xctestrun files exist (required for test-without-building)
XCTESTRUN_COUNT=$(find "$DERIVED_PATH" -name "*.xctestrun" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$XCTESTRUN_COUNT" -eq 0 ]]; then
  echo "❌ ERROR: No .xctestrun files found after restoration!" >&2
  echo "   test-without-building requires these files." >&2
  echo "   Contents of DerivedData:" >&2
  ls -la "$DERIVED_PATH" || true
  exit 1
fi
echo "✅ Found $XCTESTRUN_COUNT .xctestrun file(s)"

echo "✅ Derived data restored to $DERIVED_PATH"
