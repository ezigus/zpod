#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__ZPOD_XCODE_SH:-}" ]]; then
  return 0
fi
__ZPOD_XCODE_SH=1

DESTINATION_IS_GENERIC=0
SELECTED_DESTINATION=""

_xcode_simctl_select() {
  if ! command_exists xcrun; then
    return 1
  fi
  local preferred="$1"
  local simctl_json
  simctl_json="$(xcrun simctl list devices --json 2>/dev/null || true)"
  [[ -z "$simctl_json" ]] && return 1

  local line name runtime os
  while IFS= read -r line; do
    if [[ "$line" =~ "name" ]]; then
      name=$(echo "$line" | sed -En 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')
    fi
    if [[ "$line" =~ "runtime" ]]; then
      runtime=$(echo "$line" | sed -En 's/.*"runtime"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')
    fi
    if [[ "$line" =~ "isAvailable" ]]; then
      if echo "$line" | grep -q 'true'; then
        if [[ -n "$name" && -n "$runtime" ]]; then
          os=$(echo "$runtime" | sed -En 's/.*iOS-([0-9]+(-[0-9]+)*).*/\1/p' | tr '-' '.')
          if [[ "$name" == "$preferred" ]]; then
            SELECTED_DESTINATION="platform=iOS Simulator,name=${name},OS=${os:-18.0}"
            DESTINATION_IS_GENERIC=0
            return 0
          fi
        fi
      fi
      name=""; runtime=""
    fi
  done <<< "$(echo "$simctl_json" | tr ',' '\n')"
  return 1
}

require_xcodebuild() {
  if ! command_exists xcodebuild; then
    log_error "xcodebuild not found. Install Xcode or run the script in fallback (SPM) mode."
    return 1
  fi
  return 0
}

select_destination() {
  local workspace="$1"
  local scheme="$2"
  local preferred_sim="$3"

  DESTINATION_IS_GENERIC=0
  SELECTED_DESTINATION=""

  if _xcode_simctl_select "$preferred_sim"; then
    log_info "Using simulator destination: ${SELECTED_DESTINATION}"
    return 0
  fi

  local destinations_output
  destinations_output="$(xcodebuild -workspace "$workspace" -scheme "$scheme" -showdestinations | cat || true)"
  local sim_lines
  sim_lines="$(echo "$destinations_output" | grep "platform:iOS Simulator" || true)"

  if echo "$sim_lines" | grep -q "Any iOS Simulator Device"; then
    SELECTED_DESTINATION="generic/platform=iOS Simulator"
    DESTINATION_IS_GENERIC=1
    log_warn "No concrete simulators detected, using generic destination"
    return 0
  fi

  local line name os
  line="$(echo "$sim_lines" | grep "name:${preferred_sim}" | head -n1 || true)"
  if [[ -n "$line" ]]; then
    name=$(echo "$line" | sed -En 's/.*name:([^,}]+).*/\1/p')
    os=$(echo "$line" | sed -En 's/.*OS:([0-9.]+).*/\1/p')
    if [[ -n "$name" && -n "$os" ]]; then
      SELECTED_DESTINATION="platform=iOS Simulator,name=${name},OS=${os}"
      log_info "Using simulator destination: ${SELECTED_DESTINATION}"
      return 0
    fi
  fi

  line="$(echo "$sim_lines" | head -n1 || true)"
  if [[ -n "$line" ]]; then
    name=$(echo "$line" | sed -En 's/.*name:([^,}]+).*/\1/p')
    os=$(echo "$line" | sed -En 's/.*OS:([0-9.]+).*/\1/p')
    if [[ -n "$name" && -n "$os" ]]; then
      SELECTED_DESTINATION="platform=iOS Simulator,name=${name},OS=${os}"
      log_warn "Preferred simulator not found. Using ${SELECTED_DESTINATION}"
      return 0
    fi
  fi

  log_warn "No simulators found; falling back to generic destination"
  SELECTED_DESTINATION="generic/platform=iOS Simulator"
  DESTINATION_IS_GENERIC=1
  return 0
}

xcodebuild_wrapper() {
  local -a args=("$@")
  log_info "xcodebuild ${args[*]}"
  xcodebuild "${args[@]}"
}
