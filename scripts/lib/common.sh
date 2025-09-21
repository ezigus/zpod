#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__ZPOD_COMMON_SH:-}" ]]; then
  return 0
fi
__ZPOD_COMMON_SH=1

# shellcheck disable=SC2034
REPO_ROOT="${REPO_ROOT:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
if [[ -z "$REPO_ROOT" ]]; then
  if command -v git >/dev/null 2>&1; then
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  fi
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_command() {
  local cmd="$1"
  local hint="${2:-}"
  if ! command_exists "$cmd"; then
    if [[ -n "$hint" ]]; then
      log_error "$cmd not found. $hint"
    else
      log_error "$cmd not found in PATH"
    fi
    return 1
  fi
  return 0
}

split_csv() {
  local input="$1"
  local IFS=','
  read -r -a __ZPOD_SPLIT_RESULT <<< "$input"
}

trim() {
  local value="$1"
  # shellcheck disable=SC2001
  echo "$value" | sed 's/^ *//;s/ *$//'
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

is_ci() {
  [[ -n "${CI:-}" ]]
}

# Format timestamps for result files
current_timestamp() {
  date +%Y%m%d_%H%M%S
}

absolute_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd)
  else
    local dir
    dir=$(dirname "$path")
    local base
    base=$(basename "$path")
    (cd "$dir" && printf "%s/%s\n" "$(pwd)" "$base")
  fi
}
