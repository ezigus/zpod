#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_ROOT}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_ROOT}/lib/common.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_ROOT}/lib/logging.sh"
# shellcheck source=lib/xcode.sh
source "${SCRIPT_ROOT}/lib/xcode.sh"

PREFERRED_SIMULATOR="${1:-iPhone 17 Pro}"
SCHEME_CANDIDATE="${2:-zpod (zpod project)}"
WORKSPACE_PATH="${3:-${REPO_ROOT}/zpod.xcworkspace}"

if ! require_xcodebuild; then
  log_warn "xcodebuild unavailable; defaulting to generic iOS Simulator destination" >&2
  echo "generic/platform=iOS Simulator"
  exit 0
fi

TEMP_OUTPUT="$(mktemp)"
if ! select_destination "${WORKSPACE_PATH}" "${SCHEME_CANDIDATE}" "${PREFERRED_SIMULATOR}" >"$TEMP_OUTPUT" 2>&1; then
  if [[ -s "$TEMP_OUTPUT" ]]; then
    cat "$TEMP_OUTPUT" >&2
  fi
  rm -f "$TEMP_OUTPUT"
  log_warn "Failed to resolve simulator destination; falling back to generic iOS Simulator" >&2
  echo "generic/platform=iOS Simulator"
  exit 0
fi

if [[ -s "$TEMP_OUTPUT" ]]; then
  cat "$TEMP_OUTPUT" >&2
fi
rm -f "$TEMP_OUTPUT"

if [[ -z "${SELECTED_DESTINATION:-}" ]]; then
  log_warn "Simulator destination resolution returned empty result; using generic fallback" >&2
  echo "generic/platform=iOS Simulator"
  exit 0
fi

echo "${SELECTED_DESTINATION}"
