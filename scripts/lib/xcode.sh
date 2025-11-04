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

  # Try the preferred device first, then fall back to newer devices before older ones
  local fallback_devices=(
    "$preferred"
    "iPhone 17 Pro"
    "iPhone 17"
    "iPhone 17 Pro Max"
    "iPhone 16 Pro"
    "iPhone 16 Plus"
    "iPhone 16"
    "iPhone 15 Pro"
    "iPhone 15"
  )

  if command_exists python3; then
    local dest_info
    dest_info=$(PREFERRED_DEVICE="$preferred" python3 -c '
import json
import os
import sys

preferred = os.environ.get("PREFERRED_DEVICE", "")
fallbacks = [name for name in [preferred,
                "iPhone 17 Pro",
                "iPhone 17",
                "iPhone 17 Pro Max",
                "iPhone 16 Pro",
                "iPhone 16 Plus",
                "iPhone 16",
                "iPhone 15 Pro",
                "iPhone 15"] if name]

try:
  data = json.load(sys.stdin)
except Exception:
  sys.exit(0)

devices = data.get("devices", {})
for name in fallbacks:
  for runtime, runtime_devices in devices.items():
    for device in runtime_devices:
      if device.get("name") == name and device.get("isAvailable"):
        runtime_suffix = runtime.rsplit(".", 1)[-1]
        if runtime_suffix.startswith("iOS-"):
          runtime_suffix = runtime_suffix.split("iOS-", 1)[-1]
        runtime_version = runtime_suffix.replace("-", ".")
        print(f"{name}|{runtime_version}")
        sys.exit(0)
sys.exit(0)
' <<<"$simctl_json" 2>/dev/null || true)
    if [[ -n "$dest_info" ]]; then
      local dest_name dest_os
      dest_name="${dest_info%%|*}"
      dest_os="${dest_info##*|}"
      if [[ -n "$dest_name" && -n "$dest_os" && "$dest_name" != "$dest_os" ]]; then
        SELECTED_DESTINATION="platform=iOS Simulator,name=${dest_name},OS=${dest_os}"
        DESTINATION_IS_GENERIC=0
        return 0
      fi
    fi
  fi

  local line name runtime os device
  for device in "${fallback_devices[@]}"; do
    line=""
    name=""
    runtime=""
    os=""
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
            if [[ "$name" == "$device" ]]; then
              SELECTED_DESTINATION="platform=iOS Simulator,name=${name},OS=${os:-18.0}"
              DESTINATION_IS_GENERIC=0
              return 0
            fi
          fi
        fi
        name=""; runtime=""
      fi
    done <<< "$(echo "$simctl_json" | tr ',' '\n')"
  done
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

  if [[ -n "${ZPOD_SIMULATOR_UDID:-}" ]]; then
    local udid="$ZPOD_SIMULATOR_UDID"
    if command_exists xcrun; then
      local device_state
      device_state="$(xcrun simctl list devices -j 2>/dev/null | python3 -c "import json,sys; devices=json.load(sys.stdin).get('devices',{}); print('1' if any(d.get('udid')=='${udid}' and d.get('isAvailable') for runtime in devices.values() for d in runtime) else '')" || true)"
      if [[ -n "$device_state" ]]; then
        SELECTED_DESTINATION="platform=iOS Simulator,id=${udid}"
        DESTINATION_IS_GENERIC=0
        log_info "Using simulator destination from ZPOD_SIMULATOR_UDID: id=${udid}"
        return 0
      else
        log_warn "Requested simulator UDID ${udid} not available; falling back to automatic selection"
      fi
    else
      log_warn "xcrun unavailable while honoring ZPOD_SIMULATOR_UDID; falling back to automatic selection"
    fi
  fi

  if _xcode_simctl_select "$preferred_sim"; then
    log_info "Using simulator destination: ${SELECTED_DESTINATION}"
    return 0
  fi

  local destinations_output
  destinations_output="$(xcodebuild -workspace "$workspace" -scheme "$scheme" -showdestinations | cat || true)"
  local sim_lines
  sim_lines="$(echo "$destinations_output" | grep "platform:iOS Simulator" || true)"

  if echo "$sim_lines" | grep -q "Any iOS Simulator Device"; then
    if ! echo "$sim_lines" | grep -q "OS:"; then
      SELECTED_DESTINATION="generic/platform=iOS Simulator"
      DESTINATION_IS_GENERIC=1
      log_warn "No concrete simulators detected, using generic destination"
      return 0
    fi
  fi

  local line name os
  line="$(echo "$sim_lines" | grep "name:${preferred_sim}" | head -n1 || true)"
  if [[ -n "$line" ]]; then
    name=$(trim "$(echo "$line" | sed -En 's/.*name:([^,}]+).*/\1/p')")
    os=$(trim "$(echo "$line" | sed -En 's/.*OS:([0-9.]+).*/\1/p')")
    if [[ -n "$name" && -n "$os" ]]; then
      SELECTED_DESTINATION="platform=iOS Simulator,name=${name},OS=${os}"
      log_info "Using simulator destination: ${SELECTED_DESTINATION}"
      return 0
    fi
  fi

  line="$(echo "$sim_lines" | grep 'OS:' | head -n1 || true)"
  if [[ -n "$line" ]]; then
    name=$(trim "$(echo "$line" | sed -En 's/.*name:([^,}]+).*/\1/p')")
    os=$(trim "$(echo "$line" | sed -En 's/.*OS:([0-9.]+).*/\1/p')")
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
