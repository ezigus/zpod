#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__ZPOD_RESULT_SH:-}" ]]; then
  return 0
fi
__ZPOD_RESULT_SH=1

RESULTS_DIR="${REPO_ROOT}/TestResults"
mkdir -p "$RESULTS_DIR"

init_result_paths() {
  local operation="$1"
  local target="${2:-}"
  local stamp
  stamp="$(current_timestamp)"
  local suffix=""
  if [[ -n "$target" ]]; then
    # Remove spaces/slashes for filenames
    suffix="_${target//[\ \/]/-}"
  fi
  RESULT_BUNDLE="${RESULTS_DIR}/TestResults_${stamp}_${operation}${suffix}.xcresult"
  RESULT_LOG="${RESULTS_DIR}/TestResults_${stamp}_${operation}${suffix}.log"
  export RESULT_BUNDLE RESULT_LOG
}

xcresult_has_failures() {
  local bundle="$1"
  if [[ ! -d "$bundle" ]]; then
    return 2
  fi

  if ! command_exists python3 || ! command_exists xcrun; then
    return 3
  fi

  local failure_count
  if ! failure_count=$(xcrun xcresulttool get --legacy --path "$bundle" --format json 2>/dev/null | \
    python3 - <<'PY'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    print("parse_error", end="")
    raise SystemExit(2)

issues = data.get("issues", {})
failures = issues.get("testFailureSummaries", {})
values = failures.get("_values")
if not isinstance(values, list):
    values = []
print(len(values), end="")
PY
  ); then
    return 3
  fi

  if [[ "$failure_count" == "parse_error" ]]; then
    return 3
  fi

  if [[ -z "$failure_count" ]]; then
    return 3
  fi

  if (( failure_count > 0 )); then
    return 0
  fi
  return 1
}
