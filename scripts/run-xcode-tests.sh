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
REQUESTED_OSLOG_DEBUG=0
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
declare -a PACKAGE_TEST_TARGET_ENTRIES=()
PACKAGE_TEST_TARGETS_LOADED=0

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

log_oslog_debug() {
  local target="$1"
  if [[ $REQUESTED_OSLOG_DEBUG -ne 1 ]]; then
    return
  fi
  if ! command_exists log; then
    log_warn "OSLog debug requested, but 'log' command is unavailable"
    return
  fi
  local last="${ZPOD_OSLOG_LAST:-5m}"
  local default_predicate='subsystem == "us.zig.zpod" && (category == "PlaybackStateCoordinator" || category == "ExpandedPlayerViewModel" || category == "PlaybackPositionUITests")'
  local predicate="${ZPOD_OSLOG_PREDICATE:-$default_predicate}"
  log_section "OSLog debug (${target})"
  log_info "OSLog window: ${last}"
  log_info "OSLog predicate: ${predicate}"
  log show --last "$last" --style compact --predicate "$predicate" --info --debug
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
  local ui_full_timeout="${ZPOD_UI_TEST_TIMEOUT_SECONDS_FULL:-}"
  local default_timeout="${ZPOD_TEST_TIMEOUT_SECONDS:-1800}"
  if [[ "$label" == "zpodUITests" || "$label" == "UI tests" ]]; then
    if [[ -n "$ui_full_timeout" ]]; then
      echo "$ui_full_timeout"
      return
    fi
    echo ""
    return
  fi
  if [[ "$label" == *UITests* || "$label" == *-ui ]]; then
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
  rg -N --no-filename -g '*Tests.swift' -o 'class[[:space:]]+[A-Za-z0-9_]+Tests' \
    "${REPO_ROOT}/zpodUITests" | \
    sed -E 's/class[[:space:]]+//' | \
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
  local use_fresh_sim=0
  if [[ "${ZPOD_UI_TEST_FRESH_SIM:-0}" == "1" ]]; then
    use_fresh_sim=1
  fi
  local original_sim_udid="${ZPOD_SIMULATOR_UDID:-}"

  for suite in "${suites[@]}"; do
    local temp_sim_udid=""
    if (( use_fresh_sim == 1 )); then
      log_info "Provisioning fresh simulator for UI suite ${suite}..."
      if temp_sim_udid=$(create_ephemeral_simulator 2>/dev/null); then
        log_info "Using simulator id=${temp_sim_udid} for UI suite ${suite}"
        export ZPOD_SIMULATOR_UDID="$temp_sim_udid"
      else
        log_warn "Failed to provision fresh simulator for ${suite}; using default destination"
      fi
    fi

    if ! execute_phase "UI tests ${suite}" "test" run_test_target "zpodUITests/${suite}"; then
      any_failed=1
    fi

    if [[ -n "$temp_sim_udid" ]]; then
      cleanup_ephemeral_simulator "$temp_sim_udid"
      temp_sim_udid=""
    fi
    if [[ -n "$original_sim_udid" ]]; then
      export ZPOD_SIMULATOR_UDID="$original_sim_udid"
    else
      unset ZPOD_SIMULATOR_UDID
    fi
  done
  if (( any_failed == 1 )); then
    log_warn "One or more UI suites failed; continuing with remaining phases"
  fi
}

retry_with_fresh_sim() {
  local label="$1"
  local reason="$2"
  local runner="${3:-run_tests_once}"

  if [[ "${retry_attempted:-0}" -ne 0 ]]; then
    return 0
  fi
  retry_attempted=1

  log_warn "${reason}; resetting CoreSimulator service..."
  reset_core_simulator_service
  if [[ -n "${temp_sim_udid:-}" ]]; then
    cleanup_ephemeral_simulator "$temp_sim_udid"
    temp_sim_udid=""
  fi

  log_warn "Retrying ${label} with a freshly created simulator..."
  local new_udid=""
  if new_udid=$(create_ephemeral_simulator 2>/dev/null); then
    temp_sim_udid="$new_udid"
    log_info "Retrying ${label} with simulator id=${temp_sim_udid}"
    args=("${original_args[@]}")
    local idx
    for idx in "${!args[@]}"; do
      if [[ "${args[$idx]}" == "-destination" ]]; then
        args[$((idx + 1))]="id=${temp_sim_udid}"
        break
      fi
    done
    $runner
    xc_status=$?
  else
    log_warn "Failed to provision a fresh simulator; keeping previous failure"
  fi
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
