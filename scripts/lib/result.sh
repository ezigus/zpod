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
