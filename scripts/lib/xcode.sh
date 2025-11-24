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

_destination_supported_for_scheme() {
  local destination="$1"
  local destinations_output="$2"

  if [[ -z "$destination" || -z "$destinations_output" ]]; then
    return 1
  fi

  if [[ "$destination" == *"id="* ]]; then
    local id="${destination#*id=}"
    id="${id%%,*}"
    if echo "$destinations_output" | grep -F "id:${id}" >/dev/null; then
      return 0
    fi
    return 1
  fi

  local name="${destination#*name=}"
  name="${name%%,*}"
  local os="${destination#*,OS=}"
  os="${os%%,*}"

  if [[ -z "$name" || -z "$os" ]]; then
    return 1
  fi

  local line
  while IFS= read -r line; do
    if echo "$line" | grep -F "name:${name}" >/dev/null && echo "$line" | grep -F "OS:${os}" >/dev/null; then
      return 0
    fi
  done <<< "$(echo "$destinations_output" | grep "platform:iOS Simulator" || true)"

  return 1
}

_extract_name_from_destination_line() {
  local line="$1"
  trim "$(echo "$line" | sed -En 's/.*name:([^,}]+).*/\1/p')"
}

_extract_os_from_destination_line() {
  local line="$1"
  trim "$(echo "$line" | sed -En 's/.*OS:([0-9.]+).*/\1/p')"
}

_choose_destination_from_showdestinations() {
  local preferred="$1"
  local sim_lines="$2"

  if [[ -z "$sim_lines" ]]; then
    return 1
  fi

  local line name os

  if [[ -n "$preferred" ]]; then
    line="$(echo "$sim_lines" | grep -F "name:${preferred}" | head -n1 || true)"
    if [[ -n "$line" ]]; then
      name="$(_extract_name_from_destination_line "$line")"
      os="$(_extract_os_from_destination_line "$line")"
      if [[ -n "$name" && -n "$os" ]]; then
        SELECTED_DESTINATION="platform=iOS Simulator,name=${name},OS=${os}"
        DESTINATION_IS_GENERIC=0
        return 0
      fi
    fi
  fi

  line="$(echo "$sim_lines" | grep 'name:iPhone' | head -n1 || true)"
  if [[ -n "$line" ]]; then
    name="$(_extract_name_from_destination_line "$line")"
    os="$(_extract_os_from_destination_line "$line")"
    if [[ -n "$name" && -n "$os" ]]; then
      SELECTED_DESTINATION="platform=iOS Simulator,name=${name},OS=${os}"
      DESTINATION_IS_GENERIC=0
      return 0
    fi
  fi

  if echo "$sim_lines" | grep -q 'name:Any iOS Simulator Device'; then
    SELECTED_DESTINATION="generic/platform=iOS Simulator"
    DESTINATION_IS_GENERIC=1
    return 0
  fi

  line="$(echo "$sim_lines" | grep 'name:' | head -n1 || true)"
  if [[ -n "$line" ]]; then
    name="$(_extract_name_from_destination_line "$line")"
    os="$(_extract_os_from_destination_line "$line")"
    if [[ -n "$name" && -n "$os" ]]; then
      SELECTED_DESTINATION="platform=iOS Simulator,name=${name},OS=${os}"
      DESTINATION_IS_GENERIC=0
      return 0
    fi
  fi

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

  local destinations_output=""
  local destinations_exit=0
  destinations_output="$(xcodebuild -workspace "$workspace" -scheme "$scheme" -showdestinations 2>&1)" || destinations_exit=$?
  local sim_lines=""
  sim_lines="$(echo "$destinations_output" | grep "platform:iOS Simulator" || true)"

  if (( destinations_exit != 0 )); then
    log_warn "xcodebuild -showdestinations failed with status ${destinations_exit}; falling back to simctl discovery"
  fi

  if [[ -n "$sim_lines" ]]; then
    if _choose_destination_from_showdestinations "$preferred_sim" "$sim_lines"; then
      if (( DESTINATION_IS_GENERIC == 1 )); then
        log_warn "No concrete simulators detected, using ${SELECTED_DESTINATION}"
      else
        log_info "Using simulator destination: ${SELECTED_DESTINATION}"
      fi
      return 0
    fi
  elif [[ -n "$destinations_output" ]]; then
    log_warn "xcodebuild -showdestinations did not list any iOS Simulator destinations; falling back to simctl discovery"
  else
    log_warn "xcodebuild -showdestinations produced no output; falling back to simctl discovery"
  fi

  if _xcode_simctl_select "$preferred_sim"; then
    if [[ -z "$destinations_output" ]] || _destination_supported_for_scheme "$SELECTED_DESTINATION" "$destinations_output"; then
      log_info "Using simulator destination: ${SELECTED_DESTINATION}"
      return 0
    fi
    log_warn "Simulator ${SELECTED_DESTINATION} unavailable for scheme ${scheme}; ignoring simctl result"
  fi

  if [[ -n "$sim_lines" ]] && echo "$sim_lines" | grep -q "Any iOS Simulator Device"; then
    SELECTED_DESTINATION="generic/platform=iOS Simulator"
    DESTINATION_IS_GENERIC=1
    log_warn "No concrete simulators detected, using generic destination"
    return 0
  fi

  log_warn "No simulators found; falling back to generic destination"
  SELECTED_DESTINATION="generic/platform=iOS Simulator"
  DESTINATION_IS_GENERIC=1
  return 0
}

xcodebuild_wrapper() {
  local -a args=("$@")
  log_info "xcodebuild ${args[*]}"
  
  # UI tests can hang indefinitely waiting for app to idle or during diagnostic collection.
  # Set a 30-minute timeout (1800s) - generous enough for legitimate test runs, protective against hangs.
  # If timeout is reached, kill xcodebuild and all child processes (including simctl diagnose).
  local timeout_seconds=1800
  local xcodebuild_pid
  
  # Set up trap to forward INT signal to xcodebuild process
  local cleanup_done=0
  cleanup_xcodebuild() {
    if (( cleanup_done == 0 )); then
      cleanup_done=1
      if [[ -n "${xcodebuild_pid:-}" ]] && kill -0 "$xcodebuild_pid" 2>/dev/null; then
        log_warn "Interrupt received - terminating xcodebuild and child processes..."
        pkill -TERM -P "$xcodebuild_pid" 2>/dev/null || true
        sleep 1
        pkill -KILL -P "$xcodebuild_pid" 2>/dev/null || true
        kill -TERM "$xcodebuild_pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$xcodebuild_pid" 2>/dev/null || true
      fi
    fi
  }
  trap cleanup_xcodebuild INT
  
  # Run xcodebuild in background to enable timeout monitoring and signal forwarding
  xcodebuild "${args[@]}" &
  xcodebuild_pid=$!
  
  # Monitor with timeout
  local elapsed=0
  local check_interval=5
  
  while (( elapsed < timeout_seconds )); do
    # Check if xcodebuild is still running
    if ! kill -0 "$xcodebuild_pid" 2>/dev/null; then
      # Process finished naturally
      trap - INT  # Remove trap
      wait "$xcodebuild_pid"
      local exit_code=$?
      return $exit_code
    fi
    
    sleep "$check_interval"
    elapsed=$((elapsed + check_interval))
  done
  
  # Timeout reached - kill xcodebuild and all children
  log_error "xcodebuild timed out after ${timeout_seconds}s - killing process tree"
  cleanup_xcodebuild
  trap - INT  # Remove trap
  
  return 124  # Standard timeout exit code
}
