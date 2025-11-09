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

if [[ ! -d "$TEMP_DIR/zpod.app" ]]; then
  echo "❌ Extraction failed or incomplete - zpod.app not found" >&2
  rm -rf "$TEMP_DIR"
  exit 1
fi

if [[ ! -f "$TEMP_DIR/zpod.app/zpod" && -f "$TEMP_DIR/zpod.app/zpod.debug.dylib" ]]; then
  ln -sf zpod.debug.dylib "$TEMP_DIR/zpod.app/zpod"
fi

if [[ ! -f "$TEMP_DIR/zpod.app/zpod" ]]; then
  echo "❌ Main binary missing after extraction" >&2
  ls -la "$TEMP_DIR/zpod.app/" || true
  rm -rf "$TEMP_DIR"
  exit 1
fi

HOST_DIR="$DERIVED_PATH/Build/Products/Debug-iphonesimulator"
mkdir -p "$(dirname "$HOST_DIR")"
mv "$TEMP_DIR" "$HOST_DIR"

echo "✅ Host app restored to $HOST_DIR"
