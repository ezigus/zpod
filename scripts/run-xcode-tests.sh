#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_ROOT}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_ROOT}/lib/common.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_ROOT}/lib/logging.sh"
# shellcheck source=lib/result.sh
source "${SCRIPT_ROOT}/lib/result.sh"
# shellcheck source=lib/xcode.sh
source "${SCRIPT_ROOT}/lib/xcode.sh"
# shellcheck source=lib/spm.sh
source "${SCRIPT_ROOT}/lib/spm.sh"
# shellcheck source=lib/testplan.sh
source "${SCRIPT_ROOT}/lib/testplan.sh"

SCHEME=""
WORKSPACE="${REPO_ROOT}/zpod.xcworkspace"
PREFERRED_SIM="iPhone 17 Pro"
REQUESTED_CLEAN=0
REQUESTED_BUILDS=""
REQUESTED_TESTS=""
REQUESTED_SYNTAX=0
REQUEST_TESTPLAN=0
REQUEST_TESTPLAN_SUITE=""
REQUESTED_LINT=0
SELF_CHECK=0
SCHEME_RESOLVED=0
SCHEME_CANDIDATES=("zpod (zpod project)" "zpod")

TESTPLAN_LAST_DISCOVERED=0
TESTPLAN_LAST_INCLUDED=0
TESTPLAN_LAST_MISSING=0
TESTPLAN_LAST_PACKAGES=0
TESTPLAN_LAST_WORKSPACE=0
TESTPLAN_LAST_MISSING_NAMES=""

declare -a SUMMARY_ITEMS=()
declare -a RESULT_LOG_PATHS=()

EXIT_STATUS=0
INTERRUPTED=0
CURRENT_PHASE=""
CURRENT_PHASE_CATEGORY=""
SUMMARY_PRINTED=0
CURRENT_PHASE_RECORDED=0
declare -a PHASE_DURATION_ENTRIES=()
declare -a TEST_SUITE_TIMING_ENTRIES=()

register_result_log() {
  local path="$1"
  [[ -n "$path" ]] || return
  if (( ${#RESULT_LOG_PATHS[@]} > 0 )); then
    local existing
    for existing in "${RESULT_LOG_PATHS[@]}"; do
      if [[ "$existing" == "$path" ]]; then
        return
      fi
    done
  fi
  RESULT_LOG_PATHS+=("$path")
}

print_grouped_test_summary() {
  print_section_header "Summary Tests"
  local count=${#PRIMARY_ORDER[@]}
  local -a totals passed failed skipped details
  local i
  for (( i=0; i<count; i++ )); do
    totals[i]=0; passed[i]=0; failed[i]=0; skipped[i]=0; details[i]=""
  done

  local entry
  for entry in "${SUMMARY_ITEMS[@]-}"; do
    IFS='|' read -r category name status log_path total passed_count failed_count skipped_count note <<< "$entry"
    # Only count entries that actually represent tests or have totals
    if [[ "$category" != "test" && -z "${total:-}" && -z "${passed_count:-}" && -z "${failed_count:-}" && -z "${skipped_count:-}" ]]; then
      continue
    fi
    local group
    group=$(test_group_for "$category" "$name")
    [[ -z "$group" ]] && continue
    local idx
    idx=$(index_for_primary "$group")
    [[ -z "$idx" ]] && continue
    totals[idx]=$(( ${totals[idx]} + ${total:-0} ))
    passed[idx]=$(( ${passed[idx]} + ${passed_count:-0} ))
    failed[idx]=$(( ${failed[idx]} + ${failed_count:-0} ))
    skipped[idx]=$(( ${skipped[idx]} + ${skipped_count:-0} ))
    local symbol
    symbol=$(status_symbol "$status")
    details[idx]+=$(printf '  %s %s – %s total (failed %s, skipped %s)%s\n' \
      "$symbol" "$name" "${total:-0}" "${failed_count:-0}" "${skipped_count:-0}" \
      $([[ -n "$log_path" ]] && printf ' – log: %s' "$log_path"))
  done

  for i in "${!PRIMARY_ORDER[@]}"; do
    local t=${totals[i]}
    local p=${passed[i]}
    local f=${failed[i]}
    local s=${skipped[i]}
    # Only show groups that ran
    if (( t == 0 && p == 0 && f == 0 && s == 0 )) && [[ -z "${details[i]}" ]]; then
      continue
    fi
    printf "%s: %s total (passed %s, failed %s, skipped %s)\n" "${PRIMARY_ORDER[i]}" "$t" "$p" "$f" "$s"
    if [[ -n "${details[i]}" ]]; then
      printf "%s" "${details[i]}"
    else
      printf "  (none)\n"
    fi
  done
}

update_exit_status() {
  local code="$1"
  [[ -z "$code" ]] && return
  if (( code != 0 )); then
    if (( EXIT_STATUS == 0 )); then
      EXIT_STATUS=$code
    fi
  fi
}

status_symbol() {
  local status="$1"
  case "$status" in
    success) printf '✅';;
    warn) printf '⚠️';;
    error|fail|failed) printf '❌';;
    interrupted) printf '⏸️';;
    *) printf 'ℹ️';;
  esac
}

format_elapsed_time() {
  local elapsed="$1"
  local hours=$((elapsed / 3600))
  local minutes=$(((elapsed % 3600) / 60))
  local seconds=$((elapsed % 60))
  printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds"
}

begin_phase() {
  CURRENT_PHASE="$1"
  CURRENT_PHASE_CATEGORY="$2"
  CURRENT_PHASE_RECORDED=0
}

mark_phase_summary_recorded() {
  CURRENT_PHASE_RECORDED=1
}

execute_phase() {
  local label="$1"
  local category="$2"
  shift 2
  local -a command=("$@")

  begin_phase "$label" "$category"
  local phase_start
  phase_start=$(date +%s)
  log_info "▶️  ${label} started"
  set +e
  "${command[@]}"
  local status=$?
  set -e
  local phase_end
  phase_end=$(date +%s)
  local phase_elapsed=$((phase_end - phase_start))
  local formatted_elapsed
  formatted_elapsed=$(format_elapsed_time "$phase_elapsed")

  local phase_status="success"
  if (( status != 0 )); then
    if (( CURRENT_PHASE_RECORDED == 0 )); then
      add_summary "$category" "$label" "error" "" "" "" "" "" "failed"
    fi
    log_warn "${label} failed after ${formatted_elapsed}"
    update_exit_status "$status"
    phase_status="error"
  else
    log_info "⏱️  ${label} completed in ${formatted_elapsed}"
  fi

  record_phase_timing "$category" "$label" "$phase_elapsed" "$phase_status"

  CURRENT_PHASE=""
  CURRENT_PHASE_CATEGORY=""
  CURRENT_PHASE_RECORDED=0

  return "$status"
}

record_phase_timing() {
  local category="$1"
  local name="$2"
  local elapsed="$3"
  local status="$4"
  PHASE_DURATION_ENTRIES+=("${category}|${name}|${elapsed}|${status}")
}

category_in() {
  # Safely check membership; tolerate empty inputs. Disable errtrace locally so non-zero returns
  # here don't trigger the global ERR trap (callers handle the boolean explicitly).
  local had_errtrace=0
  case $- in
    *E*) had_errtrace=1;;
  esac
  set +E
  if (( $# == 0 )); then
    [[ $had_errtrace -eq 1 ]] && set -E
    return 1
  fi
  local value="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if [[ "$value" == "$candidate" ]]; then
      [[ $had_errtrace -eq 1 ]] && set -E
      return 0
    fi
  done
  [[ $had_errtrace -eq 1 ]] && set -E
  return 1
}

# Primary ordering for grouped summaries
PRIMARY_ORDER=("Build" "Syntax" "AppSmoke" "Package Build" "Package Tests" "Integration" "UI Tests" "Lint")

index_for_primary() {
  local group="$1"
  local idx
  for idx in "${!PRIMARY_ORDER[@]}"; do
    [[ "${PRIMARY_ORDER[idx]}" == "$group" ]] && { echo "$idx"; return; }
  done
  echo ""
}

phase_group_for() {
  local category="$1"
  local name="$2"
  if [[ "$category" == "syntax" || "$name" == "Swift syntax" ]]; then
    echo "Syntax"; return
  fi
  if [[ "$name" == "App smoke tests" ]]; then
    echo "AppSmoke"; return
  fi
  if [[ "$name" == Integration* ]]; then
    echo "Integration"; return
  fi
  if [[ "$name" == "UI tests" || "$name" == zpodUITests* || "$name" == *UITests* || "$name" == *-ui || "$name" == zpod-ui ]]; then
    echo "UI Tests"; return
  fi
  if [[ "$category" == "lint" || "$name" == Swift\ lint* ]]; then
    echo "Lint"; return
  fi
  if [[ "$name" == Build\ package* ]]; then
    echo "Package Build"; return
  fi
  if [[ "$name" == package\ * ]]; then
    echo "Package Build"; return
  fi
  if [[ "$name" == Package\ tests* ]]; then
    echo "Package Tests"; return
  fi
  if [[ "$category" == "build" || "$name" == Build* ]]; then
    echo "Build"; return
  fi
}

test_group_for() {
  local category="$1"
  local name="$2"
  if [[ "$category" == "syntax" ]]; then
    echo "Syntax"; return
  fi
  if [[ "$category" == "build" ]]; then
    if [[ "$name" == package\ * || "$name" == Build\ package* ]]; then
      echo "Package Build"; return
    fi
    echo "Build"; return
  fi
  if [[ "$name" == AppSmokeTests* || "$name" == *AppSmoke* ]]; then
    echo "AppSmoke"; return
  fi
  if [[ "$name" == IntegrationTests* || "$name" == *Integration* ]]; then
    echo "Integration"; return
  fi
  if [[ "$name" == zpodUITests* || "$name" == *UITests* || "$name" == *-ui || "$name" == zpod-ui ]]; then
    echo "UI Tests"; return
  fi
  if [[ "$category" == "lint" || "$name" == Swift\ lint* ]]; then
    echo "Lint"; return
  fi
  if [[ "$name" == package* ]]; then
    echo "Package Tests"; return
  fi
}

resolve_xcodebuild_timeout() {
  local label="$1"
  if [[ -n "${ZPOD_XCODEBUILD_TIMEOUT_SECONDS:-}" ]]; then
    echo "$ZPOD_XCODEBUILD_TIMEOUT_SECONDS"
    return
  fi

  local ui_timeout="${ZPOD_UI_TEST_TIMEOUT_SECONDS:-900}"
  local default_timeout="${ZPOD_TEST_TIMEOUT_SECONDS:-1800}"
  if [[ "$label" == *UITests* || "$label" == *-ui || "$label" == "UI tests" ]]; then
    echo "$ui_timeout"
    return
  fi
  echo "$default_timeout"
}

list_ui_test_suites() {
  if [[ -n "${ZPOD_UI_TEST_SUITES:-}" ]]; then
    split_csv "$ZPOD_UI_TEST_SUITES"
    local item
    for item in "${__ZPOD_SPLIT_RESULT[@]}"; do
      item="$(trim "$item")"
      [[ -z "$item" ]] && continue
      printf "%s\n" "$item"
    done
    return 0
  fi

  ensure_command rg "ripgrep is required to enumerate UI test suites" || return 1
  rg -N --no-filename -g '*Tests.swift' 'class[[:space:]]+[A-Za-z0-9_]+[[:space:]]*:[[:space:]]*XCTestCase' \
    "${REPO_ROOT}/zpodUITests" | \
    sed -E 's/^.*class[[:space:]]+([A-Za-z0-9_]+)[[:space:]]*:.*$/\1/' | \
    sort -u
}

run_ui_test_suites() {
  local suites=()
  local suite
  while IFS= read -r suite; do
    [[ -z "$suite" ]] && continue
    suites+=("$suite")
  done < <(list_ui_test_suites)

  if (( ${#suites[@]} == 0 )); then
    log_warn "No UI test suites discovered; falling back to zpodUITests"
    execute_phase "UI tests" "test" run_test_target "zpodUITests"
    return
  fi

  local any_failed=0
  for suite in "${suites[@]}"; do
    if ! execute_phase "UI tests ${suite}" "test" run_test_target "zpodUITests/${suite}"; then
      any_failed=1
    fi
  done
  if (( any_failed == 1 )); then
    log_warn "One or more UI suites failed; continuing with remaining phases"
  fi
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

reset_core_simulator_service() {
  command_exists xcrun || return
  set +e
  xcrun simctl shutdown all >/dev/null 2>&1
  killall -9 com.apple.CoreSimulator.CoreSimulatorService >/dev/null 2>&1
  set -e
}

latest_ios_runtime_id() {
  command_exists xcrun || return 1
  command_exists python3 || return 1

  local runtime_id=""
  set +e
  runtime_id=$(xcrun simctl list runtimes -j 2>/dev/null | python3 - <<'PY'
import json, sys
try:
  data = json.load(sys.stdin)
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
  local status=$?
  set -e
  (( status == 0 )) || return 1
  [[ -n "$runtime_id" ]] || return 1
  printf "%s" "$runtime_id"
}

list_ios_runtime_ids() {
  command_exists xcrun || return 1
  command_exists python3 || return 1

  local output
  set +e
  output=$(xcrun simctl list runtimes -j 2>/dev/null | python3 - <<'PY'
import json, sys
try:
  data = json.load(sys.stdin)
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
  local status=$?
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
  set +e
  identifier=$(xcrun simctl list devicetypes -j 2>/dev/null | python3 - "$encoded_names" <<'PY'
import json, sys

preferred = sys.argv[1].split("|")
try:
  data = json.load(sys.stdin)
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
  local status=$?
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
    local name="zpod-temp-$(date +%s)"
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

print_section_header() {
  local title="$1"
  printf '================================\n%s\n================================\n' "$title"
}

format_summary_line() {
  local category="$1"
  local name="$2"
  local status="$3"
  local log_path="$4"
  local total="$5"
  local passed="$6"
  local failed="$7"
  local skipped="$8"
  local note="$9"

  local symbol
  symbol=$(status_symbol "$status")
  local line="  ${symbol} ${name}"
  if [[ "$category" == "test" && -n "$total" ]]; then
    line+=" – ${total} total (passed ${passed}, failed ${failed}, skipped ${skipped})"
  fi
  if [[ -n "$note" ]]; then
    line+=" – ${note}"
  fi
  if [[ -n "$log_path" ]]; then
    line+=" – log: ${log_path}"
  fi
  printf '%s\n' "$line"
}

categorize_test_entry() {
  local name="$1"
  case "$name" in
    package\ *) echo "Package Tests";;
    *AppSmokeTests*|*zpod-smoke*) echo "Unit Tests";;
    *IntegrationTests*|*Integration*) echo "Integration Tests";;
    *UITests*|*-ui|*UITests-*) echo "UI Tests";;
    *) echo "Other Tests";;
  esac
}

print_entries_for_categories() {
  local -a categories=("$@")
  if (( ${#categories[@]} == 0 )); then
    printf '  (none)\n'
    return
  fi
  local found=0
  local entry
  for entry in "${SUMMARY_ITEMS[@]}"; do
    IFS='|' read -r category name status log_path total passed failed skipped note <<< "$entry"
    if category_in "$category" "${categories[@]}"; then
      format_summary_line "$category" "$name" "$status" "$log_path" "$total" "$passed" "$failed" "$skipped" "$note"
      found=1
    fi
  done
  if (( found == 0 )); then
    printf '  (none)\n'
  fi
}

finalize_and_exit() {
  local code="$1"
  update_exit_status "$code"
  trap - ERR INT EXIT
  if (( SUMMARY_PRINTED == 0 )); then
    if [[ -n "${RESULT_LOG:-}" ]]; then
      print_summary | tee -a "$RESULT_LOG"
    else
      print_summary
    fi
  fi
  SUMMARY_PRINTED=1
  exit "$code"
}

exit_with_summary() {
  local code="${1:-1}"
  update_exit_status "$code"
  finalize_and_exit "$EXIT_STATUS"
}

handle_interrupt() {
  INTERRUPTED=1
  if [[ -n "$CURRENT_PHASE" && $CURRENT_PHASE_RECORDED -eq 0 ]]; then
    add_summary "${CURRENT_PHASE_CATEGORY:-phase}" "$CURRENT_PHASE" "interrupted" "" "" "" "" "" "interrupted by user"
  fi
  update_exit_status 130
  finalize_and_exit "$EXIT_STATUS"
}

handle_unexpected_error() {
  local status=$1
  local line=$2
  if [[ -n "$CURRENT_PHASE" && $CURRENT_PHASE_RECORDED -eq 0 ]]; then
    add_summary "${CURRENT_PHASE_CATEGORY:-script}" "$CURRENT_PHASE" "error" "" "" "" "" "" "script error at line ${line}"
  elif (( ${#SUMMARY_ITEMS[@]} == 0 )); then
    add_summary "script" "runtime" "error" "" "" "" "" "" "script error at line ${line}"
  fi
  update_exit_status "$status"
  finalize_and_exit "$EXIT_STATUS"
}

trap 'handle_interrupt' INT
trap 'handle_unexpected_error $? $LINENO' ERR
handle_exit() {
  local status=$?
  if (( EXIT_STATUS != 0 )); then
    status=$EXIT_STATUS
  fi
  finalize_and_exit "$status"
}
trap 'handle_exit' EXIT

add_summary() {
  local category="$1"
  local name="$2"
  local status="$3"
  local log_path="${4:-}"
  local total="${5:-}"
  local passed="${6:-}"
  local failed="${7:-}"
  local skipped="${8:-}"
  local note="${9:-}"
  mark_phase_summary_recorded
  SUMMARY_ITEMS+=("${category}|${name}|${status}|${log_path}|${total}|${passed}|${failed}|${skipped}|${note}")
}

ensure_host_app_product() {
  if [[ -z "${ZPOD_DERIVED_DATA_PATH:-}" ]]; then
    return 0
  fi

  local expected_app="$ZPOD_DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/zpod.app/zpod"
  if [[ -f "$expected_app" ]]; then
    return 0
  fi

  if [[ "${ZPOD_TEST_WITHOUT_BUILDING:-0}" == "1" ]]; then
    log_error "Host app missing at ${expected_app} but rebuilds are disabled (ZPOD_TEST_WITHOUT_BUILDING=1)"
    return 1
  fi

  log_info "Host app missing at ${expected_app}; building zpod target before running tests"

  local original_clean=$REQUESTED_CLEAN
  REQUESTED_CLEAN=0
  if ! build_app_target "zpod"; then
    REQUESTED_CLEAN=$original_clean
    log_error "Failed to build host app in ${ZPOD_DERIVED_DATA_PATH}"
    return 1
  fi
  REQUESTED_CLEAN=$original_clean

  if [[ ! -f "$expected_app" ]]; then
    log_error "Host app still missing at ${expected_app} after rebuild"
    return 1
  fi

  return 0
}

extract_test_counts() {
  local summary="$1"
  summary="${summary//$'\r'/}"
  summary="${summary//$'\n'/}"
  if [[ "$summary" =~ ^([0-9]+)[[:space:]]+run,[[:space:]]+([0-9]+)[[:space:]]+passed,[[:space:]]+([0-9]+)[[:space:]]+failed,[[:space:]]+([0-9]+)[[:space:]]+skipped$ ]]; then
    printf "%s|%s|%s|%s" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
    return 0
  fi
  return 1
}

join_with_delimiter() {
  local delimiter="$1"
  shift
  local -a items=("$@")
  local count=${#items[@]}
  if (( count == 0 )); then
    return
  fi
  local output="${items[0]}"
  local i
  for (( i=1; i<count; i++ )); do
    output+="${delimiter}${items[i]}"
  done
  printf "%s" "$output"
}

format_list_preview() {
  local array_name="$1"
  local limit=${2:-6}

  local count
  eval "count=\${#$array_name[@]}"
  if (( count == 0 )); then
    return
  fi

  local slice_count=$(( count < limit ? count : limit ))
  local -a slice=()
  local idx value
  for (( idx=0; idx<slice_count; idx++ )); do
    eval "value=\${$array_name[$idx]}"
    slice+=("$value")
  done

  local text
  text=$(join_with_delimiter ", " "${slice[@]}")
  if (( count > limit )); then
    text+=" (+$((count - limit)) more)"
  fi
  printf "%s" "$text"
}

collect_build_summary_info() {
  local log_path="$1"
  [[ -f "$log_path" ]] || return 0

  local -a targets=()
  local -a packages=()
  local targets_seen=$'\n'
  local packages_seen=$'\n'
  local in_packages=0
  local target_regex="Target '([^']+)'"

  while IFS= read -r line; do
    if [[ -z "${line// }" ]]; then
      in_packages=0
    fi

    if [[ "$line" == *"Resolved source packages:"* ]]; then
      in_packages=1
      continue
    fi

    if (( in_packages )); then
      if [[ $line =~ ^[[:space:]]*([A-Za-z0-9._-]+):[[:space:]] ]]; then
        local package="${BASH_REMATCH[1]}"
        if [[ $packages_seen != *$'\n'"$package"$'\n'* ]]; then
          packages+=("$package")
          packages_seen+="${package}"$'\n'
        fi
      fi
      continue
    fi

    if [[ $line =~ $target_regex ]]; then
      local target="${BASH_REMATCH[1]}"
      if [[ $targets_seen != *$'\n'"$target"$'\n'* ]]; then
  targets+=("$target")
  targets_seen+="${target}"$'\n'
      fi
    fi
  done < "$log_path"

  local -a parts=()
  if (( ${#targets[@]} > 0 )); then
    local formatted
    formatted=$(format_list_preview targets 6)
    parts+=("targets ${#targets[@]}: ${formatted}")
  fi
  if (( ${#packages[@]} > 0 )); then
    local formatted
    formatted=$(format_list_preview packages 6)
    parts+=("packages ${#packages[@]}: ${formatted}")
  fi

  if (( ${#parts[@]} == 0 )); then
    return 0
  fi

  local note="${parts[0]}"
  local p_idx
  for (( p_idx=1; p_idx<${#parts[@]}; p_idx++ )); do
    note+="; ${parts[p_idx]}"
  done
  printf "%s" "$note"
}

summarize_syntax_log() {
  local log_path="$1"
  [[ -f "$log_path" ]] || return 0
  local file_count
  file_count=$(grep -c "Checking:" "$log_path" 2>/dev/null || true)
  if (( file_count > 0 )); then
    printf "%s" "${file_count} files checked"
  fi
}

summarize_lint_log() {
  local tool="$1"
  local log_path="$2"
  [[ -f "$log_path" ]] || return 0

  local line
  line=$(grep -E "Found [0-9]+ violations" "$log_path" 2>/dev/null | tail -1 || true)
  if [[ -n "$line" ]]; then
    if [[ $line =~ Found[[:space:]]+([0-9]+)[[:space:]]+violations?,[[:space:]]+([0-9]+)[[:space:]]+serious[[:space:]]+in[[:space:]]+([0-9]+)[[:space:]]+files? ]]; then
      printf "%s" "${BASH_REMATCH[3]} files, ${BASH_REMATCH[1]} violations (${BASH_REMATCH[2]} serious)"
      return 0
    fi
    printf "%s" "$line"
    return 0
  fi

  case "$tool" in
    swift-format)
      line=$(grep -E "(No lint violations|Lint finished)" "$log_path" 2>/dev/null | tail -1 || true)
      ;;
    swiftformat)
      line=$(grep -E "SwiftFormat" "$log_path" 2>/dev/null | tail -1 || true)
      ;;
  esac

  if [[ -n "$line" ]]; then
    printf "%s" "$line"
  fi
}

summarize_testplan_note() {
  local -a parts=()
  if (( TESTPLAN_LAST_DISCOVERED > 0 )); then
    parts+=("targets ${TESTPLAN_LAST_DISCOVERED} (workspace ${TESTPLAN_LAST_WORKSPACE}, package ${TESTPLAN_LAST_PACKAGES})")
  fi
  if (( TESTPLAN_LAST_INCLUDED >= 0 )); then
    parts+=("plan entries ${TESTPLAN_LAST_INCLUDED}")
  fi
  if (( TESTPLAN_LAST_MISSING >= 0 )); then
    local missing_text="missing ${TESTPLAN_LAST_MISSING}"
    if (( TESTPLAN_LAST_MISSING > 0 )) && [[ -n "$TESTPLAN_LAST_MISSING_NAMES" ]]; then
      local -a missing_arr=()
      while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        missing_arr+=("$name")
      done <<< "$TESTPLAN_LAST_MISSING_NAMES"
      if (( ${#missing_arr[@]} > 0 )); then
        local limit=5
        local preview_count=$(( ${#missing_arr[@]} < limit ? ${#missing_arr[@]} : limit ))
        local -a preview=()
        local idx
        for (( idx=0; idx<preview_count; idx++ )); do
          preview+=("${missing_arr[idx]}")
        done
        local preview_text=""
        if (( preview_count > 0 )); then
          preview_text=$(join_with_delimiter ", " "${preview[@]}")
          if (( ${#missing_arr[@]} > limit )); then
            preview_text+=" (+$(( ${#missing_arr[@]} - limit )) more)"
          fi
          missing_text+=" (${preview_text})"
        fi
      fi
    fi
    parts+=("${missing_text}")
  fi

  if (( ${#parts[@]} == 0 )); then
    return 0
  fi

  local note="${parts[0]}"
  local idx
  for (( idx=1; idx<${#parts[@]}; idx++ )); do
    note+="; ${parts[idx]}"
  done
  printf "%s" "$note"
}

tally_counts() {
  local -a categories=("$@")
  local total=0
  local success=0
  local warn=0
  local error=0
  local interrupted=0
  local entry
  for entry in "${SUMMARY_ITEMS[@]}"; do
    IFS='|' read -r category _ status _ <<< "$entry"
    if category_in "$category" "${categories[@]}"; then
      ((total++))
      case "$status" in
        success) ((success++));;
        warn) ((warn++));;
        error|fail|failed) ((error++));;
        interrupted) ((interrupted++));;
      esac
    fi
  done
  printf '%s|%s|%s|%s|%s' "$total" "$success" "$warn" "$error" "$interrupted"
}

sum_test_case_counts() {
  local total=0
  local passed=0
  local failed=0
  local skipped=0
  local entry
  for entry in "${SUMMARY_ITEMS[@]}"; do
    IFS='|' read -r category _ status _ t p f s _ <<< "$entry"
    if [[ "$category" == "test" && -n "$t" ]]; then
      ((total+=t))
      ((passed+=p))
      ((failed+=f))
      ((skipped+=s))
    fi
  done
  printf '%s|%s|%s|%s' "$total" "$passed" "$failed" "$skipped"
}

print_suite_breakdown() {
  local target="$1"
  local found=0
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target suite duration status total failed skipped <<< "$entry"
    [[ "$suite_target" == "$target" ]] || continue
    local symbol
    symbol=$(status_symbol "$status")
    printf '    %s %s – %s (%s tests, failed %s, skipped %s)\n' \
      "$symbol" "$suite" "$(format_elapsed_time "${duration:-0}")" "${total:-0}" "${failed:-0}" "${skipped:-0}"
    found=1
  done
  (( found == 0 )) && return
}

group_for_entry() {
  local category="$1"
  local name="$2"
  if [[ "$category" == "test" ]]; then
    test_group_for "$category" "$name"
  else
    phase_group_for "$category" "$name"
  fi
}

group_elapsed_seconds() {
  local target_group="$1"
  local total=0
  local entry
  for entry in "${PHASE_DURATION_ENTRIES[@]-}"; do
    IFS='|' read -r category name elapsed status <<< "$entry"
    local group
    group=$(phase_group_for "$category" "$name")
    [[ "$group" == "$target_group" ]] || continue
    total=$(( total + ${elapsed:-0} ))
  done
  printf "%s" "$total"
}

first_log_for_group() {
  local target_group="$1"
  local first=""
  local more=0
  local entry
  for entry in "${SUMMARY_ITEMS[@]-}"; do
    IFS='|' read -r category name status log_path _ <<< "$entry"
    [[ -n "$log_path" ]] || continue
    local group
    group=$(group_for_entry "$category" "$name")
    [[ "$group" == "$target_group" ]] || continue
    if [[ -z "$first" ]]; then
      first="$log_path"
    else
      more=1
      break
    fi
  done
  if [[ -n "$first" ]]; then
    if (( more == 1 )); then
      printf "%s (+more)" "$first"
    else
      printf "%s" "$first"
    fi
  fi
}

print_group_timing_block() {
  local title="$1"
  shift
  local -a groups=("$@")
  local any=0
  print_section_header "$title"
  local total_all=0
  local group
  for group in "${groups[@]}"; do
    local seconds
    seconds=$(group_elapsed_seconds "$group")
    (( seconds == 0 )) && continue
    any=1
    local log_path
    log_path=$(first_log_for_group "$group")
    printf "  %s: %s" "$group" "$(format_elapsed_time "$seconds")"
    if [[ -n "$log_path" ]]; then
      printf " – log: %s" "$log_path"
    fi
    printf "\n"
    total_all=$(( total_all + seconds ))
  done
  if (( any == 0 )); then
    printf "  (none)\n"
  fi
  printf "  Total: %s\n" "$(format_elapsed_time "$total_all")"
  printf "\n"
}

print_test_timing_block() {
  local -a groups=("Syntax" "AppSmoke" "Package Tests" "Integration" "UI Tests" "Lint")
  local any=0
  print_section_header "Test Timing"
  local total_all=0
  local group
  for group in "${groups[@]}"; do
    local seconds
    seconds=$(group_elapsed_seconds "$group")
    (( seconds == 0 )) && continue
    total_all=$(( total_all + seconds ))
    local suppress=0
    if [[ "$group" == "Package Tests" || "$group" == "UI Tests" ]]; then
      suppress=1
    fi
    if (( suppress == 1 )); then
      continue
    fi
    any=1
    local log_path
    log_path=$(first_log_for_group "$group")
    printf "  %s: %s" "$group" "$(format_elapsed_time "$seconds")"
    if [[ -n "$log_path" ]]; then
      printf " – log: %s" "$log_path"
    fi
    printf "\n"
  done
  if (( any == 0 )); then
    printf "  (none)\n"
  fi
  printf "  Total: %s\n" "$(format_elapsed_time "$total_all")"
  printf "\n"
}

package_test_timing_breakdown() {
  local any=0
  local total_duration=0
  local -a lines=()
  local entry
  for entry in "${SUMMARY_ITEMS[@]-}"; do
    IFS='|' read -r category name status log_path total passed failed skipped _ <<< "$entry"
    [[ "$category" == "test" ]] || continue
    [[ "$name" == package\ * ]] || continue
    local pkg_phase="Package tests ${name#package }"
    local duration_sec=0
    local ph_entry
    for ph_entry in "${PHASE_DURATION_ENTRIES[@]-}"; do
      IFS='|' read -r ph_cat ph_name ph_elapsed _ <<< "$ph_entry"
      if [[ "$ph_name" == "$pkg_phase" ]]; then
        duration_sec=${ph_elapsed:-0}
        break
      fi
    done
    total_duration=$(( total_duration + duration_sec ))
    any=1
    local line="    ${name} – $(format_elapsed_time "$duration_sec")"
    if [[ -n "$log_path" ]]; then
      line+=" – log: ${log_path}"
    fi
    lines+=("$line")
  done
  (( any == 0 )) && return
  local group_total
  group_total=$(group_elapsed_seconds "Package Tests")
  if (( group_total > 0 )); then
    total_duration=$group_total
  fi
  printf "  Package Tests detail: %s\n" "$(format_elapsed_time "$total_duration")"
  printf '%s\n' "${lines[@]}"
}

ui_suite_timing_breakdown() {
  local any=0
  local total_duration=0
  local -a lines=()
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target suite duration status total failed skipped <<< "$entry"
    [[ "$suite_target" == *UITests* ]] || continue
    local symbol
    symbol=$(status_symbol "$status")
    total_duration=$(( total_duration + ${duration:-0} ))
    any=1
    lines+=("    ${symbol} ${suite} – $(format_elapsed_time "${duration:-0}")")
  done
  (( any == 0 )) && return
  local group_total
  group_total=$(group_elapsed_seconds "UI Tests")
  if (( group_total > 0 )); then
    total_duration=$group_total
  fi
  printf "  UI suite detail: %s\n" "$(format_elapsed_time "$total_duration")"
  local line
  for line in "${lines[@]}"; do
    printf '%s\n' "$line"
  done
}

status_counts_for_groups() {
  local target_group="$1"
  local total=0 success=0 warn=0 error=0 skipped=0
  local entry
  for entry in "${SUMMARY_ITEMS[@]-}"; do
    IFS='|' read -r category name status _ <<< "$entry"
    local group
    group=$(group_for_entry "$category" "$name")
    [[ "$group" == "$target_group" ]] || continue
    (( total++ ))
    case "$status" in
      success) ((success++));;
      warn) ((warn++));;
      error|fail|failed) ((error++));;
      interrupted) ((skipped++));;
    esac
  done
  printf "%s|%s|%s|%s|%s" "$total" "$success" "$error" "$skipped" "$warn"
}

test_counts_for_group() {
  local target_group="$1"
  local total=0 passed=0 failed=0 skipped=0 warn=0
  local has_entry=0
  local entry
  for entry in "${SUMMARY_ITEMS[@]-}"; do
    IFS='|' read -r category name status _ t p f s _ <<< "$entry"
    [[ "$category" == "test" ]] || continue
    local group
    group=$(test_group_for "$category" "$name")
    [[ "$group" == "$target_group" ]] || continue
    has_entry=1
    total=$(( total + ${t:-0} ))
    passed=$(( passed + ${p:-0} ))
    failed=$(( failed + ${f:-0} ))
    skipped=$(( skipped + ${s:-0} ))
    [[ "$status" == "warn" ]] && (( warn++ ))
  done
  printf "%s|%s|%s|%s|%s|%s" "$total" "$passed" "$failed" "$skipped" "$warn" "$has_entry"
}

group_has_entries() {
  local target_group="$1"
  local entry
  for entry in "${SUMMARY_ITEMS[@]-}"; do
    IFS='|' read -r category name _ <<< "$entry"
    local group
    group=$(group_for_entry "$category" "$name")
    [[ "$group" == "$target_group" ]] && return 0
  done
  return 1
}

print_build_results_block() {
  local -a groups=("Build" "Package Build")
  print_section_header "Build Results"
  local any=0
  local group
  for group in "${groups[@]}"; do
    local counts
    counts=$(status_counts_for_groups "$group")
    IFS='|' read -r total success failed skipped warn <<< "$counts"
    if (( total == 0 )); then
      continue
    fi
    any=1
    printf "  %s: total %s (passed %s, failed %s, skipped %s, warnings %s)\n" \
      "$group" "$total" "$success" "$failed" "$skipped" "$warn"
  done
  if (( any == 0 )); then
    printf "  (none)\n"
  fi
  printf "\n"
}

print_test_results_block() {
  local package_counts ui_counts
  package_counts=$(test_counts_for_group "Package Tests")
  IFS='|' read -r pkg_total pkg_passed pkg_failed pkg_skipped pkg_warn pkg_present <<< "$package_counts"
  ui_counts=$(test_counts_for_group "UI Tests")
  IFS='|' read -r ui_total ui_passed ui_failed ui_skipped ui_warn ui_present <<< "$ui_counts"

  local -a groups=("Syntax" "AppSmoke" "Integration" "Lint")
  print_section_header "Test Results"
  local any=0
  local group
  for group in "${groups[@]}"; do
    if [[ "$group" == "Lint" ]]; then
      local lcounts
      lcounts=$(status_counts_for_groups "Lint")
      IFS='|' read -r ltotal lsuccess lfailed lskipped lwarn <<< "$lcounts"
      local lint_present=0
      group_has_entries "Lint" && lint_present=1
      if (( ltotal == 0 && lwarn == 0 && lint_present == 0 )); then
        continue
      fi
      any=1
      printf "  %s: total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)\n" \
        "$group" "$ltotal" "$lsuccess" "$lfailed" "$lskipped" "$lwarn"
    else
      local counts
      counts=$(test_counts_for_group "$group")
      IFS='|' read -r total passed failed skipped warn present <<< "$counts"

      # Check for build failures (error status with no test results)
      local status_counts error_count
      status_counts=$(status_counts_for_groups "$group")
      IFS='|' read -r _ _ error_count _ _ <<< "$status_counts"

      if (( total == 0 && warn == 0 && present == 0 )); then
        # If there's an error but no test results, it's likely a build failure
        if (( error_count > 0 )); then
          any=1
          printf "  %s: ❌ BUILD FAILED\n" "$group"
        fi
        continue
      fi
      any=1
      printf "  %s: total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)\n" \
        "$group" "$total" "$passed" "$failed" "$skipped" "$warn"
    fi
  done
  if (( any == 0 && pkg_present == 0 && ui_present == 0 )); then
    printf "  (none)\n"
  fi
  print_package_test_breakdown "$pkg_total" "$pkg_passed" "$pkg_failed" "$pkg_skipped" "$pkg_warn" "$pkg_present"
  print_ui_suite_results_summary "$ui_total" "$ui_passed" "$ui_failed" "$ui_skipped" "$ui_warn" "$ui_present"
  printf "\n"
}

print_package_test_breakdown() {
  local summary_total="$1"
  local summary_passed="$2"
  local summary_failed="$3"
  local summary_skipped="$4"
  local summary_warn="$5"
  local present="${6:-0}"
  if (( present == 0 )); then
    return
  fi
  local printed_header=0
  local entry
  for entry in "${SUMMARY_ITEMS[@]-}"; do
    IFS='|' read -r category name status log_path entry_total entry_passed entry_failed entry_skipped note <<< "$entry"
    [[ "$category" == "test" ]] || continue
    [[ "$name" == package\ * ]] || continue
    if (( printed_header == 0 )); then
      printf "  Package breakdown: total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)\n" \
        "${summary_total:-0}" "${summary_passed:-0}" "${summary_failed:-0}" "${summary_skipped:-0}" "${summary_warn:-0}"
      printed_header=1
    fi
    local entry_warn=0
    [[ "$status" == "warn" ]] && entry_warn=1
    printf "    %s – total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)" \
      "$name" "${entry_total:-0}" "${entry_passed:-0}" "${entry_failed:-0}" "${entry_skipped:-0}" "$entry_warn"
    if [[ -n "$log_path" ]]; then
      printf " – log: %s" "$log_path"
    fi
    printf "\n"
  done
}

print_ui_suite_results_summary() {
  local summary_total="$1"
  local summary_passed="$2"
  local summary_failed="$3"
  local summary_skipped="$4"
  local summary_warn="$5"
  local present="${6:-0}"
  if (( present == 0 )); then
    return
  fi
  local printed_header=0
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target suite duration status suite_total suite_failed suite_skipped <<< "$entry"
    [[ "$suite_target" == *UITests* ]] || continue
    if (( printed_header == 0 )); then
      printf "  UI suite results: total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)\n" \
        "${summary_total:-0}" "${summary_passed:-0}" "${summary_failed:-0}" "${summary_skipped:-0}" "${summary_warn:-0}"
    fi
    printed_header=1
    local passed=$(( ${suite_total:-0} - ${suite_failed:-0} - ${suite_skipped:-0} ))
    local suite_warn=0
    [[ "$status" == "warn" ]] && suite_warn=1
    printf "    %s – total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)\n" \
      "$suite" "${suite_total:-0}" "${passed:-0}" "${suite_failed:-0}" "${suite_skipped:-0}" "$suite_warn"
  done
}

print_ui_suite_breakdown() {
  local printed_header=0
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target suite duration status total failed skipped <<< "$entry"
    [[ "$suite_target" == *UITests* ]] || continue
    if (( printed_header == 0 )); then
      printf "  UI suites:\n"
      printed_header=1
    fi
    local symbol
    symbol=$(status_symbol "$status")
    local passed=$(( ${total:-0} - ${failed:-0} - ${skipped:-0} ))
    printf "    %s %s – total %s (✅ %s, ❌ %s, ⏭️ %s)\n" \
      "$symbol" "$suite" "${total:-0}" "${passed:-0}" "${failed:-0}" "${skipped:-0}"
  done
}

aggregate_suite_counts() {
  local target="$1"
  local total=0 failed=0 skipped=0
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target _ _ status suite_total suite_failed suite_skipped <<< "$entry"
    [[ "$suite_target" == "$target" ]] || continue
    (( total += suite_total ))
    (( failed += suite_failed ))
    (( skipped += suite_skipped ))
  done
  local passed=$(( total - failed - skipped ))
  printf '%s|%s|%s|%s' "$total" "$passed" "$failed" "$skipped"
}

print_timing_sections() {
  print_section_header "Timing"
  printf "Phase Timing:\n"
  print_phase_timing
  printf "\nTest Suite Timing:\n"
  print_test_suite_timing
}

print_grouped_timing_summary() {
  print_section_header "Summary Timing"
  local count=${#PRIMARY_ORDER[@]}
  local -a totals
  local -a details
  local overall=0
  local i
  for (( i=0; i<count; i++ )); do
    totals[i]=0
    details[i]=""
  done

  local entry
  for entry in "${PHASE_DURATION_ENTRIES[@]-}"; do
    IFS='|' read -r category name elapsed status <<< "$entry"
    local group
    group=$(phase_group_for "$category" "$name")
    [[ -z "$group" ]] && continue
    local idx
    idx=$(index_for_primary "$group")
    [[ -z "$idx" ]] && continue
    local seconds=${elapsed:-0}
    totals[idx]=$(( ${totals[idx]} + seconds ))
    overall=$((overall + seconds))
    local symbol
    symbol=$(status_symbol "$status")
    details[idx]+=$(printf '  %s %s – %s\n' "$symbol" "$name" "$(format_elapsed_time "$seconds")")
  done

  printf "Overall elapsed (phases sum): %s\n" "$(format_elapsed_time "$overall")"

  for i in "${!PRIMARY_ORDER[@]}"; do
    local total=${totals[i]}
    # Only show groups that ran
    if (( total == 0 )) && [[ -z "${details[i]}" ]]; then
      continue
    fi
    printf "%s: %s\n" "${PRIMARY_ORDER[i]}" "$(format_elapsed_time "$total")"
    # Suppress per-item timing details for aggregate-heavy or single-item groups to keep the summary concise.
    local suppress_details=0
    case "${PRIMARY_ORDER[i]}" in
      Build|Syntax|AppSmoke)
        suppress_details=1
        ;;
    esac
    if [[ -n "${details[i]}" ]] && (( suppress_details == 0 )); then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf "%s\n" "$line"
      done <<< "${details[i]}"
    else
      printf "  (none)\n"
    fi
    printf "\n"
  done
}

print_test_execution_summary() {
  local -a groups=("Unit Tests" "Integration Tests" "UI Tests" "Package Tests" "Other Tests")
  local group
  local entry
  local any=0
  for group in "${groups[@]}"; do
    local group_found=0
    for entry in "${SUMMARY_ITEMS[@]}"; do
      IFS='|' read -r category name status log_path total passed failed skipped note <<< "$entry"
      if [[ "$category" != "test" ]]; then
        continue
      fi
      local bucket
      bucket=$(categorize_test_entry "$name")
      if [[ "$bucket" == "$group" ]]; then
        if (( group_found == 0 )); then
          printf '%s:\n' "$group"
          group_found=1
        fi
        format_summary_line "$category" "$name" "$status" "$log_path" "$total" "$passed" "$failed" "$skipped" "$note"
        print_suite_breakdown "$name"
      fi
    done
    if (( group_found == 0 )); then
      continue
    fi
    any=1
  done
  if (( any == 0 )); then
    printf '  (none)\n'
  fi
}

print_grouped_test_summary() {
  print_section_header "Summary Tests"
  local count=${#PRIMARY_ORDER[@]}
  local -a totals passed failed skipped details
  local i
  for (( i=0; i<count; i++ )); do
    totals[i]=0; passed[i]=0; failed[i]=0; skipped[i]=0; details[i]=""
  done

  local entry
  for entry in "${SUMMARY_ITEMS[@]-}"; do
    IFS='|' read -r category name status log_path total passed_count failed_count skipped_count note <<< "$entry"
    # Only count entries that represent tests or report totals
    if [[ "$category" != "test" && -z "${total:-}" && -z "${passed_count:-}" && -z "${failed_count:-}" && -z "${skipped_count:-}" ]]; then
      continue
    fi
    local group
    group=$(test_group_for "$category" "$name")
    [[ -z "$group" ]] && continue
    local idx
    idx=$(index_for_primary "$group")
    [[ -z "$idx" ]] && continue
    totals[idx]=$(( ${totals[idx]} + ${total:-0} ))
    passed[idx]=$(( ${passed[idx]} + ${passed_count:-0} ))
    failed[idx]=$(( ${failed[idx]} + ${failed_count:-0} ))
    skipped[idx]=$(( ${skipped[idx]} + ${skipped_count:-0} ))
    local symbol
    symbol=$(status_symbol "$status")
    local suffix=""
    if [[ -n "$log_path" ]]; then
      suffix=" – log: $log_path"
    fi
    # Only append details when there is a non-zero total or failures/skips recorded.
    if [[ -n "$total" && "$total" != "0" ]] || [[ -n "$failed_count" && "$failed_count" != "0" ]] || [[ -n "$skipped_count" && "$skipped_count" != "0" ]]; then
      details[idx]+=$(printf '  %s %s – %s total (failed %s, skipped %s)%s\n' \
        "$symbol" "$name" "${total:-0}" "${failed_count:-0}" "${skipped_count:-0}" "$suffix")
    fi
  done

  local any=0
  for i in "${!PRIMARY_ORDER[@]}"; do
    local t=${totals[i]}
    local p=${passed[i]}
    local f=${failed[i]}
    local s=${skipped[i]}
    if (( t == 0 && p == 0 && f == 0 && s == 0 )) && [[ -z "${details[i]}" ]]; then
      continue
    fi
    any=1
    printf "%s: %s total (passed %s, failed %s, skipped %s)\n" "${PRIMARY_ORDER[i]}" "$t" "$p" "$f" "$s"
    if [[ -n "${details[i]}" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf "%s\n" "$line"
      done <<< "${details[i]}"
    else
      printf "  (none)\n"
    fi
    printf "\n"
  done

  if (( any == 0 )); then
    printf "  (none)\n"
    return
  fi

  local overall_total=0 overall_passed=0 overall_failed=0 overall_skipped=0
  for i in "${!PRIMARY_ORDER[@]}"; do
    overall_total=$((overall_total + totals[i]))
    overall_passed=$((overall_passed + passed[i]))
    overall_failed=$((overall_failed + failed[i]))
    overall_skipped=$((overall_skipped + skipped[i]))
  done
  printf "Overall: %s total (passed %s, failed %s, skipped %s)\n" \
    "$overall_total" "$overall_passed" "$overall_failed" "$overall_skipped"
}

print_summary() {
  (( SUMMARY_PRINTED == 0 )) || return
  SUMMARY_PRINTED=1

  if [[ ${#SUMMARY_ITEMS[@]} -eq 0 ]]; then
    print_section_header "Summary"
    printf 'No phases executed.\n'
    return
  fi

  local build_counts
  build_counts=$(tally_counts syntax build testplan script)
  IFS='|' read -r build_total build_success build_warn build_error build_interrupted <<< "$build_counts"

  local lint_counts
  lint_counts=$(tally_counts lint)
  IFS='|' read -r lint_total lint_success lint_warn lint_error lint_interrupted <<< "$lint_counts"

  print_group_timing_block "Build Timing" "Build" "Package Build"
  print_test_timing_block
  package_test_timing_breakdown
  ui_suite_timing_breakdown
  print_build_results_block
  print_test_results_block

  print_section_header "Overall Status"
  printf '  Exit Status: %s\n' "$EXIT_STATUS"
  if [[ -n "${START_TIME:-}" ]]; then
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    printf '  Elapsed Time: %s\n' "$(format_elapsed_time "$elapsed")"
  fi
}

print_phase_timing() {
  local -a phase_lines=()
  if [[ ${#PHASE_DURATION_ENTRIES[@]} -eq 0 ]]; then
    phase_lines+=("  (none)")
  else
    local entry
    for entry in "${PHASE_DURATION_ENTRIES[@]}"; do
      IFS='|' read -r category name elapsed status <<< "$entry"
      local formatted_elapsed
      formatted_elapsed=$(format_elapsed_time "$elapsed")
      local symbol
      symbol=$(status_symbol "$status")
      local scope="${category:-phase}"
      phase_lines+=("  ${symbol} ${name} – ${formatted_elapsed} (${scope})")
    done
  fi
  local line
  for line in "${phase_lines[@]}"; do
    printf '%s\n' "$line"
  done
  append_phase_timing_to_logs "${phase_lines[@]}"
}

append_phase_timing_to_logs() {
  [[ ${#RESULT_LOG_PATHS[@]} -gt 0 ]] || return
  local -a lines=("$@")
  local log_path
  for log_path in "${RESULT_LOG_PATHS[@]}"; do
    [[ -n "$log_path" && -f "$log_path" ]] || continue
    {
      printf '\n================================\nPhase Timing\n================================\n'
      local line
      for line in "${lines[@]}"; do
        printf '%s\n' "$line"
      done
    } >> "$log_path"
  done
}

print_test_suite_timing() {
  if [[ ${#TEST_SUITE_TIMING_ENTRIES[@]:-0} -eq 0 ]]; then
    printf '  (none)\n'
    return
  fi
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r target suite duration status total failed skipped <<< "$entry"
    local symbol
    symbol=$(status_symbol "$status")
    printf '  %s %s › %s – %s (%s tests)\n' \
      "$symbol" "$target" "$suite" "$(format_elapsed_time "${duration:-0}")" \
      "${total:-0}"
  done
  append_suite_timing_to_logs "${TEST_SUITE_TIMING_ENTRIES[@]-}"
}

append_suite_timing_to_logs() {
  [[ ${#RESULT_LOG_PATHS[@]} -gt 0 ]] || return
  local -a entries=("$@")
  local log_path
  for log_path in "${RESULT_LOG_PATHS[@]}"; do
    [[ -n "$log_path" && -f "$log_path" ]] || continue
    {
      printf '\nTest Suite Timing\n--------------------------------\n'
      local entry
      for entry in "${entries[@]}"; do
        IFS='|' read -r target suite duration status total failed skipped <<< "$entry"
        local symbol
        symbol=$(status_symbol "$status")
        printf '  %s %s › %s – %s (%s tests)\n' \
          "$symbol" "$target" "$suite" "$(format_elapsed_time "${duration:-0}")" \
          "${total:-0}"
      done
    } >> "$log_path"
  done
}

record_test_suite_timings() {
  local bundle="$1"
  local target_label="$2"
  local log_path="${3:-}"
  [[ -d "$bundle" ]] || return
  if ! command_exists python3 || ! command_exists xcrun; then
    return
  fi
  local output
  if ! output=$(python3 - "$bundle" "$target_label" <<'PY'
import json
import subprocess
import sys

bundle = sys.argv[1]
target_label = sys.argv[2]

def run_xcresult(identifier=None):
  args = ['xcrun', 'xcresulttool', 'get', '--format', 'json', '--legacy', '--path', bundle]
  if identifier:
    args.extend(['--id', identifier])
  result = subprocess.run(args, capture_output=True, text=True)
  if result.returncode != 0:
    raise RuntimeError("xcresulttool failed")
  return json.loads(result.stdout or "{}")

def walk_tests(node, prefix, results):
  name = node.get("name", {}).get("_value", "")
  status = node.get("testStatus", {}).get("_value", "").lower() or "unknown"
  duration = node.get("duration", {}).get("_value", 0) or 0
  subtests = node.get("subtests", {}).get("_values", [])
  if subtests:
    for child in subtests:
      walk_tests(child, prefix + [name], results)
  else:
    suite = "::".join(prefix) if prefix else name
    results.append((suite, status, duration))

try:
  root = run_xcresult()
except Exception:
  sys.exit(0)

actions = root.get("actions", {}).get("_values", [])
if not actions:
  sys.exit(0)

results = []
for action in actions:
  tests_ref = action.get("actionResult", {}).get("testsRef")
  if not tests_ref:
    continue
  identifier = tests_ref.get("id", {}).get("_value")
  if not identifier:
    continue
  data = run_xcresult(identifier)
  for summary in data.get("summaries", {}).get("_values", []):
    for testable in summary.get("testableSummaries", {}).get("_values", []):
      testable_name = testable.get("targetName", {}).get("_value", target_label)
      for test in testable.get("tests", {}).get("_values", []):
        walk_tests(test, [testable_name], results)

if not results:
  sys.exit(0)

from collections import defaultdict
aggregated = defaultdict(lambda: {"duration":0.0, "total":0, "failed":0, "skipped":0})
for suite, status, duration in results:
  info = aggregated[suite]
  info["duration"] += float(duration or 0)
  info["total"] += 1
  if status == "skipped":
    info["skipped"] += 1
  elif status == "failure":
    info["failed"] += 1

for suite, info in aggregated.items():
  status = "success"
  if info["failed"] > 0:
    status = "error"
  elif info["skipped"] > 0 and info["failed"] == 0:
    status = "warn"
  duration_int = int(round(info["duration"]))
  print(f"{suite}|{duration_int}|{status}|{info['total']}|{info['failed']}|{info['skipped']}")
PY
); then
    output=""
  fi
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      IFS='|' read -r suite duration status total failed skipped <<< "$line"
      TEST_SUITE_TIMING_ENTRIES+=("${target_label}|${suite}|${duration}|${status}|${total}|${failed}|${skipped}")
    done <<< "$output"
    return
  fi

  # Fallback: parse xcodebuild log for suite timing when xcresulttool is unavailable
  if [[ -n "$log_path" && -f "$log_path" ]]; then
    local log_output
    if log_output=$(python3 - "$log_path" "$target_label" <<'PY'
import re, sys

log_path = sys.argv[1]
target_label = sys.argv[2]
pattern = re.compile(r"Test Suite '([^']+)' (passed|failed) at .*Executed ([0-9]+) tests?, with ([0-9]+) failures .* in ([0-9.]+) ")
entries = []
with open(log_path, 'r', errors='ignore') as f:
  for line in f:
    match = pattern.search(line)
    if match:
      suite = match.group(1)
      status_text = match.group(2)
      total = int(match.group(3))
      failed = int(match.group(4))
      duration = float(match.group(5))
      skipped = 0
      status = "success"
      if failed > 0 or status_text == "failed":
        status = "error"
      entries.append((suite, int(round(duration)), status, total, failed, skipped))
if entries:
  for e in entries:
    print(f"{target_label}|{e[0]}|{e[1]}|{e[2]}|{e[3]}|{e[4]}|{e[5]}")
PY
    ); then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        TEST_SUITE_TIMING_ENTRIES+=("$line")
      done <<< "$log_output"
    fi
  fi
}

ensure_swift_format_tool() {
  local tool_root="${REPO_ROOT}/.build-tools/swift-format"
  local tool_binary="${tool_root}/.build/release/swift-format"
  if [[ -x "$tool_binary" ]]; then
    export PATH="${tool_root}/.build/release:${PATH}"
    return 0
  fi

  if ! command_exists git || ! command_exists swift; then
    return 1
  fi

  log_section "Bootstrapping swift-format"
  mkdir -p "${REPO_ROOT}/.build-tools"
  if [[ -d "$tool_root/.git" ]]; then
    log_info "Updating swift-format repository"
    (cd "$tool_root" && git fetch --depth 1 origin main && git reset --hard origin/main) || return 1
  else
    log_info "Cloning swift-format"
    git clone --depth 1 https://github.com/apple/swift-format.git "$tool_root" || return 1
  fi

  log_info "Building swift-format (release)"
  swift build -c release --product swift-format --package-path "$tool_root" || return 1

  if [[ -x "$tool_binary" ]]; then
    export PATH="${tool_root}/.build/release:${PATH}"
    return 0
  fi
  return 1
}

ensure_scheme_available() {
  if [[ $SCHEME_RESOLVED -eq 1 ]]; then
    return
  fi

  local -a candidates=()
  if [[ -n "$SCHEME" ]]; then
    candidates+=("$SCHEME")
  fi
  candidates+=("${SCHEME_CANDIDATES[@]}")

  local list_output
  set +e
  list_output=$(xcodebuild -workspace "$WORKSPACE" -list 2>/dev/null)
  local list_status=$?
  set -e
  if [[ $list_status -ne 0 || -z "$list_output" ]]; then
    log_error "Unable to list schemes for workspace '$WORKSPACE'"
    update_exit_status 1
    finalize_and_exit 1
  fi

  local available_list
  available_list=$(printf "%s" "$list_output" | awk '
    /^ *Schemes:/ { capture=1; next }
    capture && NF==0 { exit }
    capture { sub(/^ +/,""); print }
  ') || {
    log_error "Failed to parse schemes for workspace '$WORKSPACE'"
    update_exit_status 1
    finalize_and_exit 1
  }

  if [[ -z "$available_list" ]]; then
    log_error "No schemes found in workspace '$WORKSPACE'"
    update_exit_status 1
    finalize_and_exit 1
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -z "$candidate" ]] && continue
    if printf '%s
' "$available_list" | grep -Fxq "$candidate"; then
      if [[ "$candidate" != "$SCHEME" ]]; then
        log_info "Using scheme '$candidate'"
      fi
      SCHEME="$candidate"
      SCHEME_RESOLVED=1
      return
    fi
  done

  local first_scheme
  first_scheme=$(printf '%s
' "$available_list" | sed -n '1p')
  if [[ -n "$first_scheme" ]]; then
    log_info "Using scheme '$first_scheme'"
    SCHEME="$first_scheme"
    SCHEME_RESOLVED=1
    return
  fi

  log_error "Unable to locate a usable scheme in workspace '$WORKSPACE'"
  update_exit_status 1
  finalize_and_exit 1
}


show_help() {
  cat <<EOF
Usage: scripts/run-xcode-tests.sh [OPTIONS]

Options:
  -b <targets>      Comma-separated list of build targets (e.g. zpod,CoreModels)
  -t <tests>        Comma-separated list of tests (target, class, or class/method)
  -c                Clean before running build/test
  -s                Run Swift syntax verification only (no build or tests)
  -l                Run Swift lint checks (swiftlint/swift-format if available)
  -p [suite]        Verify test plan coverage (optional suite: default, AppSmokeTests, zpodUITests, IntegrationTests)
  --scheme <name>   Xcode scheme to use (default: "zpod (zpod project)")
  --workspace <ws>  Path to workspace (default: zpod.xcworkspace)
  --sim <device>    Preferred simulator name (default: "iPhone 17 Pro")
  --self-check      Run environment self-checks and exit
  --help            Show this message
EOF
}

self_check() {
  log_section "Self-check"
  log_info "Repository root: ${REPO_ROOT}"
  log_info "Script root: ${SCRIPT_ROOT}"

 if is_macos; then
   if command_exists xcodebuild; then
      local xcode_version
      xcode_version=$(xcodebuild -version 2>/dev/null)
      xcode_version=${xcode_version%%$'\n'*}
      log_info "xcodebuild available: ${xcode_version}"
    else
      log_warn "xcodebuild missing. macOS builds will fall back to Swift Package workflows."
    fi
  else
    log_info "Non-macOS environment detected, will rely on Swift Package Manager"
  fi

  if command_exists swift; then
    local swift_version
    swift_version=$(swift --version 2>/dev/null)
    swift_version=${swift_version%%$'\n'*}
    log_info "swift toolchain: ${swift_version}"
  else
    log_error "swift command not found"
    return 1
  fi

  if [[ ! -d "${REPO_ROOT}/Scripts" && ! -d "${REPO_ROOT}/scripts" ]]; then
    log_warn "Unexpected scripts directory layout"
  fi

  REQUESTED_BUILDS="zpod"
  REQUESTED_TESTS="AppSmokeTests"
  log_info "Argument parsing sanity check passed"

  log_success "Self-check complete"
  return 0
}

require_workspace() {
  if [[ -d "$WORKSPACE" ]]; then
    if [[ ! -f "$WORKSPACE/contents.xcworkspacedata" ]]; then
      log_error "Workspace directory ${WORKSPACE} is missing contents.xcworkspacedata"
      update_exit_status 1
      finalize_and_exit 1
    fi
  elif [[ -f "$WORKSPACE" ]]; then
    return
  else
    log_error "Workspace not found at ${WORKSPACE}"
    update_exit_status 1
    finalize_and_exit 1
  fi
}

is_package_target() {
  local target="$1"
  [[ -d "${REPO_ROOT}/Packages/${target}" ]]
}

list_package_targets() {
  [[ -d "${REPO_ROOT}/Packages" ]] || return 0
  find "${REPO_ROOT}/Packages" -mindepth 1 -maxdepth 1 -type d \
    ! -name '.git' ! -name '.swiftpm' ! -name '.DS_Store' \
    -exec basename {} \; | sort
}

package_supports_host_build() {
  local package="$1"
  local manifest="${REPO_ROOT}/Packages/${package}/Package.swift"
  [[ -f "$manifest" ]] || return 0
  if ! grep -q "platforms" "$manifest"; then
    return 0
  fi
  # Check for uncommented .macOS platform declaration
  if grep -v '^\s*//' "$manifest" | grep -q ".macOS"; then
    return 0
  fi
  return 1
}

find_package_for_test_target() {
  local identifier="$1"
  [[ -z "$identifier" ]] && return 1
  local pkg_dir pkg_name
  for pkg_dir in "${REPO_ROOT}/Packages"/*; do
    [[ -d "$pkg_dir" ]] || continue
    pkg_name="$(basename "$pkg_dir")"
    if [[ "$identifier" == "$pkg_name" ]]; then
      echo "$pkg_name"
      return 0
    fi
    if [[ -d "$pkg_dir/Tests/$identifier" ]]; then
      echo "$pkg_name"
      return 0
    fi
  done
  return 1
}

dev_build_enhanced_syntax() {
  ensure_command swift "swift toolchain is required for syntax checks"

  log_section "🔨 zPodcastAddict Development Build Script"
  log_info "Project root: ${REPO_ROOT}"

  log_section "Checking Swift Syntax"
  local error_count=0

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    log_info "Checking: $(basename "$file")"
    if ! swift -frontend -parse "$file" >/dev/null 2>&1; then
      log_error "Syntax error in $file"
      swift -frontend -parse "$file" 2>&1 | head -10 || true
      ((error_count++))
    else
      log_success "$(basename "$file")"
    fi
  done < <(find "$REPO_ROOT" -type f -name "*.swift" \
    ! -path "*/.build/*" ! -path "*/build/*" ! -path "*/.swiftpm/*")

  echo
  if (( error_count == 0 )); then
    log_success "All Swift files passed syntax check"
  else
    log_error "Found ${error_count} syntax errors"
    return 1
  fi
}

run_syntax_check() {
  init_result_paths "syntax" "swift"
  register_result_log "$RESULT_LOG"
  log_section "Syntax check"
  set +e
  (
    cd "$REPO_ROOT"
    dev_build_enhanced_syntax
  ) | tee "$RESULT_LOG"
  local syntax_status=${PIPESTATUS[0]}
  set -e

  local note=""
  note=$(summarize_syntax_log "$RESULT_LOG")

  if (( syntax_status != 0 )); then
    log_error "Syntax check failed (status ${syntax_status}) -> $RESULT_LOG"
    add_summary "syntax" "Swift syntax" "error" "$RESULT_LOG" "" "" "" "" "failed"
    update_exit_status "$syntax_status"
    return "$syntax_status"
  fi

  log_success "Syntax check finished -> $RESULT_LOG"
  add_summary "syntax" "Swift syntax" "success" "$RESULT_LOG" "" "" "" "" "$note"
  return 0
}

build_app_target() {
  local target_label="$1"
  require_xcodebuild || return 1
  require_workspace
  ensure_scheme_available
  init_result_paths "build" "$target_label"
  register_result_log "$RESULT_LOG"
  local resolved_scheme="$SCHEME"
  local resolved_destination=""
  if [[ "$target_label" == "IntegrationTests" ]]; then
    resolved_scheme="IntegrationTests"
  fi
  select_destination "$WORKSPACE" "$resolved_scheme" "$PREFERRED_SIM"
  resolved_destination="$SELECTED_DESTINATION"
  if [[ "$target_label" == "zpod" && -n "${ZPOD_SIMULATOR_UDID:-}" ]]; then
    resolved_destination="id=${ZPOD_SIMULATOR_UDID}"
  fi

  local -a args=(
    -workspace "$WORKSPACE"
    -scheme "$resolved_scheme"
    -destination "$resolved_destination"
    -resultBundlePath "$RESULT_BUNDLE"
  )
  if [[ -n "${ZPOD_DERIVED_DATA_PATH:-}" ]]; then
    mkdir -p "$ZPOD_DERIVED_DATA_PATH"
    args+=(-derivedDataPath "$ZPOD_DERIVED_DATA_PATH")
  fi
  if [[ $REQUESTED_CLEAN -eq 1 ]]; then
    args+=(clean)
  fi
  args+=(build)

  log_section "xcodebuild ${target_label}"
  set +e
  xcodebuild_wrapper "${args[@]}" | tee "$RESULT_LOG"
  local xc_status=${PIPESTATUS[0]}
  set -e

  local note=""
  note=$(collect_build_summary_info "$RESULT_LOG")

  if (( xc_status != 0 )); then
    log_error "Build failed (${target_label}) status ${xc_status} -> $RESULT_LOG"
    add_summary "build" "${target_label}" "error" "$RESULT_LOG" "" "" "" "" "failed"
    update_exit_status "$xc_status"
    return "$xc_status"
  fi

  log_success "Build finished -> $RESULT_LOG"
  add_summary "build" "${target_label}" "success" "$RESULT_LOG" "" "" "" "" "$note"
  return 0
}

build_package_target() {
  local package="$1"
  if package_supports_host_build "$package"; then
    :
  else
    log_warn "Skipping swift build for package '${package}' (host platform unsupported; built via workspace targets)"
    add_summary "build" "package ${package}" "warn" "" "" "" "" "" "skipped (host platform unsupported)"
    return 0
  fi
  init_result_paths "build_pkg" "$package"
  register_result_log "$RESULT_LOG"
  log_section "swift build (${package})"
  set +e
  build_swift_package "$package" "$REQUESTED_CLEAN"
  local pkg_status=$?
  set -e

  local note=""
  note=$(collect_build_summary_info "$RESULT_LOG")

  if (( pkg_status != 0 )); then
    log_error "Package build failed (${package}) status ${pkg_status} -> $RESULT_LOG"
    add_summary "build" "package ${package}" "error" "$RESULT_LOG" "" "" "" "" "failed"
    update_exit_status "$pkg_status"
    return "$pkg_status"
  fi

  log_success "Package build finished -> $RESULT_LOG"
  add_summary "build" "package ${package}" "success" "$RESULT_LOG" "" "" "" "" "$note"
  return 0
}

build_for_testing_phase() {
  # Build-once-test-many optimization: Build zpod.app + ALL test bundles in one xcodebuild invocation
  # This eliminates redundant rebuilds (previously: 3x zpod.app builds during regression)
  # Output: zpod.app + AppSmokeTests.xctest + IntegrationTests.xctest + zpodUITests.xctest
  require_xcodebuild || return 1
  require_workspace
  ensure_scheme_available
  init_result_paths "build" "build-for-testing"
  register_result_log "$RESULT_LOG"

  select_destination "$WORKSPACE" "$SCHEME" "$PREFERRED_SIM"
  local resolved_destination="$SELECTED_DESTINATION"

  local -a args=(
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -destination "$resolved_destination"
    -resultBundlePath "$RESULT_BUNDLE"
  )

  if [[ -n "${ZPOD_DERIVED_DATA_PATH:-}" ]]; then
    mkdir -p "$ZPOD_DERIVED_DATA_PATH"
    args+=(-derivedDataPath "$ZPOD_DERIVED_DATA_PATH")
  fi

  # CI safe mode: Clean DerivedData before build to avoid stale artifacts
  if [[ "${ZPOD_CI_SAFE_MODE:-0}" == "1" ]]; then
    log_info "CI safe mode: cleaning DerivedData before build-for-testing"
    if [[ -n "${ZPOD_DERIVED_DATA_PATH:-}" ]]; then
      rm -rf "$ZPOD_DERIVED_DATA_PATH"/*
    else
      rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/*
    fi
    REQUESTED_CLEAN=1
  fi

  if [[ $REQUESTED_CLEAN -eq 1 ]]; then
    args+=(clean)
  fi

  args+=(build-for-testing)

  log_section "xcodebuild build-for-testing"
  set +e
  xcodebuild_wrapper "${args[@]}" | tee "$RESULT_LOG"
  local xc_status=${PIPESTATUS[0]}
  set -e

  local note=""
  note=$(collect_build_summary_info "$RESULT_LOG")

  if (( xc_status != 0 )); then
    log_error "Build-for-testing failed: status ${xc_status} -> $RESULT_LOG"
    add_summary "build" "build-for-testing" "error" "$RESULT_LOG" "" "" "" "" "failed"
    update_exit_status "$xc_status"
    return "$xc_status"
  fi

  log_success "Build-for-testing finished -> $RESULT_LOG"
  add_summary "build" "build-for-testing" "success" "$RESULT_LOG" "" "" "" "" "$note"
  return 0
}

run_build_target() {
  local target="$1"
  case "$target" in
    all)
      if ! build_app_target "zpod"; then
        return $?
      fi
      local pkg
      while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if ! build_package_target "$pkg"; then
          return $?
        fi
      done < <(list_package_targets)
      ;;
    zpod)
      build_app_target "$target" || return $?;;
    "") ;;
    *)
      if is_package_target "$target"; then
        build_package_target "$target" || return $?
      else
        log_error "Unknown build target: $target"
        update_exit_status 1
        finalize_and_exit 1
      fi
      ;;
  esac
}

test_app_target() {
  local target="$1"
  require_workspace
  ensure_scheme_available
  if ! command_exists xcodebuild; then
    log_warn "xcodebuild unavailable, running package fallback"
    init_result_paths "test_fallback" "$target"
    register_result_log "$RESULT_LOG"
    run_swift_package_tests
    return 0
  fi

  local resolved_scheme="$SCHEME"
  local resolved_destination=""
  if [[ "$target" == "IntegrationTests" ]]; then
    resolved_scheme="IntegrationTests"
  fi
  select_destination "$WORKSPACE" "$resolved_scheme" "$PREFERRED_SIM"
  resolved_destination="$SELECTED_DESTINATION"

  if [[ "$target" == "zpod" ]]; then
    local clean_flag=$REQUESTED_CLEAN
    run_filtered_xcode_tests "${target}-smoke" "$clean_flag" "AppSmokeTests"
    run_filtered_xcode_tests "${target}-ui" 0 "zpodUITests"
    return
  fi

  if [[ "$target" == "AppSmokeTests" ]]; then
    local clean_flag=$REQUESTED_CLEAN
    run_filtered_xcode_tests "AppSmokeTests" "$clean_flag" "AppSmokeTests"
    return
  fi

  init_result_paths "test" "$target"
  register_result_log "$RESULT_LOG"
  if [[ $DESTINATION_IS_GENERIC -eq 1 ]]; then
    if [[ "$target" == "AppSmokeTests" || "$target" == "zpodUITests" || "$target" == "IntegrationTests" ]]; then
      log_error "No concrete iOS Simulator runtime is available; cannot execute ${target}"
      log_error "Ensure the 'Ensure iOS Simulator runtime is installed' step downloads a device runtime before running tests."
      add_summary "test" "${target}" "error" "" "" "" "" "" "failed (no simulator runtime)"
      update_exit_status 2
      return 2
    fi
    log_warn "Generic simulator destination detected; running build only"
    if ! build_app_target "$target"; then
      return $?
    fi
    add_summary "test" "${target}" "warn" "" "" "" "" "" "build only (generic simulator destination)"
    return 0
  fi

  local -a args=(
    -workspace "$WORKSPACE"
    -scheme "$resolved_scheme"
    -destination "$resolved_destination"
    -resultBundlePath "$RESULT_BUNDLE"
  )

  if [[ -n "${ZPOD_DERIVED_DATA_PATH:-}" ]]; then
    mkdir -p "$ZPOD_DERIVED_DATA_PATH"
    args+=(-derivedDataPath "$ZPOD_DERIVED_DATA_PATH")
  fi
  local use_test_without_building=0
  if [[ "${ZPOD_TEST_WITHOUT_BUILDING:-0}" == "1" ]]; then
    use_test_without_building=1
  fi

  if [[ $REQUESTED_CLEAN -eq 1 && $use_test_without_building -eq 0 ]]; then
    args+=(clean)
  fi

  local -a action_args=()
  if [[ $use_test_without_building -eq 1 ]]; then
    action_args+=(test-without-building)
  else
    action_args+=(build test)
  fi

  case "$target" in
    all|zpod)
      args+=("${action_args[@]}");;
    AppSmokeTests|zpodTests|zpodUITests)
      args+=("${action_args[@]}" -only-testing:"$target")
      if [[ "$target" == "zpodUITests" ]]; then
        args+=(-skip-testing:IntegrationTests)
      fi
      ;;
    IntegrationTests)
      args+=("${action_args[@]}");;
    */*)
      args+=("${action_args[@]}" -only-testing:"$target")
      if [[ "$target" == zpodUITests/* ]]; then
        args+=(-skip-testing:IntegrationTests)
      fi
      ;;
    *)
      args+=("${action_args[@]}")
      ;;
  esac

  log_section "xcodebuild tests (${target})"
  local -a original_args=("${args[@]}")
  run_tests_once() {
    set +e
    local timeout_seconds
    timeout_seconds=$(resolve_xcodebuild_timeout "$target")
    ZPOD_XCODEBUILD_TIMEOUT_SECONDS="$timeout_seconds" xcodebuild_wrapper "${args[@]}" 2>&1 | tee "$RESULT_LOG"
    local status=${PIPESTATUS[0]}
    set -e
    return "$status"
  }

  run_tests_once
  local xc_status=$?

  # Retry once on simulator boot failure by reselecting destination and rerunning.
  local temp_sim_udid=""
  if [[ $xc_status -ne 0 ]] && [[ -f "$RESULT_LOG" ]] && is_sim_boot_failure_log "$RESULT_LOG"; then
    log_warn "Simulator boot failure detected; reselecting destination and retrying once..."
    select_destination "$WORKSPACE" "$resolved_scheme" "$PREFERRED_SIM"
    resolved_destination="$SELECTED_DESTINATION"
    args=("${original_args[@]}")
    local idx
    for idx in "${!args[@]}"; do
      if [[ "${args[$idx]}" == "-destination" ]]; then
        args[$((idx + 1))]="$resolved_destination"
        break
      fi
    done
    run_tests_once
    xc_status=$?
  fi

  # If the retry still failed due to boot issues, reset CoreSimulator and create a fresh simulator once.
  if [[ $xc_status -ne 0 ]] && [[ -f "$RESULT_LOG" ]] && is_sim_boot_failure_log "$RESULT_LOG"; then
    log_warn "Simulator boot failure persists; resetting CoreSimulator service..."
    reset_core_simulator_service
    log_warn "Retrying ${target} with a freshly created simulator..."
    local new_udid=""
    if new_udid=$(create_ephemeral_simulator 2>/dev/null); then
      temp_sim_udid="$new_udid"
      log_info "Retrying ${target} with simulator id=${temp_sim_udid}"
      args=("${original_args[@]}")
      local idx
      for idx in "${!args[@]}"; do
        if [[ "${args[$idx]}" == "-destination" ]]; then
          args[$((idx + 1))]="id=${temp_sim_udid}"
          break
        fi
      done
      run_tests_once
      xc_status=$?
    else
      log_warn "Failed to provision a fresh simulator; keeping previous failure"
    fi
  fi

  cleanup_ephemeral_simulator "$temp_sim_udid"

  # Parse test results from log file as fallback
  local log_total=0 log_passed=0 log_failed=0
  if [[ -f "$RESULT_LOG" ]]; then
    # Extract: "Executed X tests, with Y failures"
    if grep -q "Executed.*tests.*with.*failures" "$RESULT_LOG"; then
      log_total=$(grep -o "Executed [0-9]* test" "$RESULT_LOG" | tail -1 | grep -o "[0-9]*" || echo "0")
      log_failed=$(grep -o "with [0-9]* failure" "$RESULT_LOG" | tail -1 | grep -o "[0-9]*" || echo "0")
      log_passed=$((log_total - log_failed))
    fi
  fi

  if [[ $xc_status -ne 0 ]]; then
    record_test_suite_timings "$RESULT_BUNDLE" "$target" "$RESULT_LOG"
    xcresult_has_failures "$RESULT_BUNDLE"
    local inspect_status=$?
    case $inspect_status in
      0)
        # xcresult confirmed failures
        log_error "Tests failed (status $xc_status) -> $RESULT_LOG"
        add_summary "test" "${target}" "error" "$RESULT_LOG" "" "" "" "" "failed"
        update_exit_status "$xc_status"
        return "$xc_status"
        ;;
      1)
        # xcresult says no failures, check log
        if (( log_failed > 0 )); then
          log_error "Tests failed (status $xc_status) -> $RESULT_LOG"
          add_summary "test" "${target}" "error" "$RESULT_LOG" "$log_total" "$log_passed" "$log_failed" "0" "failed"
          update_exit_status "$xc_status"
          return "$xc_status"
        fi
        log_warn "xcodebuild exited with status $xc_status but no test failures detected; treating as success"
        ;;
      *)
        # xcresult inspection failed, rely on log parsing
        log_warn "xcodebuild exited with status $xc_status and result bundle could not be inspected; checking log"
        if (( log_failed > 0 )); then
          log_error "Tests failed (from log) -> $RESULT_LOG"
          add_summary "test" "${target}" "error" "$RESULT_LOG" "$log_total" "$log_passed" "$log_failed" "0" "failed (from log)"
          update_exit_status "$xc_status"
          return "$xc_status"
        elif (( log_total > 0 && log_passed > 0 )); then
          log_success "Tests passed (from log) despite exit code $xc_status -> $RESULT_LOG"
          # Continue to add success summary below
        else
          log_error "Could not determine test results (status $xc_status) -> $RESULT_LOG"
          add_summary "test" "${target}" "error" "$RESULT_LOG" "" "" "" "" "result inspection failed"
          update_exit_status "$xc_status"
          return "$xc_status"
        fi
        ;;
    esac
  fi

  log_success "Tests finished -> $RESULT_LOG"
  local summary_text=""
  local total="" passed="" failed="" skipped="" note=""
  if summary_text=$(xcresult_summary "$RESULT_BUNDLE" 2>/dev/null); then
    local counts=""
    if counts=$(extract_test_counts "$summary_text"); then
      IFS='|' read -r total passed failed skipped <<< "$counts"
    else
      note="$summary_text"
    fi
  elif (( log_total > 0 )); then
    # Fallback to log-based counts if xcresult unavailable
    total=$log_total
    passed=$log_passed
    failed=$log_failed
    skipped=0
    note="from log"
  fi
  record_test_suite_timings "$RESULT_BUNDLE" "$target" "$RESULT_LOG"
  if [[ -z "$total" || "$total" -eq 0 ]]; then
    local suite_counts
    suite_counts=$(aggregate_suite_counts "$target")
    IFS='|' read -r total passed failed skipped <<< "$suite_counts"
  fi
  if [[ -n "$total" ]]; then
    if [[ -z "$passed" ]]; then
      local computed=$(( total - failed - skipped ))
      if (( computed < 0 )); then
        computed=0
        note="${note:+$note; }adjusted counts"
      fi
      passed=$computed
    fi
  fi
  if [[ -n "$total" && "$total" -gt 0 && "$log_total" -eq 0 ]]; then
    log_info "xcresult counts: ${total} run, ${passed} passed, ${failed} failed, ${skipped} skipped"
    if [[ -n "$RESULT_LOG" && -f "$RESULT_LOG" ]]; then
      {
        printf '\nTest Results (xcresult)\n--------------------------------\n'
        printf 'Executed %s tests, with %s failures, %s skipped\n' "$total" "$failed" "$skipped"
      } >> "$RESULT_LOG"
    fi
  fi
  add_summary "test" "${target}" "success" "$RESULT_LOG" "$total" "$passed" "$failed" "$skipped" "$note"
  return 0
}

test_package_target() {
  local package="$1"
  init_result_paths "test_pkg" "$package"
  register_result_log "$RESULT_LOG"
  
  # Check if package has a Tests directory
  local pkg_path="${REPO_ROOT}/Packages/${package}"
  if [[ ! -d "${pkg_path}/Tests" ]]; then
    log_warn "Skipping swift test for package '${package}' (no Tests directory)"
    printf "⚠️ Package %s skipped: no Tests directory found.\n" "$package" | tee "$RESULT_LOG" >/dev/null
    add_summary "test" "package ${package}" "warn" "$RESULT_LOG" "" "" "" "" "skipped (no tests)"
    return 0
  fi
  
  if package_supports_host_build "$package"; then
    :
  else
    log_warn "Skipping swift test for package '${package}' (host platform unsupported on this machine)"
    printf "⚠️ Package %s skipped: host platform does not match declared platforms.\n" "$package" | tee "$RESULT_LOG" >/dev/null
    add_summary "test" "package ${package}" "warn" "$RESULT_LOG" "" "" "" "" "skipped (host platform unsupported)"
    return 0
  fi
  log_section "swift test (${package})"
  set +e
  run_swift_package_target_tests "$package" "$REQUESTED_CLEAN"
  local pkg_status=$?
  set -e

  if (( pkg_status != 0 )); then
    log_error "Package tests failed (${package}) status ${pkg_status} -> $RESULT_LOG"
    add_summary "test" "package ${package}" "error" "$RESULT_LOG" "" "" "" "" "failed"
    update_exit_status "$pkg_status"
    return 0  # Continue with other packages despite failure
  fi

  log_success "Package tests finished -> $RESULT_LOG"
  local pt_total="" pt_passed="" pt_failed="" pt_skipped=""
  if grep -q "Executed [0-9]* tests" "$RESULT_LOG"; then
    local counts_line
    counts_line=$(grep -E "Executed [0-9]+ tests?, with [0-9]+ failures?" "$RESULT_LOG" | tail -1)
    if [[ $counts_line =~ Executed[[:space:]]+([0-9]+)[[:space:]]+tests?,[[:space:]]+with[[:space:]]+([0-9]+)[[:space:]]+failures? ]]; then
      pt_total="${BASH_REMATCH[1]}"
      pt_failed="${BASH_REMATCH[2]}"
      pt_passed=$(( pt_total - pt_failed ))
      pt_skipped=0
    fi
  fi
  add_summary "test" "package ${package}" "success" "$RESULT_LOG" "$pt_total" "$pt_passed" "$pt_failed" "$pt_skipped"
  return 0
}

run_swift_lint() {
  init_result_paths "lint" "swift"
  register_result_log "$RESULT_LOG"
  log_section "Swift lint"

  if command_exists swiftlint; then
    set +e
    (
      cd "$REPO_ROOT"
      swiftlint lint
    ) | tee "$RESULT_LOG"
    local lint_status=${PIPESTATUS[0]}
    set -e
    local note=""
    note=$(summarize_lint_log "swiftlint" "$RESULT_LOG")
    if (( lint_status != 0 )); then
      log_warn "SwiftLint reported violations (status ${lint_status}) -> $RESULT_LOG"
      add_summary "lint" "swiftlint" "warn" "$RESULT_LOG" "" "" "" "" "${note:-violations}"
      return 0
    fi
    log_success "SwiftLint finished -> $RESULT_LOG"
    add_summary "lint" "swiftlint" "success" "$RESULT_LOG" "" "" "" "" "$note"
    return 0
  fi

  if command_exists swift-format; then
    set +e
    (
      cd "$REPO_ROOT"
      swift-format lint --recursive .
    ) | tee "$RESULT_LOG"
    local lint_status=${PIPESTATUS[0]}
    set -e
    local note=""
    note=$(summarize_lint_log "swift-format" "$RESULT_LOG")
    if (( lint_status != 0 )); then
      log_warn "swift-format reported violations (status ${lint_status}) -> $RESULT_LOG"
      add_summary "lint" "swift-format" "warn" "$RESULT_LOG" "" "" "" "" "${note:-violations}"
      return 0
    fi
    log_success "swift-format lint finished -> $RESULT_LOG"
    add_summary "lint" "swift-format" "success" "$RESULT_LOG" "" "" "" "" "$note"
    return 0
  fi

  if command_exists swiftformat; then
    set +e
    (
      cd "$REPO_ROOT"
      swiftformat --lint .
    ) | tee "$RESULT_LOG"
    local lint_status=${PIPESTATUS[0]}
    set -e
    local note=""
    note=$(summarize_lint_log "swiftformat" "$RESULT_LOG")
    if (( lint_status != 0 )); then
      log_warn "swiftformat reported violations (status ${lint_status}) -> $RESULT_LOG"
      add_summary "lint" "swiftformat" "warn" "$RESULT_LOG" "" "" "" "" "${note:-violations}"
      return 0
    fi
    log_success "swiftformat lint finished -> $RESULT_LOG"
    add_summary "lint" "swiftformat" "success" "$RESULT_LOG" "" "" "" "" "$note"
    return 0
  fi

  if ensure_swift_format_tool; then
    if command_exists swift-format; then
      set +e
      (
        cd "$REPO_ROOT"
        swift-format lint --recursive .
      ) | tee "$RESULT_LOG"
      local lint_status=${PIPESTATUS[0]}
      set -e
      local note=""
      note=$(summarize_lint_log "swift-format" "$RESULT_LOG")
      if (( lint_status != 0 )); then
        log_warn "swift-format reported violations (status ${lint_status}) -> $RESULT_LOG"
        add_summary "lint" "swift-format" "warn" "$RESULT_LOG" "" "" "" "" "${note:-violations}"
        return 0
      fi
      log_success "swift-format lint finished -> $RESULT_LOG"
      add_summary "lint" "swift-format" "success" "$RESULT_LOG" "" "" "" "" "$note"
      return 0
    fi
  fi

  log_warn "No Swift lint tool available (swiftlint/swift-format/swiftformat)."

  local in_ci=0
  if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" ]]; then
    in_ci=1
  fi

  if command_exists brew; then
    log_section "Installing SwiftLint via Homebrew"
    if brew list swiftlint >/dev/null 2>&1; then
      brew upgrade swiftlint || true
    else
      brew install swiftlint || true
    fi

    if command_exists swiftlint; then
      set +e
      (
        cd "$REPO_ROOT"
        swiftlint lint
      ) | tee "$RESULT_LOG"
      local lint_status=${PIPESTATUS[0]}
      set -e
      local note=""
      note=$(summarize_lint_log "swiftlint" "$RESULT_LOG")
      if (( lint_status != 0 )); then
        log_warn "SwiftLint reported violations (status ${lint_status}) -> $RESULT_LOG"
        add_summary "lint" "swiftlint" "warn" "$RESULT_LOG" "" "" "" "" "${note:-violations}"
        return 0
      fi
      log_success "SwiftLint finished -> $RESULT_LOG"
      add_summary "lint" "swiftlint" "success" "$RESULT_LOG" "" "" "" "" "$note"
      return 0
    fi
    log_warn "SwiftLint installation attempt failed or command still unavailable."
  else
    log_warn "Homebrew not found; cannot auto-install SwiftLint."
  fi

  cat <<'EOF' | tee "$RESULT_LOG"
Lint tool unavailable; skipped lint step.

To enable linting install one of the supported tools and ensure it is on PATH before rerunning:
  • SwiftLint      `brew install swiftlint`
  • swift-format   `brew install swift-format`
  • SwiftFormat    `brew install swiftformat`

After installation rerun ./scripts/run-xcode-tests.sh so the lint phase executes.
EOF
  add_summary "lint" "swift" "warn" "$RESULT_LOG" "" "" "" "" "tool unavailable"
  if [[ $in_ci -eq 1 ]]; then
    log_warn "Continuing without lint (CI environment)."
    return 0
  fi
  return 1
}

run_testplan_check() {
  local suite="$1"
  local label="${suite:-default}"
  init_result_paths "testplan" "$label"
  register_result_log "$RESULT_LOG"
  if verify_testplan_coverage "$suite" > >(tee "$RESULT_LOG") 2>&1; then
    local note
    note=$(summarize_testplan_note)
    add_summary "testplan" "${label}" "success" "$RESULT_LOG" "" "" "" "" "$note"
    return 0
  else
    local status=$?
    local note
    note=$(summarize_testplan_note)
    if [[ $status -eq 2 ]]; then
      if [[ -z "$note" ]]; then
        note="incomplete"
      fi
      add_summary "testplan" "${label}" "warn" "$RESULT_LOG" "" "" "" "" "$note"
    else
      if [[ -z "$note" ]]; then
        note="failed"
      fi
      add_summary "testplan" "${label}" "warn" "$RESULT_LOG" "" "" "" "" "$note"
    fi
    return $status
  fi
}

run_filtered_xcode_tests() {
  local label="$1"
  local clean_flag="$2"
  shift 2
  local -a filters=("$@")

  ensure_scheme_available

  local integration_run=0
  local filter
  for filter in "${filters[@]}"; do
    if [[ "$filter" == IntegrationTests* ]]; then
      integration_run=1
      break
    fi
  done

  local resolved_scheme="$SCHEME"
  local resolved_destination=""
  if [[ $integration_run -eq 1 ]]; then
    resolved_scheme="IntegrationTests"
  fi
  select_destination "$WORKSPACE" "$resolved_scheme" "$PREFERRED_SIM"
  resolved_destination="$SELECTED_DESTINATION"

  if [[ $integration_run -eq 0 ]]; then
    ensure_host_app_product || return $?
  fi

  init_result_paths "test" "$label"
  register_result_log "$RESULT_LOG"

  if [[ $DESTINATION_IS_GENERIC -eq 1 ]]; then
    log_error "No concrete iOS Simulator runtime is available; cannot execute ${label}"
    log_error "Install an iOS simulator runtime before rerunning the script."
    add_summary "test" "${label}" "error" "" "" "" "" "" "failed (no simulator runtime)"
    update_exit_status 2
    return 2
  fi

  local -a args=(
    -workspace "$WORKSPACE"
    -scheme "$resolved_scheme"
    -destination "$resolved_destination"
    -resultBundlePath "$RESULT_BUNDLE"
  )

  if [[ -n "${ZPOD_DERIVED_DATA_PATH:-}" ]]; then
    mkdir -p "$ZPOD_DERIVED_DATA_PATH"
    args+=(-derivedDataPath "$ZPOD_DERIVED_DATA_PATH")
  fi

  local use_test_without_building=0
  if [[ "${ZPOD_TEST_WITHOUT_BUILDING:-0}" == "1" ]]; then
    use_test_without_building=1
  fi

  if [[ $clean_flag -eq 1 && $use_test_without_building -eq 0 ]]; then
    args+=(clean)
  fi

  if [[ $use_test_without_building -eq 1 ]]; then
    args+=(test-without-building)
  else
    args+=(build test)
  fi

  if [[ $integration_run -eq 0 ]]; then
    local filter
    for filter in "${filters[@]}"; do
      args+=("-only-testing:$filter")
    done
  fi

  log_section "xcodebuild tests (${label})"
  local temp_sim_udid=""
  run_tests_once() {
    set +e
    local timeout_seconds
    timeout_seconds=$(resolve_xcodebuild_timeout "$label")
    ZPOD_XCODEBUILD_TIMEOUT_SECONDS="$timeout_seconds" xcodebuild_wrapper "${args[@]}" 2>&1 | tee "$RESULT_LOG"
    local status=${PIPESTATUS[0]}
    set -e
    return "$status"
  }

  run_tests_once
  local xc_status=$?

  if [[ $xc_status -ne 0 ]] && [[ -f "$RESULT_LOG" ]] && is_sim_boot_failure_log "$RESULT_LOG"; then
    log_warn "Simulator boot failure detected for ${label}; resetting CoreSimulator service..."
    reset_core_simulator_service
    log_warn "Creating a fresh simulator and retrying once..."
    local new_udid=""
    if new_udid=$(create_ephemeral_simulator 2>/dev/null); then
      temp_sim_udid="$new_udid"
      log_info "Retrying ${label} with simulator id=${temp_sim_udid}"
      local idx
      for idx in "${!args[@]}"; do
        if [[ "${args[$idx]}" == "-destination" ]]; then
          args[$((idx + 1))]="id=${temp_sim_udid}"
          break
        fi
      done
      run_tests_once
      xc_status=$?
    else
      log_warn "Failed to provision a fresh simulator; skipping retry"
    fi
  fi

  cleanup_ephemeral_simulator "$temp_sim_udid"

  if [[ $xc_status -ne 0 ]]; then
    record_test_suite_timings "$RESULT_BUNDLE" "$label" "$RESULT_LOG"
    xcresult_has_failures "$RESULT_BUNDLE"
    local inspect_status=$?
    case $inspect_status in
      0)
        log_error "Tests failed (${label}) status $xc_status -> $RESULT_LOG"
        add_summary "test" "${label}" "error" "$RESULT_LOG" "" "" "" "" "failed"
        update_exit_status "$xc_status"
        return "$xc_status"
        ;;
      1)
        log_warn "xcodebuild exited with status $xc_status for ${label} but no test failures detected; treating as success"
        ;;
      *)
        log_error "xcodebuild exited with status $xc_status for ${label} and result bundle could not be inspected"
        add_summary "test" "${label}" "error" "$RESULT_LOG" "" "" "" "" "result bundle inspection failed"
        update_exit_status "$xc_status"
        return "$xc_status"
        ;;
    esac
  fi

  log_success "Tests finished -> $RESULT_LOG"
  local summary_text=""
  local total="" passed="" failed="" skipped="" note=""
  if summary_text=$(xcresult_summary "$RESULT_BUNDLE" 2>/dev/null); then
    local counts=""
    if counts=$(extract_test_counts "$summary_text"); then
      IFS='|' read -r total passed failed skipped <<< "$counts"
    else
      note="$summary_text"
    fi
  fi
  record_test_suite_timings "$RESULT_BUNDLE" "$label" "$RESULT_LOG"
  if [[ -z "$total" || "$total" -eq 0 ]]; then
    local suite_counts
    suite_counts=$(aggregate_suite_counts "$label")
    IFS='|' read -r total passed failed skipped <<< "$suite_counts"
  fi
  add_summary "test" "${label}" "success" "$RESULT_LOG" "$total" "$passed" "$failed" "$skipped" "$note"
  return 0
}

run_test_target() {
  local target
  target=$(resolve_test_identifier "$1") || exit_with_summary 1
  case "$target" in
    all|zpod|AppSmokeTests|zpodTests|zpodUITests|IntegrationTests|*/*)
      test_app_target "$target" || return $?;;
    "") ;;
    *)
      if is_package_target "$target"; then
        test_package_target "$target" || return $?
      else
        log_error "Unknown test target: $target"
        update_exit_status 1
        finalize_and_exit 1
      fi
      ;;
  esac
}

infer_target_for_class() {
  local class_name="$1"
  local search_dirs=("${REPO_ROOT}/zpodUITests" "${REPO_ROOT}/AppSmokeTests" "${REPO_ROOT}/IntegrationTests")
  local matches=()
  ensure_command rg "ripgrep is required to resolve test names" || exit_with_summary 1

  for dir in "${search_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
      matches+=("$file")
    done < <(rg -l --hidden --iglob '*Tests.swift' "class\\s+${class_name}\\b" "$dir" 2>/dev/null || true)
  done

  if [[ ${#matches[@]} -eq 0 ]]; then
    return 1
  fi
  if [[ ${#matches[@]} -gt 1 ]]; then
    log_error "Ambiguous test class '$class_name' found in multiple targets"
    for match in "${matches[@]}"; do
      log_error "  -> $match"
    done
    update_exit_status 1
    finalize_and_exit 1
  fi

  local match_path="${matches[0]}"
  case "$match_path" in
    */zpodUITests/*) echo "zpodUITests";;
    */AppSmokeTests/*) echo "AppSmokeTests";;
    */IntegrationTests/*) echo "IntegrationTests";;
    *) return 1;;
  esac
}

resolve_test_identifier() {
  local spec="$1"
  [[ -z "$spec" ]] && { log_error "Empty test identifier"; return 1; }

  local known_targets=(all zpod AppSmokeTests zpodUITests IntegrationTests)
  local candidate
  for candidate in "${known_targets[@]}"; do
    if [[ "$spec" == "$candidate" ]]; then
      echo "$spec"
      return 0
    fi
  done

  if [[ "$spec" == "zpodTests" ]]; then
    echo "AppSmokeTests"
    return 0
  fi

  if is_package_target "$spec"; then
    echo "$spec"
    return 0
  fi

  local package_match
  if package_match=$(find_package_for_test_target "$spec" 2>/dev/null); then
    if [[ -n "$package_match" ]]; then
      echo "$package_match"
      return 0
    fi
  fi

  if [[ "$spec" == */* ]]; then
    local first_part="${spec%%/*}"
    local remainder="${spec#*/}"
    for candidate in "${known_targets[@]}"; do
      if [[ "$first_part" == "$candidate" ]]; then
        echo "$spec"
        return 0
      fi
    done

    if is_package_target "$first_part"; then
      if [[ "$remainder" != "$spec" ]]; then
        log_warn "Package test filtering is not supported; running full package '$first_part'"
      fi
      echo "$first_part"
      return 0
    fi

    if package_match=$(find_package_for_test_target "$first_part" 2>/dev/null); then
      if [[ -n "$package_match" ]]; then
        if [[ "$remainder" != "$spec" ]]; then
          log_warn "Package test filtering is not supported; running full package '$package_match'"
        fi
        echo "$package_match"
        return 0
      fi
    fi

    local inferred_target
    inferred_target=$(infer_target_for_class "$first_part") || {
      log_error "Unable to infer test target for class '$first_part'"
      return 1
    }
    if [[ "$remainder" == "$spec" ]]; then
      echo "${inferred_target}/${first_part}"
    else
      echo "${inferred_target}/${first_part}/${remainder}"
    fi
    return 0
  fi

  # Treat bare class names as UITest target by inference
  local inferred_target
  inferred_target=$(infer_target_for_class "$spec") || {
    log_error "Could not locate test class or target matching '$spec'"
    return 1
  }
  echo "${inferred_target}/${spec}"
  return 0
}

full_clean_build() {
  REQUESTED_CLEAN=1
  build_app_target "zpod" || return $?
}

full_build_no_test() {
  build_app_target "zpod" || return $?
}

full_build_and_test() {
  REQUESTED_CLEAN=1
  build_app_target "zpod" || return $?
  test_app_target "zpod" || return $?
}

partial_clean_build() {
  local module="$1"
  REQUESTED_CLEAN=1
  run_build_target "$module" || return $?
}

partial_build_and_test() {
  local module="$1"
  run_build_target "$module" || return $?
  run_test_target "$module" || return $?
}

# Start timer for entire script execution
START_TIME=$(date +%s)

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b)
      REQUESTED_BUILDS="$2"; shift 2;;
    -t)
      REQUESTED_TESTS="$2"; shift 2;;
    -c)
      REQUESTED_CLEAN=1; shift;;
    -s)
      REQUESTED_SYNTAX=1; shift;;
    -l|--lint)
      REQUESTED_LINT=1; shift;;
    -p)
      REQUEST_TESTPLAN=1
      if [[ $# -gt 1 && "$2" != -* ]]; then
        REQUEST_TESTPLAN_SUITE="$2"
        shift 2
      else
        REQUEST_TESTPLAN_SUITE=""
        shift
      fi;;
    --scheme)
      SCHEME="$2"; shift 2;;
    --workspace)
      WORKSPACE="$2"; shift 2;;
    --sim)
      PREFERRED_SIM="$2"; shift 2;;
    --verify-testplan)
      REQUEST_TESTPLAN=1
      REQUEST_TESTPLAN_SUITE=""
      shift;;
    --verify-testplan=*)
      REQUEST_TESTPLAN=1
      REQUEST_TESTPLAN_SUITE="${1#*=}"
      shift;;
    --self-check)
      SELF_CHECK=1; shift;;
    --help|-h)
      show_help; finalize_and_exit 0;;
    full_clean_build|full_build_no_test|full_build_and_test|partial_clean_build|partial_build_and_test)
      log_error "Deprecated action '$1'. Use -b/-t/-c/-s flags instead."
      exit_with_summary 1;;
    *)
      log_error "Unknown argument: $1"
      show_help
      exit_with_summary 1;;
  esac
done

if [[ $REQUESTED_SYNTAX -eq 1 ]]; then
  if [[ -n "$REQUESTED_BUILDS" || -n "$REQUESTED_TESTS" || $REQUESTED_CLEAN -eq 1 || $REQUEST_TESTPLAN -eq 1 || $REQUESTED_LINT -eq 1 ]]; then
    log_error "-s (syntax) cannot be combined with other build or test flags"
    update_exit_status 1
    finalize_and_exit 1
  fi
fi

if [[ $SELF_CHECK -eq 1 ]]; then
  self_check
  finalize_and_exit $?
fi

echo "[DEBUG] REQUESTED_SYNTAX=$REQUESTED_SYNTAX REQUESTED_BUILDS='$REQUESTED_BUILDS' REQUESTED_TESTS='$REQUESTED_TESTS' REQUEST_TESTPLAN=$REQUEST_TESTPLAN REQUEST_TESTPLAN_SUITE='$REQUEST_TESTPLAN_SUITE' REQUESTED_LINT=$REQUESTED_LINT"

did_run_anything=0

if [[ $REQUESTED_SYNTAX -eq 1 ]]; then
  execute_phase "Swift syntax" "syntax" run_syntax_check
  did_run_anything=1
fi

if [[ -n "$REQUESTED_BUILDS" ]]; then
  split_csv "$REQUESTED_BUILDS"
  for item in "${__ZPOD_SPLIT_RESULT[@]}"; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    execute_phase "Build ${item}" "build" run_build_target "$item"
    did_run_anything=1
  done
fi

if [[ -n "$REQUESTED_TESTS" ]]; then
  split_csv "$REQUESTED_TESTS"
  for item in "${__ZPOD_SPLIT_RESULT[@]}"; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    execute_phase "Test ${item}" "test" run_test_target "$item"
    did_run_anything=1
  done
fi

if [[ $REQUEST_TESTPLAN -eq 1 ]]; then
  execute_phase "Test plan ${REQUEST_TESTPLAN_SUITE:-default}" "testplan" run_testplan_check "$REQUEST_TESTPLAN_SUITE"
  did_run_anything=1
fi

if [[ $REQUESTED_LINT -eq 1 ]]; then
  execute_phase "Swift lint" "lint" run_swift_lint
  did_run_anything=1
fi

if [[ $did_run_anything -eq 1 ]]; then
  finalize_and_exit "$EXIT_STATUS"
fi

REQUESTED_CLEAN=1
if ! execute_phase "Swift syntax" "syntax" run_syntax_check; then
  finalize_and_exit "$EXIT_STATUS"
fi

execute_phase "Test plan default" "testplan" run_testplan_check ""

# Package builds and tests
__ZPOD_ALL_PACKAGES=()
while IFS= read -r pkg; do
  [[ -z "$pkg" ]] && continue
  __ZPOD_ALL_PACKAGES+=("$pkg")
done < <(list_package_targets)

for pkg in "${__ZPOD_ALL_PACKAGES[@]}"; do
  execute_phase "Build package ${pkg}" "build" build_package_target "$pkg"
done

# Keep REQUESTED_CLEAN=1 for workspace build to ensure clean test bundle builds
# Reset it AFTER workspace build, before individual package tests

for pkg in "${__ZPOD_ALL_PACKAGES[@]}"; do
  execute_phase "Package tests ${pkg}" "test" test_package_target "$pkg"
done
unset __ZPOD_ALL_PACKAGES

# Build-once-test-many optimization:
# Build zpod.app + ALL test bundles (AppSmoke, Integration, UI) in ONE xcodebuild invocation
# This eliminates redundant builds (previously: 3x zpod.app from scratch)
# REQUESTED_CLEAN=1 ensures test bundles are rebuilt fresh (prevents stale artifact issues)
execute_phase "Build app and test bundles" "build" build_for_testing_phase

# Reset clean flag after workspace build
REQUESTED_CLEAN=0

# Run all app tests using pre-built artifacts (no rebuild)
# Tests run instantly against artifacts from build-for-testing
export ZPOD_TEST_WITHOUT_BUILDING=1
if ! execute_phase "App smoke tests" "test" run_test_target "AppSmokeTests"; then
  unset ZPOD_TEST_WITHOUT_BUILDING
  finalize_and_exit "$EXIT_STATUS"
fi
execute_phase "Integration tests" "test" run_test_target "IntegrationTests"
run_ui_test_suites
unset ZPOD_TEST_WITHOUT_BUILDING

execute_phase "Swift lint" "lint" run_swift_lint

finalize_and_exit "$EXIT_STATUS"
