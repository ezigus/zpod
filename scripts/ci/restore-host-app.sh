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

pushd "$ARTIFACT_DIR" >/dev/null
if ! shasum -a 256 -c host-app.tar.gz.sha256; then
  echo "❌ Artifact checksum verification failed" >&2
  exit 1
fi
popd >/dev/null

TEMP_DIR=$(mktemp -d)
tar -xzf "$ARTIFACT_DIR/host-app.tar.gz" -C "$TEMP_DIR"

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

echo "✅ Derived data restored to $DERIVED_PATH"
