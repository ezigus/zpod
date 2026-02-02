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

reset_core_simulator_service() {
  command_exists xcrun || return
  set +e
  xcrun simctl shutdown all >/dev/null 2>&1
  killall -9 com.apple.CoreSimulator.CoreSimulatorService >/dev/null 2>&1
  set -e
}

is_sim_boot_failure_log() {
  local log_path="$1"
  [[ -f "$log_path" ]] || return 1
  if grep -qi "Unable to boot the Simulator" "$log_path"; then
    return 0
  fi
  if grep -qi "Failed to prepare device" "$log_path"; then
    return 0
  fi
  return 1
}

is_system_test_bundle_failure_log() {
  local log_path="$1"
  [[ -f "$log_path" ]] || return 1

  local -a patterns=(
    "Failed to create a bundle instance representing"
    "Failed to load the test bundle"
    "The bundle at .*\\.xctest.*could not be loaded"
    "xctest.*could not be loaded"
    "Test runner exited before executing tests"
  )

  local pattern
  for pattern in "${patterns[@]}"; do
    if grep -Eqi "$pattern" "$log_path"; then
      return 0
    fi
  done
  return 1
}

latest_ios_runtime_id() {
  command_exists xcrun || return 1
  command_exists python3 || return 1

  local simctl_json runtime_id status=0
  simctl_json="$(xcrun simctl list runtimes -j 2>/dev/null || true)"
  [[ -z "$simctl_json" ]] && return 1

  set +e
  runtime_id=$(SIMCTL_RUNTIMES_JSON="$simctl_json" python3 - <<'PY'
import json, os, sys
data_str = os.environ.get("SIMCTL_RUNTIMES_JSON", "")
if not data_str:
  sys.exit(1)
try:
  data = json.loads(data_str)
except Exception:
  sys.exit(1)
runtimes = [
  r for r in data.get("runtimes", [])
  if r.get("platform") == "iOS" and r.get("isAvailable", True)
]
if not runtimes:
  sys.exit(1)
def version_key(rt):
  ver = rt.get("version") or ""
  parts = []
  for part in str(ver).replace("-", ".").split("."):
    try:
      parts.append(int(part))
    except Exception:
      parts.append(-1)
  return parts
runtimes = sorted(runtimes, key=version_key, reverse=True)
print(runtimes[0].get("identifier", ""))
PY
)
  status=$?
  set -e
  (( status == 0 )) || return 1
  [[ -n "$runtime_id" ]] || return 1
  printf "%s" "$runtime_id"
}

list_ios_runtime_ids() {
  command_exists xcrun || return 1
  command_exists python3 || return 1

  local simctl_json output status=0
  simctl_json="$(xcrun simctl list runtimes -j 2>/dev/null || true)"
  [[ -z "$simctl_json" ]] && return 1

  set +e
  output=$(SIMCTL_RUNTIMES_JSON="$simctl_json" python3 - <<'PY'
import json, os, sys
data_str = os.environ.get("SIMCTL_RUNTIMES_JSON", "")
if not data_str:
  sys.exit(1)
try:
  data = json.loads(data_str)
except Exception:
  sys.exit(1)
runtimes = [
  r for r in data.get("runtimes", [])
  if r.get("platform") == "iOS" and r.get("isAvailable", True)
]
if not runtimes:
  sys.exit(1)
def version_key(rt):
  ver = rt.get("version") or ""
  parts = []
  for part in str(ver).replace("-", ".").split("."):
    try:
      parts.append(int(part))
    except Exception:
      parts.append(-1)
  return parts
runtimes = sorted(runtimes, key=version_key, reverse=True)
for rt in runtimes:
  ident = rt.get("identifier")
  if ident:
    print(ident)
PY
)
  status=$?
  set -e
  (( status == 0 )) || return 1
  printf "%s" "$output"
}

pick_device_type_identifier() {
  command_exists xcrun || return 1
  command_exists python3 || return 1

  local -a preferred_names=(
    "iPhone 17 Pro"
    "iPhone 17"
    "iPhone 16 Pro"
    "iPhone 16"
    "iPhone 15 Pro"
    "iPhone 15"
    "iPhone 14"
    "iPhone SE (3rd generation)"
  )

  local encoded_names
  encoded_names=$(printf "%s|" "${preferred_names[@]}")
  encoded_names="${encoded_names%|}"

  local identifier=""
  local devicetypes_json status=0
  devicetypes_json="$(xcrun simctl list devicetypes -j 2>/dev/null || true)"
  [[ -z "$devicetypes_json" ]] && return 1

  set +e
  identifier=$(SIMCTL_DEVICETYPES_JSON="$devicetypes_json" python3 - "$encoded_names" <<'PY'
import json, os, sys

preferred = sys.argv[1].split("|")
data_str = os.environ.get("SIMCTL_DEVICETYPES_JSON", "")
if not data_str:
  sys.exit(1)
try:
  data = json.loads(data_str)
except Exception:
  sys.exit(1)

types = data.get("devicetypes", [])
lookup = {t.get("name"): t.get("identifier") for t in types}
for name in preferred:
  ident = lookup.get(name)
  if ident:
    print(ident)
    sys.exit(0)
sys.exit(1)
PY
)
  status=$?
  set -e
  (( status == 0 )) || return 1
  [[ -n "$identifier" ]] || return 1
  printf "%s" "$identifier"
}

create_ephemeral_simulator() {
  local device_type
  device_type=$(pick_device_type_identifier) || return 1

  local runtime_list
  runtime_list=$(list_ios_runtime_ids) || return 1

  local runtime_id
  while IFS= read -r runtime_id; do
    [[ -z "$runtime_id" ]] && continue
    local name="zpod-temp-$(date +%s)-$$-$RANDOM"
    local udid=""
    set +e
    udid=$(xcrun simctl create "$name" "$device_type" "$runtime_id" 2>&1)
    local status=$?
    set -e
    if (( status == 0 )) && [[ -n "$udid" ]]; then
      printf "%s" "$udid"
      return 0
    fi
    log_warn "simctl create failed for runtime ${runtime_id} with status ${status}: ${udid}"
  done <<< "$runtime_list"

  return 1
}

cleanup_ephemeral_simulator() {
  local udid="$1"
  [[ -n "$udid" ]] || return
  set +e
  xcrun simctl shutdown "$udid" >/dev/null 2>&1
  xcrun simctl delete "$udid" >/dev/null 2>&1
  set -e
}

_udid_for_destination() {
  local destination="$1"
  if [[ -z "$destination" ]]; then
    return 1
  fi

  if [[ "$destination" == *"id="* ]]; then
    local id="${destination#*id=}"
    id="${id%%,*}"
    if [[ -n "$id" ]]; then
      printf "%s" "$id"
      return 0
    fi
  fi

  local name os
  name="${destination#*name=}"
  name="${name%%,*}"
  os="${destination#*,OS=}"
  os="${os%%,*}"

  if [[ -z "$name" || -z "$os" ]]; then
    return 1
  fi

  command_exists xcrun || return 1
  command_exists python3 || return 1

  local simctl_json
  simctl_json="$(xcrun simctl list devices --json 2>/dev/null || true)"
  [[ -z "$simctl_json" ]] && return 1

  local udid=""
  set +e
  udid=$(SIMCTL_DEVICES_JSON="$simctl_json" python3 - "$name" "$os" <<'PY'
import json, os, sys

name = sys.argv[1]
os_version = sys.argv[2]
data_str = os.environ.get("SIMCTL_DEVICES_JSON", "")
if not data_str:
  sys.exit(1)

try:
  data = json.loads(data_str)
except Exception:
  sys.exit(1)

for runtime, devices in data.get("devices", {}).items():
  if not runtime.startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
    continue
  runtime_suffix = runtime.rsplit(".", 1)[-1]
  if runtime_suffix.startswith("iOS-"):
    runtime_suffix = runtime_suffix.split("iOS-", 1)[1]
  runtime_os = runtime_suffix.replace("-", ".")
  if runtime_os != os_version:
    continue
  for dev in devices:
    if dev.get("isAvailable") and dev.get("name") == name:
      udid = dev.get("udid")
      if udid:
        print(udid)
        sys.exit(0)
sys.exit(1)
PY
)
  local status=$?
  set -e
  if (( status == 0 )) && [[ -n "$udid" ]]; then
    printf "%s" "$udid"
    return 0
  fi
  return 1
}

boot_simulator_destination() {
  local destination="$1"
  local label="${2:-}"

  if [[ -z "$destination" ]]; then
    return 0
  fi
  if [[ "$destination" == generic/platform=iOS\ Simulator* ]]; then
    return 0
  fi
  if ! command_exists xcrun; then
    log_warn "xcrun unavailable; skipping simulator preboot"
    return 0
  fi

  local boot_timeout=""
  if [[ -n "${ZPOD_SIM_BOOT_TIMEOUT_SECONDS+x}" ]]; then
    boot_timeout="$ZPOD_SIM_BOOT_TIMEOUT_SECONDS"
  else
    boot_timeout=180
  fi

  local udid
  if ! udid="$(_udid_for_destination "$destination")"; then
    log_warn "Could not resolve simulator UDID for destination '${destination}'; skipping preboot"
    return 0
  fi

  local start_ts elapsed formatted boot_status=0
  start_ts=$(date +%s)
  local bootstatus_supports_timeout=0
  if xcrun simctl help bootstatus 2>/dev/null | grep -q -- "-t"; then
    bootstatus_supports_timeout=1
  fi

  if [[ -n "$boot_timeout" && "$boot_timeout" != "0" ]]; then
    log_info "▶️  Booting simulator ${udid}${label:+ (${label})} with timeout ${boot_timeout}s"
  else
    log_info "▶️  Booting simulator ${udid}${label:+ (${label})} (no boot timeout)"
  fi

  set +e
  xcrun simctl boot "$udid" >/dev/null 2>&1
  set -e

  if (( bootstatus_supports_timeout == 1 )); then
    set +e
    if [[ -n "$boot_timeout" && "$boot_timeout" != "0" ]]; then
      xcrun simctl bootstatus "$udid" -b -t "$boot_timeout" >/dev/null
    else
      xcrun simctl bootstatus "$udid" -b >/dev/null
    fi
    boot_status=$?
    set -e
  else
    if [[ -n "$boot_timeout" && "$boot_timeout" != "0" ]]; then
      local deadline=$(( start_ts + boot_timeout ))
      local boot_pid=0
      set +e
      xcrun simctl bootstatus "$udid" -b >/dev/null &
      boot_pid=$!
      set -e
      while kill -0 "$boot_pid" >/dev/null 2>&1; do
        if (( $(date +%s) >= deadline )); then
          boot_status=124
          kill -TERM "$boot_pid" >/dev/null 2>&1 || true
          sleep 1
          kill -KILL "$boot_pid" >/dev/null 2>&1 || true
          break
        fi
        sleep 2
      done
      if (( boot_status == 0 )); then
        set +e
        wait "$boot_pid"
        boot_status=$?
        set -e
      fi
    else
      set +e
      xcrun simctl bootstatus "$udid" -b >/dev/null
      boot_status=$?
      set -e
    fi
  fi

  elapsed=$(( $(date +%s) - start_ts ))
  formatted=$(printf '%02d:%02d:%02d' $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60)))

  if (( boot_status == 0 )); then
    log_time "Simulator ready in ${formatted}${label:+ (${label})}"
    return 0
  fi

  log_error "Simulator boot timed out after ${formatted}${label:+ (${label})}"
  return 124
}

xcodebuild_wrapper() {
  local -a args=("$@")
  log_info "xcodebuild ${args[*]}"
  local xb_start ts_elapsed formatted_elapsed
  xb_start=$(date +%s)
  
  # UI tests can hang indefinitely waiting for app to idle or during diagnostic collection.
  # Use a configurable watchdog timeout via ZPOD_XCODEBUILD_TIMEOUT_SECONDS (seconds).
  # If the variable is explicitly set to 0/empty, disable the watchdog for this run.
  # If timeout is reached, kill xcodebuild and all child processes (including simctl diagnose).
  local timeout_seconds=""
  if [[ -n "${ZPOD_XCODEBUILD_TIMEOUT_SECONDS+x}" ]]; then
    timeout_seconds="$ZPOD_XCODEBUILD_TIMEOUT_SECONDS"
  else
    timeout_seconds=1800
  fi

  if [[ -z "$timeout_seconds" || "$timeout_seconds" == "0" ]]; then
    xcodebuild "${args[@]}"
    local exit_code=$?
    ts_elapsed=$(( $(date +%s) - xb_start ))
    formatted_elapsed=$(printf '%02d:%02d:%02d' $((ts_elapsed/3600)) $(((ts_elapsed%3600)/60)) $((ts_elapsed%60)))
    log_time "xcodebuild completed in ${formatted_elapsed} (no watchdog)"
    return $exit_code
  fi
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
      ts_elapsed=$(( $(date +%s) - xb_start ))
      formatted_elapsed=$(printf '%02d:%02d:%02d' $((ts_elapsed/3600)) $(((ts_elapsed%3600)/60)) $((ts_elapsed%60)))
      log_time "xcodebuild completed in ${formatted_elapsed}"
      return $exit_code
    fi
    
    sleep "$check_interval"
    elapsed=$((elapsed + check_interval))
  done
  
  # Timeout reached - kill xcodebuild and all children
  log_error "xcodebuild timed out after ${timeout_seconds}s - killing process tree"
  cleanup_xcodebuild
  trap - INT  # Remove trap
  ts_elapsed=$(( $(date +%s) - xb_start ))
  formatted_elapsed=$(printf '%02d:%02d:%02d' $((ts_elapsed/3600)) $(((ts_elapsed%3600)/60)) $((ts_elapsed%60)))
  log_time "xcodebuild terminated after ${formatted_elapsed} (timeout)"
  
  return 124  # Standard timeout exit code
}
