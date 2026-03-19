if [[ -n "${__ZPOD_HARNESS_SH:-}" ]]; then
  return 0
fi
__ZPOD_HARNESS_SH=1

SCHEME=""
WORKSPACE="${REPO_ROOT}/zpod.xcworkspace"
PREFERRED_SIM="iPhone 17 Pro"
REQUESTED_CLEAN=0
REQUESTED_BUILDS=""
REQUESTED_TESTS=""
REQUESTED_POSITIONAL_TARGETS=()   # file paths or suite directory names passed as positional args
REQUESTED_SYNTAX=0
REQUEST_TESTPLAN=0
REQUEST_TESTPLAN_SUITE=""
REQUESTED_LINT=0
REQUESTED_OSLOG_DEBUG=0
REQUEST_CLEAR_UI_LOCK=0
REQUEST_REAP=0
REQUEST_REAP_DRY_RUN=0
SELF_CHECK=0
SCHEME_RESOLVED=0
SCHEME_CANDIDATES=("zpod (zpod project)" "zpod")

DEFAULT_PIPELINE=0
UI_PARALLELISM=1

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
ROOT_SHELL_PID="${BASHPID:-$$}"
RUN_INVOCATION_ID=""
declare -a ORIGINAL_CLI_ARGS=()
UI_TEST_LOCK_HELD=0
UI_TEST_LOCK_PATH=""
UI_TEST_LOCK_METADATA=""
UI_LOCK_CONFLICT_EXIT_CODE=73
UI_PARALLEL_SETUP_EXIT_CODE=74
UI_PARALLEL_SHARED_DERIVED_ROOT=""
UI_SHARD_ACTIVE=0
UI_SHARD_TEARDOWN_DONE=0
UI_SHARD_QUEUE_ROOT=""
UI_SHARD_DERIVED_ROOT=""
UI_SHARD_CANCELLED=0
declare -a PHASE_DURATION_ENTRIES=()
declare -a TEST_SUITE_TIMING_ENTRIES=()
declare -a PACKAGE_TEST_TIMING_ENTRIES=()
declare -a UI_WORKER_HEALTH_ENTRIES=()
declare -a UI_SHARD_WORKER_PIDS=()
declare -a UI_SHARD_WORKER_LABELS=()
declare -a UI_SHARD_WORKER_REPORTS=()
declare -a UI_SHARD_WORKER_SIMULATORS=()
declare -a EPHEMERAL_SIMULATORS=()

register_ephemeral_simulator() {
  local udid="$1"
  [[ -n "$udid" ]] || return
  local existing
  for existing in "${EPHEMERAL_SIMULATORS[@]-}"; do
    [[ "$existing" == "$udid" ]] && return
  done
  EPHEMERAL_SIMULATORS+=("$udid")
}

unregister_ephemeral_simulator() {
  local udid="$1"
  [[ -n "$udid" ]] || return
  local -a remaining=()
  local existing
  for existing in "${EPHEMERAL_SIMULATORS[@]-}"; do
    [[ "$existing" != "$udid" ]] && remaining+=("$existing")
  done
  EPHEMERAL_SIMULATORS=("${remaining[@]-}")
}

cleanup_all_ephemeral_simulators() {
  if (( ${#EPHEMERAL_SIMULATORS[@]} == 0 )); then
    return
  fi
  local udid
  for udid in "${EPHEMERAL_SIMULATORS[@]}"; do
    cleanup_ephemeral_simulator "$udid"
  done
  EPHEMERAL_SIMULATORS=()
}

sweep_orphaned_ephemeral_simulators() {
  local udid name
  while IFS=' ' read -r udid name; do
    [[ -z "$udid" ]] && continue
    log_info "Sweeping orphaned ephemeral simulator: ${name} (${udid})"
    cleanup_ephemeral_simulator "$udid"
  done < <(xcrun simctl list devices -j 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['name'].startswith('zpod-temp-'):
            print(d['udid'] + ' ' + d['name'])
" 2>/dev/null || true)
}

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

reset_ui_shard_runtime_state() {
  UI_SHARD_ACTIVE=0
  UI_SHARD_TEARDOWN_DONE=0
  UI_SHARD_QUEUE_ROOT=""
  UI_SHARD_DERIVED_ROOT=""
  UI_SHARD_CANCELLED=0
  UI_SHARD_WORKER_PIDS=()
  UI_SHARD_WORKER_LABELS=()
  UI_SHARD_WORKER_REPORTS=()
  UI_SHARD_WORKER_SIMULATORS=()
}

invocation_command_line() {
  local cmd="scripts/run-xcode-tests.sh"
  if (( ${#ORIGINAL_CLI_ARGS[@]} == 0 )); then
    printf "%s" "$cmd"
    return 0
  fi
  local arg
  for arg in "${ORIGINAL_CLI_ARGS[@]}"; do
    cmd+=" ${arg}"
  done
  printf "%s" "$cmd"
}

resolve_ui_test_lock_dir() {
  if [[ -n "${ZPOD_UI_TEST_LOCK_DIR:-}" ]]; then
    printf "%s" "$ZPOD_UI_TEST_LOCK_DIR"
    return 0
  fi
  local repo_slug
  repo_slug=$(printf "%s" "$REPO_ROOT" | tr '/ :' '____')
  printf "%s/zpod-ui-test-lock-%s" "${TMPDIR:-/tmp}" "$repo_slug"
}

read_ui_lock_metadata_field() {
  local metadata_path="$1"
  local key="$2"
  if [[ ! -f "$metadata_path" ]]; then
    printf ""
    return 0
  fi
  awk -F= -v field="$key" '$1 == field { sub(/^[^=]*=/, "", $0); print $0; exit }' "$metadata_path" || true
}

write_ui_lock_metadata() {
  local metadata_path="$1"
  local reason="$2"
  local host_name
  host_name=$(hostname 2>/dev/null || printf "unknown-host")
  local command_line
  command_line=$(invocation_command_line)
  cat > "$metadata_path" <<EOF
pid=${ROOT_SHELL_PID}
run_id=${RUN_INVOCATION_ID}
started_epoch=${START_TIME:-0}
started_human=${START_TIME_HUMAN:-unknown}
host=${host_name}
reason=${reason}
repo_root=${REPO_ROOT}
cwd=${PWD}
command=${command_line}
EOF
}

ui_lock_owner_is_alive() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  local state=""
  state=$(ps -p "$pid" -o stat= 2>/dev/null | awk '{print $1}' || true)
  if [[ "$state" == Z* ]]; then
    return 1
  fi
  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  ps -p "$pid" -o pid= >/dev/null 2>/dev/null
}

ui_lock_owner_elapsed_seconds() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] || {
    printf "0"
    return 0
  }
  # Try etimes (Linux) first, fall back to etime (macOS) and parse the format
  local elapsed
  elapsed=$(ps -p "$pid" -o etimes= 2>/dev/null | awk '{print $1}' || true)
  if [[ "$elapsed" =~ ^[0-9]+$ ]]; then
    printf "%s" "$elapsed"
    return 0
  fi
  # Parse etime format: [[DD-]HH:]MM:SS
  local etime
  etime=$(ps -p "$pid" -o etime= 2>/dev/null | awk '{$1=$1; print}' || true)
  [[ -z "$etime" ]] && { printf "0"; return 0; }
  local days=0 hours=0 mins=0 secs=0
  if [[ "$etime" == *-* ]]; then
    days="${etime%%-*}"
    etime="${etime#*-}"
  fi
  IFS=: read -ra parts <<< "$etime"
  case ${#parts[@]} in
    3) hours="${parts[0]}"; mins="${parts[1]}"; secs="${parts[2]}";;
    2) mins="${parts[0]}"; secs="${parts[1]}";;
    1) secs="${parts[0]}";;
  esac
  # Strip leading zeros to prevent octal interpretation
  days=$((10#$days)); hours=$((10#$hours)); mins=$((10#$mins)); secs=$((10#$secs))
  printf "%s" $(( days*86400 + hours*3600 + mins*60 + secs ))
}

ui_lock_owner_has_active_test_descendants() {
  local root_pid="$1"
  [[ "$root_pid" =~ ^[0-9]+$ ]] || return 1

  local root_cmd
  root_cmd=$(ps -p "$root_pid" -o command= 2>/dev/null || true)
  if [[ "$root_cmd" =~ (xcodebuild|xctest|simctl|run-xcode-tests\.sh) ]]; then
    return 0
  fi

  command_exists pgrep || return 1
  local child_pid
  while IFS= read -r child_pid; do
    [[ "$child_pid" =~ ^[0-9]+$ ]] || continue
    local child_cmd
    child_cmd=$(ps -p "$child_pid" -o command= 2>/dev/null || true)
    if [[ "$child_cmd" =~ (xcodebuild|xctest|simctl|CoreSimulator|run-xcode-tests\.sh) ]]; then
      return 0
    fi
  done < <(collect_descendant_pids "$root_pid")

  return 1
}

ui_lock_owner_is_orphaned() {
  local owner_pid="$1"
  local owner_command="${2:-}"
  [[ "$owner_pid" =~ ^[0-9]+$ ]] || return 1
  # Default: reclaim only after 3 minutes without active test descendants.
  local orphan_after="${ZPOD_UI_LOCK_ORPHAN_AFTER_SECONDS:-180}"
  [[ "$orphan_after" =~ ^[0-9]+$ ]] || orphan_after=180

  local elapsed
  elapsed=$(ui_lock_owner_elapsed_seconds "$owner_pid")
  if (( elapsed < orphan_after )); then
    return 1
  fi

  # Be conservative: only auto-reclaim locks created by this harness command.
  if [[ "$owner_command" != *"run-xcode-tests.sh"* ]]; then
    return 1
  fi

  if ui_lock_owner_has_active_test_descendants "$owner_pid"; then
    return 1
  fi

  return 0
}

collect_descendant_pids() {
  local parent_pid="$1"
  [[ "$parent_pid" =~ ^[0-9]+$ ]] || return 0
  command_exists pgrep || return 0

  local child_pid
  while IFS= read -r child_pid; do
    [[ -z "$child_pid" ]] && continue
    printf "%s\n" "$child_pid"
    collect_descendant_pids "$child_pid"
  done < <(pgrep -P "$parent_pid" || true)
}

terminate_process_tree() {
  local root_pid="$1"
  local grace_seconds="${2:-5}"
  [[ "$root_pid" =~ ^[0-9]+$ ]] || return 0
  if [[ ! "$grace_seconds" =~ ^[0-9]+$ ]]; then
    grace_seconds=5
  fi

  local -a targets=()
  local descendant_pid
  while IFS= read -r descendant_pid; do
    [[ -z "$descendant_pid" ]] && continue
    targets+=("$descendant_pid")
  done < <(collect_descendant_pids "$root_pid")
  targets+=("$root_pid")

  local signaled=0
  local target_pid
  for target_pid in "${targets[@]-}"; do
    [[ "$target_pid" =~ ^[0-9]+$ ]] || continue
    if kill -0 "$target_pid" 2>/dev/null; then
      if kill "$target_pid" 2>/dev/null; then
        signaled=$((signaled + 1))
      fi
    fi
  done

  if (( signaled > 0 && grace_seconds > 0 )); then
    sleep "$grace_seconds"
  fi

  for target_pid in "${targets[@]-}"; do
    [[ "$target_pid" =~ ^[0-9]+$ ]] || continue
    if kill -0 "$target_pid" 2>/dev/null; then
      kill -9 "$target_pid" 2>/dev/null || true
    fi
  done
}

reap_orphaned_harness_processes() {
  local dry_run="${1:-0}"
  local self_pid="${ROOT_SHELL_PID:-$$}"
  local orphan_after="${ZPOD_REAP_ORPHAN_AFTER_SECONDS:-120}"
  [[ "$orphan_after" =~ ^[0-9]+$ ]] || orphan_after=120

  local -a candidate_pids=()
  local pid
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    # Skip ourselves and our ancestors
    [[ "$pid" == "$self_pid" ]] && continue
    [[ "$pid" == "$$" ]] && continue
    candidate_pids+=("$pid")
  done < <(pgrep -f 'run-xcode-tests\.sh' 2>/dev/null || true)

  if (( ${#candidate_pids[@]} == 0 )); then
    log_info "Reap: no other run-xcode-tests.sh processes found"
    return 0
  fi

  local reaped=0
  local skipped=0
  for pid in "${candidate_pids[@]}"; do
    local cmd elapsed state
    cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
    [[ -z "$cmd" ]] && continue
    # Verify this is actually our harness
    [[ "$cmd" == *"run-xcode-tests.sh"* ]] || continue

    elapsed=$(ui_lock_owner_elapsed_seconds "$pid")
    state=$(ps -p "$pid" -o state= 2>/dev/null | awk '{print $1}' || true)

    # Skip if too young
    if (( elapsed < orphan_after )); then
      skipped=$((skipped + 1))
      continue
    fi

    # Skip if it has active xcodebuild/xctest descendants
    if ui_lock_owner_has_active_test_descendants "$pid"; then
      log_info "Reap: PID ${pid} has active test descendants (age ${elapsed}s) — skipping"
      skipped=$((skipped + 1))
      continue
    fi

    # Count descendants for reporting
    local descendant_count=0
    local desc_pid
    while IFS= read -r desc_pid; do
      [[ -n "$desc_pid" ]] && descendant_count=$((descendant_count + 1))
    done < <(collect_descendant_pids "$pid")

    if [[ "$dry_run" == "1" ]]; then
      log_warn "Reap (dry-run): would kill PID ${pid} + ${descendant_count} descendants (age ${elapsed}s, state ${state})"
      log_warn "  cmd: ${cmd}"
    else
      log_warn "Reap: killing orphaned PID ${pid} + ${descendant_count} descendants (age ${elapsed}s, state ${state})"
      log_warn "  cmd: ${cmd}"
      terminate_process_tree "$pid" 3
    fi
    reaped=$((reaped + 1))
  done

  if (( reaped == 0 )); then
    log_info "Reap: no orphaned harness processes found (${skipped} active/young process(es) skipped)"
  else
    local verb="killed"
    [[ "$dry_run" == "1" ]] && verb="would kill"
    log_success "Reap: ${verb} ${reaped} orphaned harness process tree(s) (${skipped} skipped)"
  fi
  return 0
}

remove_ui_lock_dir() {
  local lock_dir="$1"
  if [[ -z "$lock_dir" || "$lock_dir" == "/" ]]; then
    return 1
  fi
  rm -rf "$lock_dir"
}

record_ui_lock_conflict_summary() {
  local note="$1"
  local entry
  for entry in "${SUMMARY_ITEMS[@]-}"; do
    IFS='|' read -r category name _ <<< "$entry"
    if [[ "$category" == "test" && "$name" == "zpodUITests lock" ]]; then
      return 0
    fi
  done
  add_summary "test" "zpodUITests lock" "error" "" "1" "0" "1" "0" "$note"
}

acquire_ui_test_lock() {
  local reason="${1:-UI tests}"
  local lock_mode="${ZPOD_UI_TEST_LOCK_MODE:-strict}"
  if [[ "$lock_mode" == "off" ]]; then
    return 0
  fi
  if (( UI_TEST_LOCK_HELD == 1 )); then
    return 0
  fi
  if [[ "${BASHPID:-$$}" != "$ROOT_SHELL_PID" ]]; then
    return 0
  fi

  local lock_dir
  lock_dir=$(resolve_ui_test_lock_dir)
  local metadata_path="${lock_dir}/owner.meta"
  local attempt
  for attempt in 1 2; do
    if mkdir "$lock_dir" 2>/dev/null; then
      UI_TEST_LOCK_HELD=1
      UI_TEST_LOCK_PATH="$lock_dir"
      UI_TEST_LOCK_METADATA="$metadata_path"
      write_ui_lock_metadata "$metadata_path" "$reason"
      log_info "Acquired UI test lock: ${lock_dir} (run_id=${RUN_INVOCATION_ID})"
      return 0
    fi

    local owner_pid owner_run_id owner_host owner_started owner_reason owner_command
    owner_pid=$(read_ui_lock_metadata_field "$metadata_path" "pid")
    owner_run_id=$(read_ui_lock_metadata_field "$metadata_path" "run_id")
    owner_host=$(read_ui_lock_metadata_field "$metadata_path" "host")
    owner_started=$(read_ui_lock_metadata_field "$metadata_path" "started_human")
    owner_reason=$(read_ui_lock_metadata_field "$metadata_path" "reason")
    owner_command=$(read_ui_lock_metadata_field "$metadata_path" "command")

    if [[ -n "$owner_pid" ]] && ui_lock_owner_is_alive "$owner_pid"; then
      if ui_lock_owner_is_orphaned "$owner_pid" "$owner_command"; then
        local owner_elapsed
        owner_elapsed=$(ui_lock_owner_elapsed_seconds "$owner_pid")
        log_warn "Detected orphaned active UI lock owner pid=${owner_pid} (elapsed=${owner_elapsed}s); reclaiming lock."
        log_warn "Owner run_id=${owner_run_id:-unknown} reason=${owner_reason:-unknown}"
        terminate_process_tree "$owner_pid" "${ZPOD_UI_LOCK_CLEAR_KILL_GRACE_SECONDS:-5}"
        if ui_lock_owner_is_alive "$owner_pid"; then
          log_warn "Owner pid ${owner_pid} remained alive after termination attempt; continuing with conflict handling."
        else
          if remove_ui_lock_dir "$lock_dir"; then
            continue
          fi
        fi
      fi
      log_error "UI test lock conflict: another run is already executing UI tests."
      log_error "Lock path: ${lock_dir}"
      log_error "Owner PID: ${owner_pid} (run_id=${owner_run_id:-unknown}, host=${owner_host:-unknown})"
      log_error "Owner started: ${owner_started:-unknown}"
      log_error "Owner reason: ${owner_reason:-unknown}"
      log_error "Owner command: ${owner_command:-unknown}"
      log_error "Inspect owner: ps -p ${owner_pid} -o pid,etime,command"
      log_error "If the owner process is gone, remove stale lock: rm -rf '${lock_dir}'"
      record_ui_lock_conflict_summary "UI lock held by pid ${owner_pid} (run ${owner_run_id:-unknown})"
      update_exit_status "$UI_LOCK_CONFLICT_EXIT_CODE"
      return "$UI_LOCK_CONFLICT_EXIT_CODE"
    fi

    if (( attempt == 1 )); then
      log_warn "Detected stale UI test lock at ${lock_dir}; attempting cleanup"
      if remove_ui_lock_dir "$lock_dir"; then
        continue
      fi
    fi

    log_error "Failed to acquire UI test lock at ${lock_dir}."
    log_error "Set ZPOD_UI_TEST_LOCK_MODE=off to bypass locking (not recommended for regular runs)."
    record_ui_lock_conflict_summary "Failed to recover UI lock at ${lock_dir}"
    update_exit_status "$UI_LOCK_CONFLICT_EXIT_CODE"
    return "$UI_LOCK_CONFLICT_EXIT_CODE"
  done
}

release_ui_test_lock() {
  if (( UI_TEST_LOCK_HELD == 0 )); then
    return 0
  fi
  if [[ "${BASHPID:-$$}" != "$ROOT_SHELL_PID" ]]; then
    return 0
  fi
  local lock_dir="$UI_TEST_LOCK_PATH"
  if [[ -n "$lock_dir" && -d "$lock_dir" ]]; then
    if remove_ui_lock_dir "$lock_dir"; then
      log_info "Released UI test lock: ${lock_dir}"
    else
      log_warn "Unable to remove UI test lock directory: ${lock_dir}"
    fi
  fi
  UI_TEST_LOCK_HELD=0
  UI_TEST_LOCK_PATH=""
  UI_TEST_LOCK_METADATA=""
}

clear_ui_test_lock() {
  local lock_dir
  lock_dir=$(resolve_ui_test_lock_dir)
  local metadata_path="${lock_dir}/owner.meta"
  local cleanup_status=0
  cleanup_ui_parallel_artifacts || cleanup_status=$?

  if [[ ! -e "$lock_dir" ]]; then
    log_info "No UI test lock present at ${lock_dir}"
    return "$cleanup_status"
  fi
  if [[ ! -d "$lock_dir" ]]; then
    log_error "UI lock path exists but is not a directory: ${lock_dir}"
    return 1
  fi

  local owner_pid owner_run_id owner_host owner_started owner_reason owner_command
  owner_pid=$(read_ui_lock_metadata_field "$metadata_path" "pid")
  owner_run_id=$(read_ui_lock_metadata_field "$metadata_path" "run_id")
  owner_host=$(read_ui_lock_metadata_field "$metadata_path" "host")
  owner_started=$(read_ui_lock_metadata_field "$metadata_path" "started_human")
  owner_reason=$(read_ui_lock_metadata_field "$metadata_path" "reason")
  owner_command=$(read_ui_lock_metadata_field "$metadata_path" "command")

  if [[ -n "$owner_pid" ]] && ui_lock_owner_is_alive "$owner_pid"; then
    log_warn "Clearing active UI lock owned by PID ${owner_pid} (run_id=${owner_run_id:-unknown})"
    log_warn "Owner host: ${owner_host:-unknown}; started: ${owner_started:-unknown}; reason: ${owner_reason:-unknown}"
    log_warn "Owner command: ${owner_command:-unknown}"
    log_warn "Stopping lock owner process tree rooted at PID ${owner_pid}"
    terminate_process_tree "$owner_pid" "${ZPOD_UI_LOCK_CLEAR_KILL_GRACE_SECONDS:-5}"
    if ui_lock_owner_is_alive "$owner_pid"; then
      log_error "Unable to stop active lock owner PID ${owner_pid}"
      return 1
    fi
  else
    log_info "Clearing stale UI lock at ${lock_dir}"
  fi

  if remove_ui_lock_dir "$lock_dir"; then
    if [[ "$UI_TEST_LOCK_PATH" == "$lock_dir" ]]; then
      UI_TEST_LOCK_HELD=0
      UI_TEST_LOCK_PATH=""
      UI_TEST_LOCK_METADATA=""
    fi
    log_success "Cleared UI test lock: ${lock_dir}"
    return "$cleanup_status"
  fi

  log_error "Failed to clear UI test lock: ${lock_dir}"
  return 1
}

cleanup_ui_parallel_artifacts() {
  local tmp_root="${TMPDIR:-/tmp}"
  local removed_count=0
  local artifact_path=""

  while IFS= read -r artifact_path; do
    [[ -z "$artifact_path" ]] && continue
    if rm -rf "$artifact_path"; then
      removed_count=$((removed_count + 1))
    fi
  done < <(find "$tmp_root" -maxdepth 1 \( -type d -name 'zpod-ui-derived-*' -o -type f -name '*zpod-ui-derived-*' \) -print 2>/dev/null)

  if (( removed_count > 0 )); then
    log_info "Removed ${removed_count} UI shard artifact(s) from ${tmp_root}"
  else
    log_info "No UI shard artifacts found in ${tmp_root}"
  fi
  return 0
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
  local status=0
  if "${command[@]}"; then
    status=0
  else
    status=$?
  fi
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

record_package_test_timing() {
  local package="$1"
  local elapsed="$2"
  local status="$3"
  local log_path="$4"
  PACKAGE_TEST_TIMING_ENTRIES+=("${package}|${elapsed}|${status}|${log_path}")
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
  local predicate="${ZPOD_OSLOG_PREDICATE:-subsystem == \"us.zig.zpod\" && (category == \"PlaybackStateCoordinator\" || category == \"ExpandedPlayerViewModel\")}"
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
    echo "Syntax"
    return 0
  fi
  if [[ "$name" == "App smoke tests" ]]; then
    echo "AppSmoke"
    return 0
  fi
  if [[ "$name" == Integration* ]]; then
    echo "Integration"
    return 0
  fi
  if [[ "$name" == "UI tests" || "$name" == zpodUITests* || "$name" == *UITests* || "$name" == *-ui || "$name" == zpod-ui ]]; then
    echo "UI Tests"
    return 0
  fi
  if [[ "$category" == "lint" || "$name" == Swift\ lint* ]]; then
    echo "Lint"
    return 0
  fi
  if [[ "$name" == Build\ package* ]]; then
    echo "Package Build"
    return 0
  fi
  if [[ "$name" == package\ * ]]; then
    echo "Package Build"
    return 0
  fi
  if [[ "$name" == Package\ tests* || "$name" == Test\ Packages || "$name" == Packages ]]; then
    echo "Package Tests"
    return 0
  fi
  if [[ "$category" == "build" || "$name" == Build* ]]; then
    echo "Build"
    return 0
  fi
  return 0
}

test_group_for() {
  local category="$1"
  local name="$2"
  if [[ "$category" == "syntax" ]]; then
    echo "Syntax"
    return 0
  fi
  if [[ "$category" == "build" ]]; then
    if [[ "$name" == package\ * || "$name" == Build\ package* ]]; then
      echo "Package Build"
      return 0
    fi
    echo "Build"
    return 0
  fi
  if [[ "$name" == AppSmokeTests* || "$name" == *AppSmoke* ]]; then
    echo "AppSmoke"
    return 0
  fi
  if [[ "$name" == IntegrationTests* || "$name" == *Integration* ]]; then
    echo "Integration"
    return 0
  fi
  if [[ "$name" == zpodUITests* || "$name" == *UITests* || "$name" == *-ui || "$name" == zpod-ui ]]; then
    echo "UI Tests"
    return 0
  fi
  if [[ "$category" == "lint" || "$name" == Swift\ lint* ]]; then
    echo "Lint"
    return 0
  fi
  if [[ "$name" == package* || "$name" == Test\ Packages || "$name" == Packages ]]; then
    echo "Package Tests"
    return 0
  fi
  return 0
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

target_includes_ui_tests() {
  local target="$1"
  case "$target" in
    all|zpod|zpodUITests|zpodUITests/*|*UITests*|*-ui)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_ui_parallelism() {
  local requested="${ZPOD_UI_TEST_PARALLELISM:-1}"
  if [[ ! "$requested" =~ ^[0-9]+$ ]]; then
    log_warn "Ignoring invalid ZPOD_UI_TEST_PARALLELISM='${requested}', defaulting to 1"
    requested=1
  fi
  if (( requested < 1 )); then
    requested=1
  fi

  local max_parallel="${ZPOD_UI_TEST_PARALLEL_MAX:-}"
  if [[ -z "$max_parallel" ]]; then
    if is_ci; then
      max_parallel=5
    else
      max_parallel=4
    fi
  fi
  if [[ ! "$max_parallel" =~ ^[0-9]+$ ]] || (( max_parallel < 1 )); then
    max_parallel=1
  fi
  if (( requested > max_parallel )); then
    log_warn "Requested UI parallelism ${requested} exceeds max ${max_parallel}; capping"
    requested=$max_parallel
  fi
  printf "%s" "$requested"
}

resolve_ui_parallel_derived_root() {
  if [[ -n "${ZPOD_UI_TEST_PARALLEL_DERIVED_ROOT:-}" ]]; then
    printf "%s" "$ZPOD_UI_TEST_PARALLEL_DERIVED_ROOT"
    return 0
  fi
  if [[ -n "${ZPOD_DERIVED_DATA_PATH:-}" ]]; then
    printf "%s/ui-shards-%s" "$ZPOD_DERIVED_DATA_PATH" "$RUN_INVOCATION_ID"
    return 0
  fi
  printf "%s/zpod-ui-derived-%s" "${TMPDIR:-/tmp}" "$RUN_INVOCATION_ID"
}

append_ui_worker_report_entries() {
  local report_file="$1"
  [[ -f "$report_file" ]] || return 0
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in
      summary\|*)
        append_summary_item_if_new "${line#summary|}"
        ;;
      suite_timing\|*)
        local timing_entry="${line#suite_timing|}"
        append_test_suite_timing_entry_if_new "$timing_entry"
        ;;
      worker_health\|*)
        append_ui_worker_health_entry_if_new "${line#worker_health|}"
        ;;
    esac
  done < "$report_file"
}

append_summary_item_if_new() {
  local candidate="$1"
  local existing
  for existing in "${SUMMARY_ITEMS[@]-}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return 0
    fi
  done
  SUMMARY_ITEMS+=("$candidate")
}

append_test_suite_timing_entry_if_new() {
  local candidate="$1"
  local existing
  for existing in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return 0
    fi
  done
  TEST_SUITE_TIMING_ENTRIES+=("$candidate")
}

append_ui_worker_health_entry_if_new() {
  local candidate="$1"
  local existing
  for existing in "${UI_WORKER_HEALTH_ENTRIES[@]-}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return 0
    fi
  done
  UI_WORKER_HEALTH_ENTRIES+=("$candidate")
}

worker_report_has_completion_marker() {
  local report_file="$1"
  local worker_label="$2"
  [[ -f "$report_file" ]] || return 1
  if command_exists rg; then
    rg -q "^worker_health\\|${worker_label}\\|completed\\|" "$report_file"
  else
    grep -q "^worker_health|${worker_label}|completed|" "$report_file"
  fi
}

sanitize_suite_filename() {
  local suite="$1"
  local safe
  safe=$(printf "%s" "$suite" | sed -E 's/[^A-Za-z0-9._-]+/_/g')
  printf "%s" "$safe"
}

init_ui_dynamic_queue() {
  local queue_root="$1"
  shift
  local suites=("$@")
  local pending_dir="${queue_root}/pending"
  local inflight_dir="${queue_root}/inflight"
  local done_dir="${queue_root}/done"
  rm -rf "$queue_root"
  mkdir -p "$pending_dir" "$inflight_dir" "$done_dir"

  local index=1
  local suite
  for suite in "${suites[@]}"; do
    local safe_name
    safe_name=$(sanitize_suite_filename "$suite")
    local file_name
    file_name=$(printf "%04d__%s" "$index" "$safe_name")
    printf "%s\n" "$suite" > "${pending_dir}/${file_name}"
    index=$((index + 1))
  done
}

queue_remaining_count() {
  local queue_root="$1"
  local pending_dir="${queue_root}/pending"
  local inflight_dir="${queue_root}/inflight"
  local pending_count=0
  local inflight_count=0
  if [[ -d "$pending_dir" ]]; then
    pending_count=$(find "$pending_dir" -type f | wc -l | tr -d ' ')
  fi
  if [[ -d "$inflight_dir" ]]; then
    inflight_count=$(find "$inflight_dir" -type f | wc -l | tr -d ' ')
  fi
  printf "%s" $((pending_count + inflight_count))
}

teardown_ui_shard_runtime() {
  local reason="${1:-unknown}"
  local emit_summary="${2:-1}"
  if [[ "${BASHPID:-$$}" != "$ROOT_SHELL_PID" ]]; then
    return 0
  fi
  if (( UI_SHARD_ACTIVE == 0 )); then
    return 0
  fi
  if (( UI_SHARD_TEARDOWN_DONE == 1 )); then
    return 0
  fi
  UI_SHARD_TEARDOWN_DONE=1

  local grace="${ZPOD_UI_SHARD_KILL_GRACE_SECONDS:-5}"
  if [[ ! "$grace" =~ ^[0-9]+$ ]]; then
    grace=5
  fi

  local signaled=0
  local pid
  # Use terminate_process_tree to kill each worker and its entire xcodebuild
  # descendant tree (xcodebuild → xcrun → simctl → CoreSimulator), not just
  # the direct worker PID.
  for pid in "${UI_SHARD_WORKER_PIDS[@]-}"; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      terminate_process_tree "$pid" "$grace"
      signaled=$((signaled + 1))
    fi
  done

  local idx
  for idx in "${!UI_SHARD_WORKER_PIDS[@]}"; do
    pid="${UI_SHARD_WORKER_PIDS[$idx]}"
    [[ "$pid" =~ ^[0-9]+$ ]] && wait "$pid" 2>/dev/null || true

    local label="${UI_SHARD_WORKER_LABELS[$idx]:-}"
    local report_file="${UI_SHARD_WORKER_REPORTS[$idx]:-}"
    append_ui_worker_report_entries "$report_file"
    if [[ -n "$label" ]] && ! worker_report_has_completion_marker "$report_file" "$label"; then
      local remaining="unknown"
      if [[ -n "$UI_SHARD_QUEUE_ROOT" ]]; then
        remaining=$(queue_remaining_count "$UI_SHARD_QUEUE_ROOT")
      fi
      append_ui_worker_health_entry_if_new "${label}|stopped_unexpected|130|0|0|unknown|${remaining}"
    fi
  done

  local sim_udid
  for sim_udid in "${UI_SHARD_WORKER_SIMULATORS[@]-}"; do
    unregister_ephemeral_simulator "$sim_udid"
    cleanup_ephemeral_simulator "$sim_udid"
  done

  if (( emit_summary == 1 )); then
    add_summary "test" "zpodUITests sharding cancel" "error" "" "1" "0" "1" "0" \
      "cancelled (${reason}; workers_terminated=${signaled})"
  fi
  reset_ui_shard_runtime_state
}

claim_next_ui_suite() {
  local queue_root="$1"
  local worker_label="$2"
  local pending_dir="${queue_root}/pending"
  local inflight_dir="${queue_root}/inflight"
  mkdir -p "$pending_dir" "$inflight_dir"

  while true; do
    local candidate=""
    candidate=$(find "$pending_dir" -maxdepth 1 -type f -print | sort | head -n 1)
    [[ -z "$candidate" ]] && return 1
    local candidate_name
    candidate_name=$(basename "$candidate")
    local claim_path="${inflight_dir}/${worker_label}__${candidate_name}"
    if mv "$candidate" "$claim_path" 2>/dev/null; then
      local suite
      suite=$(head -n 1 "$claim_path" 2>/dev/null || true)
      if [[ -z "$suite" ]]; then
        suite="${candidate_name#*__}"
      fi
      printf "%s|%s" "$claim_path" "$suite"
      return 0
    fi
  done
}

complete_ui_suite_claim() {
  local queue_root="$1"
  local claim_path="$2"
  local suite_status="$3"
  local done_dir="${queue_root}/done"
  mkdir -p "$done_dir"
  [[ -f "$claim_path" ]] || return 0
  local claim_name
  claim_name=$(basename "$claim_path")
  mv "$claim_path" "${done_dir}/${claim_name}__${suite_status}" 2>/dev/null || true
}

normalize_suite_counts() {
  local raw_total="$1"
  local raw_failed="$2"
  local raw_skipped="$3"
  local total="${raw_total:-0}"
  local failed="${raw_failed:-0}"
  local skipped="${raw_skipped:-0}"

  if (( failed < 0 )); then failed=0; fi
  if (( skipped < 0 )); then skipped=0; fi
  if (( total < 0 )); then total=0; fi

  local minimum_total=$(( failed + skipped ))
  if (( total < minimum_total )); then
    total=$minimum_total
  fi
  local passed=$(( total - failed - skipped ))
  if (( passed < 0 )); then
    passed=0
  fi
  printf '%s|%s|%s|%s' "$total" "$passed" "$failed" "$skipped"
}

run_ui_test_suites_serial() {
  local suites=("$@")
  local suite

  local any_failed=0
  local switched_to_fresh=0
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
        register_ephemeral_simulator "$temp_sim_udid"
        log_info "Using simulator id=${temp_sim_udid} for UI suite ${suite}"
        export ZPOD_SIMULATOR_UDID="$temp_sim_udid"
      else
        log_warn "Failed to provision fresh simulator for ${suite}; using default destination"
      fi
    fi

    if ! execute_phase "UI tests ${suite}" "test" run_test_target "zpodUITests/${suite}"; then
      any_failed=1
      if (( use_fresh_sim == 0 && switched_to_fresh == 0 )); then
        switched_to_fresh=1
        use_fresh_sim=1
        log_warn "UI suite ${suite} failed; switching remaining UI suites to fresh simulators"
        reset_core_simulator_service
      fi
    fi

    # Shut down the simulator between serial suites to let CoreSimulator tear down its
    # process tree and prevent accumulation across 17+ suites (which hits the ~1333
    # user-process limit). The next suite's xcodebuild invocation will reboot it.
    local shutdown_udid="${ZPOD_SIMULATOR_UDID:-}"
    if [[ -z "$shutdown_udid" ]]; then
      # SELECTED_DESTINATION is set by select_destination() in xcode.sh and holds the
      # actual destination chosen for this run. ZPOD_DESTINATION is never populated by
      # the harness, so using it here would always produce an empty fallback.
      shutdown_udid=$(_udid_for_destination "${SELECTED_DESTINATION:-}" 2>/dev/null) || true
    fi
    if [[ -n "$shutdown_udid" ]]; then
      log_info "Shutting down simulator ${shutdown_udid} between suites to reclaim CoreSimulator processes"
      xcrun simctl shutdown "$shutdown_udid" 2>/dev/null || true
    fi

    if [[ -n "$temp_sim_udid" ]]; then
      unregister_ephemeral_simulator "$temp_sim_udid"
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
    return 1
  fi
  return 0
}

run_ui_test_shard_worker() {
  local worker_name="$1"
  local report_file="$2"
  local worker_sim_udid="$3"
  local queue_root="$4"

  : > "$report_file"
  if [[ -n "$UI_PARALLEL_SHARED_DERIVED_ROOT" ]]; then
    export ZPOD_DERIVED_DATA_PATH="$UI_PARALLEL_SHARED_DERIVED_ROOT"
  fi
  if [[ -n "$worker_sim_udid" ]]; then
    export ZPOD_SIMULATOR_UDID="$worker_sim_udid"
  fi

  local any_failed=0
  local switched_to_fresh=0
  local use_fresh_sim=0
  local claimed_count=0
  local completed_count=0
  local last_suite=""
  if [[ "${ZPOD_UI_TEST_FRESH_SIM:-0}" == "1" ]]; then
    use_fresh_sim=1
  fi
  local original_sim_udid="${ZPOD_SIMULATOR_UDID:-}"
  while true; do
    local claim_result=""
    if ! claim_result=$(claim_next_ui_suite "$queue_root" "$worker_name"); then
      break
    fi
    IFS='|' read -r claim_path suite <<< "$claim_result"
    claimed_count=$((claimed_count + 1))
    last_suite="$suite"
    local remaining_now
    remaining_now=$(queue_remaining_count "$queue_root")
    log_info "[${worker_name}] Claimed UI suite ${suite} (remaining approx: ${remaining_now})"

    local before_summary_count=${#SUMMARY_ITEMS[@]}
    local before_timing_count=${#TEST_SUITE_TIMING_ENTRIES[@]}
    local suite_start
    suite_start=$(date +%s)
    local temp_sim_udid=""

    if (( use_fresh_sim == 1 )); then
      log_info "[${worker_name}] Provisioning fresh simulator for ${suite}..."
      if temp_sim_udid=$(create_ephemeral_simulator 2>/dev/null); then
        register_ephemeral_simulator "$temp_sim_udid"
        log_info "[${worker_name}] Using simulator id=${temp_sim_udid} for ${suite}"
        export ZPOD_SIMULATOR_UDID="$temp_sim_udid"
      else
        log_warn "[${worker_name}] Failed to provision fresh simulator for ${suite}; using default destination"
      fi
    fi

    local suite_status=0
    if run_test_target "zpodUITests/${suite}"; then
      suite_status=0
    else
      suite_status=$?
      any_failed=1
      if (( use_fresh_sim == 0 && switched_to_fresh == 0 )); then
        switched_to_fresh=1
        use_fresh_sim=1
        log_warn "[${worker_name}] UI suite ${suite} failed; switching remaining shard suites to fresh simulators"
        reset_core_simulator_service
      fi
    fi

    local suite_end
    suite_end=$(date +%s)
    local suite_elapsed=$((suite_end - suite_start))
    completed_count=$((completed_count + 1))
    if (( suite_status == 0 )); then
      complete_ui_suite_claim "$queue_root" "$claim_path" "success"
    else
      complete_ui_suite_claim "$queue_root" "$claim_path" "error"
    fi

    local wrote_summary=0
    local idx
    for (( idx=before_summary_count; idx<${#SUMMARY_ITEMS[@]}; idx++ )); do
      printf 'summary|%s\n' "${SUMMARY_ITEMS[$idx]}" >> "$report_file"
      wrote_summary=1
    done
    if (( wrote_summary == 0 )); then
      local fallback_status="success"
      if (( suite_status != 0 )); then
        fallback_status="error"
      fi
      printf 'summary|test|zpodUITests/%s|%s||||||worker fallback\n' "$suite" "$fallback_status" >> "$report_file"
    fi

    local wrote_timing=0
    local timing_idx
    for (( timing_idx=before_timing_count; timing_idx<${#TEST_SUITE_TIMING_ENTRIES[@]}; timing_idx++ )); do
      printf 'suite_timing|%s\n' "${TEST_SUITE_TIMING_ENTRIES[$timing_idx]}" >> "$report_file"
      wrote_timing=1
    done
    if (( wrote_timing == 0 )); then
      local fallback_status="success"
      local fallback_failed=0
      if (( suite_status != 0 )); then
        fallback_status="error"
        fallback_failed=1
      fi
      printf 'suite_timing|zpodUITests/%s|%s|%s|%s|0|%s|0|%s\n' \
        "$suite" "$suite" "$suite_elapsed" "$fallback_status" "$fallback_failed" "${RESULT_LOG:-}" >> "$report_file"
    fi

    if [[ -n "$temp_sim_udid" ]]; then
      unregister_ephemeral_simulator "$temp_sim_udid"
      cleanup_ephemeral_simulator "$temp_sim_udid"
    fi
    if [[ -n "$original_sim_udid" ]]; then
      export ZPOD_SIMULATOR_UDID="$original_sim_udid"
    else
      unset ZPOD_SIMULATOR_UDID
    fi
  done

  local remaining_after
  remaining_after=$(queue_remaining_count "$queue_root")
  printf 'worker_health|%s|completed|%s|%s|%s|%s|%s\n' \
    "$worker_name" "$any_failed" "$claimed_count" "$completed_count" "${last_suite:-none}" "$remaining_after" >> "$report_file"
  if (( any_failed == 1 )); then
    return 1
  fi
  return 0
}

run_ui_test_suites_parallel() {
  local suites=("$@")
  local suite_count=${#suites[@]}
  if (( suite_count == 0 )); then
    return 0
  fi
  reset_ui_shard_runtime_state

  if (( UI_PARALLELISM > 1 )); then
    if ! ensure_shared_host_app_product; then
      log_info "Shared host app missing for sharded UI run; running build-for-testing preflight"
      local prebuild_start
      prebuild_start=$(date +%s)
      if build_for_testing_phase; then
        local prebuild_end
        prebuild_end=$(date +%s)
        record_phase_timing "build" "Build app and test bundles" "$((prebuild_end - prebuild_start))" "success"
      else
        local prebuild_status=$?
        local prebuild_end
        prebuild_end=$(date +%s)
        record_phase_timing "build" "Build app and test bundles" "$((prebuild_end - prebuild_start))" "error"
        update_exit_status "$prebuild_status"
        return "$prebuild_status"
      fi
      if ! ensure_shared_host_app_product; then
        add_summary "test" "UI sharding host app" "error" "" "" "" "" "" "missing zpod.app in shared derived data"
        update_exit_status "$UI_PARALLEL_SETUP_EXIT_CODE"
        return "$UI_PARALLEL_SETUP_EXIT_CODE"
      fi
    fi
  fi

  local parallelism
  parallelism=$(resolve_ui_parallelism)
  if (( parallelism < 2 || suite_count < 2 )); then
    run_ui_test_suites_serial "${suites[@]}"
    return $?
  fi
  if (( parallelism > suite_count )); then
    parallelism=$suite_count
  fi

  local derived_root
  derived_root=$(resolve_ui_parallel_derived_root)
  if ! mkdir -p "$derived_root"; then
    log_error "Failed to create UI shard derived data root: ${derived_root}"
    add_summary "test" "zpodUITests sharding" "error" "" "" "" "" "" "parallel setup failed (derived data root)"
    update_exit_status "$UI_PARALLEL_SETUP_EXIT_CODE"
    return "$UI_PARALLEL_SETUP_EXIT_CODE"
  fi

  log_info "UI sharding enabled: ${parallelism} workers for ${suite_count} suites"
  log_info "UI shard derived data root: ${derived_root}"
  log_info "UI sharding mode: dynamic queue"

  local queue_root="${derived_root}/dynamic-queue"
  init_ui_dynamic_queue "$queue_root" "${suites[@]}"
  log_info "UI queue initialized with ${suite_count} suites at ${queue_root}"

  UI_SHARD_ACTIVE=1
  UI_SHARD_TEARDOWN_DONE=0
  UI_SHARD_QUEUE_ROOT="$queue_root"
  UI_SHARD_DERIVED_ROOT="$derived_root"

  local worker_index

  for (( worker_index=0; worker_index<parallelism; worker_index++ )); do
    local worker_label="ui-shard-$((worker_index + 1))"
    local report_file="${derived_root}/${worker_label}.report"
    local worker_sim=""
    if worker_sim=$(create_ephemeral_simulator 2>/dev/null); then
      register_ephemeral_simulator "$worker_sim"
      log_info "[${worker_label}] Provisioned simulator id=${worker_sim}"
    else
      log_error "[${worker_label}] Failed to provision dedicated simulator for parallel UI run"
      log_error "Set ZPOD_UI_TEST_PARALLELISM=1 to disable sharding or retry after resetting CoreSimulator"
      teardown_ui_shard_runtime "simulator provisioning failure" 0
      add_summary "test" "zpodUITests sharding" "error" "" "" "" "" "" "parallel setup failed (simulator provisioning)"
      update_exit_status "$UI_PARALLEL_SETUP_EXIT_CODE"
      return "$UI_PARALLEL_SETUP_EXIT_CODE"
    fi
    UI_SHARD_WORKER_SIMULATORS+=("$worker_sim")
    UI_SHARD_WORKER_REPORTS+=("$report_file")
    UI_SHARD_WORKER_LABELS+=("$worker_label")

    run_ui_test_shard_worker "$worker_label" "$report_file" "$worker_sim" "$queue_root" &
    UI_SHARD_WORKER_PIDS+=($!)
  done

  local any_failed=0
  local worker_stopped_unexpected=0
  for (( worker_index=0; worker_index<${#UI_SHARD_WORKER_PIDS[@]}; worker_index++ )); do
    local pid="${UI_SHARD_WORKER_PIDS[$worker_index]}"
    local worker_status=0
    if wait "$pid"; then
      worker_status=0
      log_info "[${UI_SHARD_WORKER_LABELS[$worker_index]}] completed successfully"
    else
      worker_status=$?
      any_failed=1
      if worker_report_has_completion_marker "${UI_SHARD_WORKER_REPORTS[$worker_index]}" "${UI_SHARD_WORKER_LABELS[$worker_index]}"; then
        log_warn "[${UI_SHARD_WORKER_LABELS[$worker_index]}] completed with failing suites (status ${worker_status})"
      else
        worker_stopped_unexpected=1
        local remaining_after_stop
        remaining_after_stop=$(queue_remaining_count "$queue_root")
        log_error "[${UI_SHARD_WORKER_LABELS[$worker_index]}] stopped unexpectedly (status ${worker_status}); remaining queued/inflight suites: ${remaining_after_stop}"
        append_ui_worker_health_entry_if_new "${UI_SHARD_WORKER_LABELS[$worker_index]}|stopped_unexpected|${worker_status}|0|0|unknown|${remaining_after_stop}"
      fi
    fi
    append_ui_worker_report_entries "${UI_SHARD_WORKER_REPORTS[$worker_index]}"
  done

  local remaining_after_workers
  remaining_after_workers=$(queue_remaining_count "$queue_root")
  if (( remaining_after_workers > 0 )); then
    any_failed=1
    log_error "Dynamic UI queue not fully drained: ${remaining_after_workers} suites remained unprocessed"
    add_summary "test" "zpodUITests sharding" "error" "" "" "" "" "" "unprocessed suites remained (${remaining_after_workers})"
  fi

  if (( worker_stopped_unexpected == 1 )); then
    add_summary "test" "zpodUITests sharding workers" "error" "" "1" "0" "1" "0" "one or more shard workers stopped unexpectedly"
  fi

  local worker_sim
  for worker_sim in "${UI_SHARD_WORKER_SIMULATORS[@]-}"; do
    unregister_ephemeral_simulator "$worker_sim"
    cleanup_ephemeral_simulator "$worker_sim"
  done
  reset_ui_shard_runtime_state

  if (( any_failed == 1 )); then
    log_warn "One or more UI shards failed; continuing with remaining phases"
    return 1
  fi
  return 0
}

run_ui_test_suites() {
  if ! acquire_ui_test_lock "UI suite orchestration"; then
    return $?
  fi

  local suites=()
  local suite
  while IFS= read -r suite; do
    [[ -z "$suite" ]] && continue
    suites+=("$suite")
  done < <(list_ui_test_suites)

  if (( ${#suites[@]} == 0 )); then
    log_warn "No UI test suites discovered; falling back to zpodUITests"
    execute_phase "UI tests" "test" test_app_target "zpodUITests"
    return $?
  fi

  run_ui_test_suites_parallel "${suites[@]}"
  return $?
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
    unregister_ephemeral_simulator "$temp_sim_udid"
    cleanup_ephemeral_simulator "$temp_sim_udid"
    temp_sim_udid=""
  fi

  # Clean up stale .xcresult bundle from the failed first attempt.
  # xcodebuild refuses to write to an existing -resultBundlePath.
  if [[ -n "${RESULT_BUNDLE:-}" && -d "$RESULT_BUNDLE" ]]; then
    log_info "Removing stale result bundle before retry: ${RESULT_BUNDLE}"
    rm -rf "$RESULT_BUNDLE"
  fi

  log_warn "Retrying ${label} with a freshly created simulator..."
  local new_udid=""
  if new_udid=$(create_ephemeral_simulator 2>/dev/null); then
    temp_sim_udid="$new_udid"
    register_ephemeral_simulator "$temp_sim_udid"
    log_info "Retrying ${label} with simulator id=${temp_sim_udid}"
    args=("${original_args[@]}")
    local idx
    for idx in "${!args[@]}"; do
      if [[ "${args[$idx]}" == "-destination" ]]; then
        args[$((idx + 1))]="id=${temp_sim_udid}"
        break
      fi
    done
    # Keep SELECTED_DESTINATION in sync with the fresh simulator so the between-suite
    # shutdown code in run_ui_test_suites_serial targets the retry sim, not the stale
    # pre-retry destination.
    SELECTED_DESTINATION="platform=iOS Simulator,id=${temp_sim_udid}"
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
  # 1. Kill process trees first so simulators are idle when we delete them
  if [[ "${BASHPID:-$$}" == "$ROOT_SHELL_PID" ]] && (( UI_SHARD_ACTIVE == 1 )); then
    teardown_ui_shard_runtime "finalize-guard" 1
  fi
  # 2. Clean registered ephemeral sims (processes are already dead, so simctl won't hang)
  if [[ "${BASHPID:-$$}" == "$ROOT_SHELL_PID" ]]; then
    cleanup_all_ephemeral_simulators
  fi
  # 3. Release lock last
  if [[ "${BASHPID:-$$}" == "$ROOT_SHELL_PID" ]]; then
    release_ui_test_lock
  fi
  trap - ERR INT EXIT
  if (( SUMMARY_PRINTED == 0 )); then
    local previous_errexit=0
    case $- in
      *e*) previous_errexit=1;;
    esac
    set +e
    if [[ -n "${RESULT_LOG:-}" ]]; then
      print_summary | tee -a "$RESULT_LOG"
    else
      print_summary
    fi
    if (( previous_errexit == 1 )); then
      set -e
    fi
  fi
  SUMMARY_PRINTED=1
  if [[ -n "${START_TIME:-}" ]]; then
    local end_time elapsed formatted
    end_time=$(date +%s)
    elapsed=$((end_time - START_TIME))
    formatted=$(printf '%02d:%02d:%02d' $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60)))
    log_time "run-xcode-tests finished in ${formatted} (exit ${EXIT_STATUS}, run_id=${RUN_INVOCATION_ID:-unknown})"
  fi
  exit "$code"
}

exit_with_summary() {
  local code="${1:-1}"
  update_exit_status "$code"
  finalize_and_exit "$EXIT_STATUS"
}

handle_interrupt() {
  if [[ "${BASHPID:-$$}" != "$ROOT_SHELL_PID" ]]; then
    return
  fi
  INTERRUPTED=1
  UI_SHARD_CANCELLED=1
  if [[ -n "$CURRENT_PHASE" && $CURRENT_PHASE_RECORDED -eq 0 ]]; then
    add_summary "${CURRENT_PHASE_CATEGORY:-phase}" "$CURRENT_PHASE" "interrupted" "" "" "" "" "" "interrupted by user"
  fi
  update_exit_status 130
  teardown_ui_shard_runtime "interrupt" 1
  finalize_and_exit "$EXIT_STATUS"
}

handle_unexpected_error() {
  if [[ "${BASHPID:-$$}" != "$ROOT_SHELL_PID" ]]; then
    return
  fi
  local status=$1
  local line=$2
  if [[ -n "$CURRENT_PHASE" && $CURRENT_PHASE_RECORDED -eq 0 ]]; then
    add_summary "${CURRENT_PHASE_CATEGORY:-script}" "$CURRENT_PHASE" "error" "" "" "" "" "" "script error at line ${line}"
  elif (( ${#SUMMARY_ITEMS[@]} == 0 )); then
    add_summary "script" "runtime" "error" "" "" "" "" "" "script error at line ${line}"
  fi
  update_exit_status "$status"
  teardown_ui_shard_runtime "error-trap" 1
  finalize_and_exit "$EXIT_STATUS"
}

trap 'handle_interrupt' INT
trap 'handle_unexpected_error $? $LINENO' ERR

# Handle SIGTERM gracefully (e.g., from CI/harness timeout) to prevent
# bash from printing "Terminated: 15 <command>" to the terminal, which
# quality-gate parsers can misinterpret as a test failure. Exit cleanly
# with the current accumulated exit status instead.
handle_sigterm() {
  if [[ "${BASHPID:-$$}" != "$ROOT_SHELL_PID" ]]; then
    return
  fi
  finalize_and_exit "${EXIT_STATUS:-0}"
}
trap 'handle_sigterm' TERM

handle_exit() {
  # Ignore trap callbacks from forked shells/subprocesses. Only the original
  # run-xcode-tests shell should emit final summaries.
  if [[ "${BASHPID:-$$}" != "$ROOT_SHELL_PID" ]]; then
    return
  fi
  local status=$?
  if (( EXIT_STATUS != 0 )); then
    status=$EXIT_STATUS
  fi
  if (( UI_SHARD_ACTIVE == 1 )); then
    teardown_ui_shard_runtime "exit-trap" 1
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

ensure_shared_host_app_product() {
  if [[ -z "${UI_PARALLEL_SHARED_DERIVED_ROOT:-}" ]]; then
    return 0
  fi
  local expected_app="${UI_PARALLEL_SHARED_DERIVED_ROOT}/Build/Products/Debug-iphonesimulator/zpod.app/zpod"
  if [[ -f "$expected_app" ]]; then
    return 0
  fi
  log_error "Shared derived data root '${UI_PARALLEL_SHARED_DERIVED_ROOT}' has no host app at ${expected_app}"
  log_error "Ensure the build phase ran against this derived root before sharded UI suites start."
  return 1
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
    IFS='|' read -r suite_target suite duration status total failed skipped log_path <<< "$entry"
    [[ "$suite_target" == "$target" ]] || continue
    local symbol
    symbol=$(status_symbol "$status")
    printf '    %s %s – %s (%s tests, failed %s, skipped %s)' \
      "$symbol" "$suite" "$(format_elapsed_time "${duration:-0}")" "${total:-0}" "${failed:-0}" "${skipped:-0}"
    if [[ -n "$log_path" ]]; then
      printf " – log: %s" "$log_path"
    fi
    printf "\n"
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
  local -a groups=("Syntax" "AppSmoke" "Integration" "Lint")
  local any=0
  print_section_header "Test Timing"
  local total_all=0
  local group
  for group in "${groups[@]}"; do
    local seconds
    seconds=$(group_elapsed_seconds "$group")
    (( seconds == 0 )) && continue
    total_all=$(( total_all + seconds ))
    any=1
    local log_path
    log_path=$(first_log_for_group "$group")
    printf "  %s: %s" "$group" "$(format_elapsed_time "$seconds")"
    if [[ -n "$log_path" ]]; then
      printf " – log: %s" "$log_path"
    fi
    printf "\n"
  done
  local ui_seconds
  ui_seconds=$(group_elapsed_seconds "UI Tests")
  if (( ui_seconds > 0 )); then
    total_all=$(( total_all + ui_seconds ))
    any=1
    local ui_log
    ui_log=$(first_log_for_group "UI Tests")
    printf "  UI Tests: %s" "$(format_elapsed_time "$ui_seconds")"
    if [[ -n "$ui_log" ]]; then
      printf " – log: %s" "$ui_log"
    fi
    printf "\n"
  fi
  local package_seconds
  package_seconds=$(group_elapsed_seconds "Package Tests")
  if (( package_seconds > 0 )); then
    total_all=$(( total_all + package_seconds ))
    any=1
    local package_log
    package_log=$(first_log_for_group "Package Tests")
    printf "  Package Tests: %s" "$(format_elapsed_time "$package_seconds")"
    if [[ -n "$package_log" ]]; then
      printf " – log: %s" "$package_log"
    fi
    printf "\n"
  fi
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

  if (( ${#PACKAGE_TEST_TIMING_ENTRIES[@]} > 0 )); then
    local timing_entry
    for timing_entry in "${PACKAGE_TEST_TIMING_ENTRIES[@]-}"; do
      IFS='|' read -r package_name package_elapsed _ package_log <<< "$timing_entry"
      total_duration=$(( total_duration + ${package_elapsed:-0} ))
      any=1
      local line="    package ${package_name} – $(format_elapsed_time "${package_elapsed:-0}")"
      if [[ -n "$package_log" ]]; then
        line+=" – log: ${package_log}"
      fi
      lines+=("$line")
    done
  else
    local entry
    for entry in "${SUMMARY_ITEMS[@]-}"; do
      IFS='|' read -r category name _ log_path _ _ _ _ _ <<< "$entry"
      [[ "$category" == "test" ]] || continue
      [[ "$name" == package\ * ]] || continue
      local pkg_phase="Package tests ${name#package }"
      local duration_sec=0
      local ph_entry
      for ph_entry in "${PHASE_DURATION_ENTRIES[@]-}"; do
        IFS='|' read -r _ ph_name ph_elapsed _ <<< "$ph_entry"
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
  fi

  (( any == 0 )) && return
  printf "  Package Tests detail: %s\n" "$(format_elapsed_time "$total_duration")"
  printf '%s\n' "${lines[@]}"
}

ui_suite_timing_breakdown() {
  local any=0
  local total_duration=0
  local -a lines=()
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target suite duration status total failed skipped log_path <<< "$entry"
    [[ "$suite_target" == *UITests* ]] || continue
    local symbol
    symbol=$(status_symbol "$status")
    total_duration=$(( total_duration + ${duration:-0} ))
    any=1
    local line="    ${symbol} ${suite} – $(format_elapsed_time "${duration:-0}")"
    if [[ -n "$log_path" ]]; then
      line+=" – log: ${log_path}"
    fi
    lines+=("$line")
  done
  if (( any == 0 )); then
    # Fallback to phase timing when suite-level xcresult parsing has no entries
    # (for example, simulator boot failures before tests start).
    local phase_entry
    for phase_entry in "${PHASE_DURATION_ENTRIES[@]-}"; do
      IFS='|' read -r phase_category phase_name phase_elapsed phase_status <<< "$phase_entry"
      [[ "$phase_category" == "test" ]] || continue
      local suite_name=""
      if [[ "$phase_name" == UI\ tests\ * ]]; then
        suite_name="${phase_name#UI tests }"
      elif [[ "$phase_name" == Test\ zpodUITests/* ]]; then
        suite_name="${phase_name#Test }"
      else
        continue
      fi
      local symbol
      symbol=$(status_symbol "$phase_status")
      total_duration=$(( total_duration + ${phase_elapsed:-0} ))
      any=1
      lines+=("    ${symbol} ${suite_name} – $(format_elapsed_time "${phase_elapsed:-0}")")
    done
  fi
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
  local minimum_total=$(( passed + failed + skipped ))
  if (( total < minimum_total )); then
    total=$minimum_total
  fi
  if (( passed < 0 )); then
    passed=0
  fi
  if (( passed > total )); then
    passed=$(( total - failed - skipped ))
    if (( passed < 0 )); then
      passed=0
    fi
  fi
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
  print_ui_worker_health_summary
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
  local computed_total=0
  local computed_failed=0
  local computed_skipped=0
  local computed_warn=0
  local computed_present=0
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target _ _ status suite_total suite_failed suite_skipped _ <<< "$entry"
    [[ "$suite_target" == *UITests* ]] || continue
    local normalized_counts
    normalized_counts=$(normalize_suite_counts "$suite_total" "$suite_failed" "$suite_skipped")
    IFS='|' read -r suite_total _ suite_failed suite_skipped <<< "$normalized_counts"
    computed_present=1
    (( computed_total += suite_total ))
    (( computed_failed += suite_failed ))
    (( computed_skipped += suite_skipped ))
    [[ "$status" == "warn" ]] && (( computed_warn += 1 ))
  done
  if (( computed_present == 1 )); then
    summary_total="$computed_total"
    summary_failed="$computed_failed"
    summary_skipped="$computed_skipped"
    summary_passed=$(( summary_total - summary_failed - summary_skipped ))
    if (( summary_passed < 0 )); then
      summary_passed=0
    fi
    summary_warn="$computed_warn"
    present=1
  fi
  if (( present == 0 )); then
    return
  fi
  if (( computed_present == 0 )); then
    # Fall back to per-target summary rows when suite-level timing rows are absent.
    printf "  UI suite results: total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)\n" \
      "${summary_total:-0}" "${summary_passed:-0}" "${summary_failed:-0}" "${summary_skipped:-0}" "${summary_warn:-0}"
    local summary_entry
    for summary_entry in "${SUMMARY_ITEMS[@]-}"; do
      IFS='|' read -r category name status log_path entry_total entry_passed entry_failed entry_skipped _ <<< "$summary_entry"
      [[ "$category" == "test" ]] || continue
      local group
      group=$(test_group_for "$category" "$name")
      [[ "$group" == "UI Tests" ]] || continue
      local suite_total="${entry_total:-0}"
      local suite_failed="${entry_failed:-0}"
      local suite_skipped="${entry_skipped:-0}"
      local suite_passed="${entry_passed:-$(( suite_total - suite_failed - suite_skipped ))}"
      if (( suite_passed < 0 )); then
        suite_passed=0
      fi
      local suite_warn=0
      [[ "$status" == "warn" ]] && suite_warn=1
      printf "    %s – total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)" \
        "$name" "$suite_total" "$suite_passed" "$suite_failed" "$suite_skipped" "$suite_warn"
      if [[ -n "$log_path" ]]; then
        printf " – log: %s" "$log_path"
      fi
      printf "\n"
    done
    return
  fi
  local printed_header=0
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target suite duration status suite_total suite_failed suite_skipped log_path <<< "$entry"
    [[ "$suite_target" == *UITests* ]] || continue
    if (( printed_header == 0 )); then
      printf "  UI suite results: total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)\n" \
        "${summary_total:-0}" "${summary_passed:-0}" "${summary_failed:-0}" "${summary_skipped:-0}" "${summary_warn:-0}"
    fi
    printed_header=1
    local normalized_counts
    normalized_counts=$(normalize_suite_counts "$suite_total" "$suite_failed" "$suite_skipped")
    local passed
    IFS='|' read -r suite_total passed suite_failed suite_skipped <<< "$normalized_counts"
    local suite_warn=0
    [[ "$status" == "warn" ]] && suite_warn=1
    printf "    %s – total %s (✅ %s, ❌ %s, ⏭️ %s, ⚠️ %s)" \
      "$suite" "${suite_total:-0}" "${passed:-0}" "${suite_failed:-0}" "${suite_skipped:-0}" "$suite_warn"
    if [[ -n "$log_path" ]]; then
      printf " – log: %s" "$log_path"
    fi
    printf "\n"
  done
}

print_ui_worker_health_summary() {
  # Guard: [@]-" on an empty array expands to one empty string (not nothing), so
  # always check the length first rather than relying on the loop count.
  (( ${#UI_WORKER_HEALTH_ENTRIES[@]} == 0 )) && return

  local unexpected_count=0
  local entry
  for entry in "${UI_WORKER_HEALTH_ENTRIES[@]+"${UI_WORKER_HEALTH_ENTRIES[@]}"}"; do
    IFS='|' read -r _ event _ _ _ _ _ <<< "$entry"
    [[ "$event" == "stopped_unexpected" ]] && unexpected_count=$((unexpected_count + 1))
  done

  if (( unexpected_count > 0 )); then
    printf "  UI shard worker health: ❌ %s worker(s) stopped unexpectedly\n" "$unexpected_count"
  else
    printf "  UI shard worker health: ✅ all workers completed\n"
  fi

  for entry in "${UI_WORKER_HEALTH_ENTRIES[@]+"${UI_WORKER_HEALTH_ENTRIES[@]}"}"; do
    IFS='|' read -r worker_label event status claimed completed last_suite remaining <<< "$entry"
    case "$event" in
      completed)
        local worker_failures=0
        [[ "${status:-0}" == "1" ]] && worker_failures=1
        if (( worker_failures == 1 )); then
          printf "    %s – completed (suites %s/%s, last suite %s, remaining %s, suite failures encountered)\n" \
            "$worker_label" "${completed:-0}" "${claimed:-0}" "${last_suite:-none}" "${remaining:-0}"
        else
          printf "    %s – completed (suites %s/%s, last suite %s, remaining %s)\n" \
            "$worker_label" "${completed:-0}" "${claimed:-0}" "${last_suite:-none}" "${remaining:-0}"
        fi
        ;;
      stopped_unexpected)
        printf "    %s – stopped unexpectedly (exit %s, completed %s/%s, last suite %s, remaining %s)\n" \
          "$worker_label" "${status:-unknown}" "${completed:-0}" "${claimed:-0}" "${last_suite:-unknown}" "${remaining:-unknown}"
        ;;
      *)
        printf "    %s – event %s (status %s, suites %s/%s, last suite %s, remaining %s)\n" \
          "$worker_label" "${event:-unknown}" "${status:-unknown}" "${completed:-0}" "${claimed:-0}" "${last_suite:-unknown}" "${remaining:-unknown}"
        ;;
    esac
  done
}

print_ui_suite_breakdown() {
  local printed_header=0
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target suite duration status total failed skipped log_path <<< "$entry"
    [[ "$suite_target" == *UITests* ]] || continue
    if (( printed_header == 0 )); then
      printf "  UI suites:\n"
      printed_header=1
    fi
    local symbol
    symbol=$(status_symbol "$status")
    local normalized_counts
    normalized_counts=$(normalize_suite_counts "$total" "$failed" "$skipped")
    local passed
    IFS='|' read -r total passed failed skipped <<< "$normalized_counts"
    printf "    %s %s – total %s (✅ %s, ❌ %s, ⏭️ %s)" \
      "$symbol" "$suite" "${total:-0}" "${passed:-0}" "${failed:-0}" "${skipped:-0}"
    if [[ -n "$log_path" ]]; then
      printf " – log: %s" "$log_path"
    fi
    printf "\n"
  done
}

aggregate_suite_counts() {
  local target="$1"
  local total=0 failed=0 skipped=0
  local entry
  for entry in "${TEST_SUITE_TIMING_ENTRIES[@]-}"; do
    IFS='|' read -r suite_target _ _ status suite_total suite_failed suite_skipped _ <<< "$entry"
    [[ "$suite_target" == "$target" ]] || continue
    local normalized_counts
    normalized_counts=$(normalize_suite_counts "$suite_total" "$suite_failed" "$suite_skipped")
    IFS='|' read -r suite_total _ suite_failed suite_skipped <<< "$normalized_counts"
    (( total += suite_total ))
    (( failed += suite_failed ))
    (( skipped += suite_skipped ))
  done
  local counts
  counts=$(normalize_suite_counts "$total" "$failed" "$skipped")
  local passed
  IFS='|' read -r total passed failed skipped <<< "$counts"
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
  if [[ -n "${RUN_INVOCATION_ID:-}" ]]; then
    printf '  Run ID: %s\n' "$RUN_INVOCATION_ID"
  fi
  printf '  Exit Status: %s\n' "$EXIT_STATUS"
  if [[ -n "${START_TIME:-}" ]]; then
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    printf '  Elapsed Time: %s\n' "$(format_elapsed_time "$elapsed")"
  fi
  if [[ -n "${START_TIME_HUMAN:-}" ]]; then
    local end_time_human
    end_time_human=$(date "+%Y-%m-%d %H:%M:%S %Z")
    printf '  Started: %s\n' "$START_TIME_HUMAN"
    printf '  Ended: %s\n' "$end_time_human"
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
    IFS='|' read -r target suite duration status total failed skipped log_path <<< "$entry"
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
        IFS='|' read -r target suite duration status total failed skipped log_path <<< "$entry"
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
  local output
  if [[ -d "$bundle" ]] && command_exists python3 && command_exists xcrun; then
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

has_all = any("::All tests::" in suite for suite, _, _ in results)
has_selected = any("::Selected tests::" in suite for suite, _, _ in results)
if has_all:
  results = [entry for entry in results if "::All tests::" in entry[0]]
elif has_selected:
  results = [entry for entry in results if "::Selected tests::" in entry[0]]

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
        local normalized_counts
        normalized_counts=$(normalize_suite_counts "$total" "$failed" "$skipped")
        IFS='|' read -r total _ failed skipped <<< "$normalized_counts"
        append_test_suite_timing_entry_if_new "${target_label}|${suite}|${duration}|${status}|${total}|${failed}|${skipped}|${log_path}"
      done <<< "$output"
      return
    fi
  fi

  # Fallback: parse xcodebuild log for suite timing when xcresulttool is unavailable
  if [[ -n "$log_path" && -f "$log_path" ]] && command_exists python3; then
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
        IFS='|' read -r suite_target suite duration status total failed skipped <<< "$line"
        local normalized_counts
        normalized_counts=$(normalize_suite_counts "$total" "$failed" "$skipped")
        IFS='|' read -r total _ failed skipped <<< "$normalized_counts"
        append_test_suite_timing_entry_if_new "${suite_target}|${suite}|${duration}|${status}|${total}|${failed}|${skipped}|${log_path}"
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
  [targets...]      Zero or more test targets. Each MUST be a .swift file path or a suite directory name:
                      • .swift file path:  zpodUITests/SmartPlaylistAuthoringUITests.swift
                                           zpodUITests/PageObjects/SmartPlaylistScreen.swift
                      • suite directory:   zpodUITests  AppSmokeTests  IntegrationTests  Packages
                    File paths are classified automatically: test classes, page objects, test
                    helpers, and production sources are all resolved to test targets.
                    Bare class names (without a path) are NOT supported.
                    Omit to run the full default pipeline.
  -c                Clean before running build/test
  -s                Run Swift syntax verification only (no build or tests)
  -l                Run Swift lint checks (swiftlint/swift-format if available)
  -p [suite]        Verify test plan coverage (optional suite: default, AppSmokeTests, zpodUITests, IntegrationTests)
  --oslog-debug     Enable OSLog debug output and emit a post-test log summary
  --scheme <name>   Xcode scheme to use (default: "zpod (zpod project)")
  --workspace <ws>  Path to workspace (default: zpod.xcworkspace)
  --sim <device>    Preferred simulator name (default: "iPhone 17 Pro")
  --clear-ui-lock   Stop lock owner process tree (if active), clear UI lock, remove UI shard artifacts, and exit
  --reap            Find and kill orphaned run-xcode-tests.sh processes from previous runs
  --reap-dry-run    Show what --reap would kill without actually killing
  --self-check      Run environment self-checks and exit
  --help            Show this message

Environment:
  ZPOD_UI_TEST_FRESH_SIM=1        Run each UI suite on a fresh simulator (overrides ZPOD_SIMULATOR_UDID per suite)
  ZPOD_UI_TEST_LOCK_MODE=off      Disable UI lock (default: strict; prevents concurrent UI runs)
  ZPOD_UI_TEST_LOCK_DIR=<path>    Override UI lock directory (default: TMPDIR-based repo-specific path)
  ZPOD_UI_LOCK_CLEAR_KILL_GRACE_SECONDS=<n>  TERM grace seconds before KILL when clearing active lock (default: 5)
  ZPOD_UI_TEST_PARALLELISM=<n>    Run UI suites across n shards in one invocation (default: 1)
  ZPOD_UI_TEST_PARALLEL_MAX=<n>   Cap max UI shard workers (default: 4 local, 5 CI)
  ZPOD_UI_TEST_PARALLEL_DERIVED_ROOT=<path>
                                  Root for per-shard DerivedData paths when parallel UI sharding is enabled
  ZPOD_REAP_ORPHAN_AFTER_SECONDS=<n>  Min age in seconds before a harness process is considered orphaned (default: 120)
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
  REQUESTED_POSITIONAL_TARGETS=("AppSmokeTests")
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

add_package_test_target_entry() {
  local target="$1"
  local pkg="$2"
  PACKAGE_TEST_TARGET_ENTRIES+=("${target}|${pkg}")
}

lookup_package_for_test_target() {
  local identifier="$1"
  local entry
  for entry in "${PACKAGE_TEST_TARGET_ENTRIES[@]-}"; do
    if [[ "$entry" == "${identifier}|"* ]]; then
      printf '%s' "${entry#*|}"
      return 0
    fi
  done
  return 1
}

load_package_test_targets() {
  if (( PACKAGE_TEST_TARGETS_LOADED == 1 )); then
    return 0
  fi
  [[ -d "${REPO_ROOT}/Packages" ]] || { PACKAGE_TEST_TARGETS_LOADED=1; return 0; }

  local pkg_dir pkg_name default_test_target
  for pkg_dir in "${REPO_ROOT}/Packages"/*; do
    [[ -d "$pkg_dir" ]] || continue
    pkg_name="$(basename "$pkg_dir")"
    default_test_target="${pkg_name}Tests"
    if [[ -d "${pkg_dir}/Tests" ]]; then
      add_package_test_target_entry "$default_test_target" "$pkg_name"
    fi
  done

  PACKAGE_TEST_TARGETS_LOADED=1
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
  load_package_test_targets || true
  if lookup_package_for_test_target "$identifier" >/dev/null 2>&1; then
    lookup_package_for_test_target "$identifier"
    return 0
  fi
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
      (( error_count += 1 ))
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

  if [[ "$target" == AppSmokeTests* ]]; then
    local clean_flag=$REQUESTED_CLEAN
    run_filtered_xcode_tests "AppSmokeTests" "$clean_flag" "$target"
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

  if boot_simulator_destination "$resolved_destination" "$target"; then
    :
  else
    local boot_status=$?
    add_summary "test" "${target}" "error" "$RESULT_LOG" "" "" "" "" "failed (simulator boot)"
    update_exit_status "$boot_status"
    return "$boot_status"
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
  local retry_attempted=0
  local timeout_seconds=""
  run_tests_once() {
    set +e
    timeout_seconds=$(resolve_xcodebuild_timeout "$target")
    if [[ -n "$timeout_seconds" ]]; then
      ZPOD_XCODEBUILD_TIMEOUT_SECONDS="$timeout_seconds" xcodebuild_wrapper "${args[@]}" 2>&1 | tee "$RESULT_LOG"
    else
      ZPOD_XCODEBUILD_TIMEOUT_SECONDS=0 xcodebuild_wrapper "${args[@]}" 2>&1 | tee "$RESULT_LOG"
    fi
    local status=${PIPESTATUS[0]}
    set -e
    return "$status"
  }

  run_tests_once
  local xc_status=$?

  local temp_sim_udid=""
  # Attempt ONE retry for infrastructure failures (sim boot, bundle load, crash).
  # retry_with_fresh_sim is a no-op after the first call (retry_attempted guard),
  # but we also skip remaining checks via elif to avoid wasteful log scanning.
  if [[ $xc_status -ne 0 ]] && [[ -f "$RESULT_LOG" ]]; then
    if is_sim_boot_failure_log "$RESULT_LOG"; then
      retry_with_fresh_sim "$target" "Simulator boot failure detected" run_tests_once
    elif is_system_test_bundle_failure_log "$RESULT_LOG"; then
      retry_with_fresh_sim "$target" "System-level test bundle failure detected" run_tests_once
    elif is_early_test_bootstrap_failure_log "$RESULT_LOG"; then
      retry_with_fresh_sim "$target" "Early test bootstrap crash detected" run_tests_once
    elif is_test_runner_restart_log "$RESULT_LOG" && ! has_explicit_test_case_failures_log "$RESULT_LOG"; then
      retry_with_fresh_sim "$target" "Test runner restarted after unexpected exit" run_tests_once
    fi
  fi

  unregister_ephemeral_simulator "$temp_sim_udid"
  cleanup_ephemeral_simulator "$temp_sim_udid"
  log_oslog_debug "$target"

  # Parse test results from log file as fallback
  local log_total=0 log_passed=0 log_failed=0
  if [[ -f "$RESULT_LOG" ]]; then
    # Extract: "Executed X tests, with Y failures"
    local counts_line=""
    counts_line=$(grep -E "Test Suite 'All tests'.*Executed [0-9]+ tests?, with [0-9]+ failures?" "$RESULT_LOG" | tail -1 || true)
    if [[ -z "$counts_line" ]]; then
      counts_line=$(grep -E "Test Suite '.*\\.xctest'.*Executed [0-9]+ tests?, with [0-9]+ failures?" "$RESULT_LOG" | tail -1 || true)
    fi
    if [[ -z "$counts_line" ]]; then
      counts_line=$(grep -E "Executed [0-9]+ tests?, with [0-9]+ failures?" "$RESULT_LOG" | tail -1 || true)
    fi
    if [[ -n "$counts_line" ]] && [[ $counts_line =~ Executed[[:space:]]+([0-9]+)[[:space:]]+tests?,[[:space:]]+with[[:space:]]+([0-9]+)[[:space:]]+failures? ]]; then
      log_total="${BASH_REMATCH[1]}"
      log_failed="${BASH_REMATCH[2]}"
      log_passed=$((log_total - log_failed))
    fi
  fi

  if (( xc_status == 124 )); then
    record_test_suite_timings "$RESULT_BUNDLE" "$target" "$RESULT_LOG"
    local note="timed out"
    if [[ -n "$timeout_seconds" ]]; then
      log_error "xcodebuild timed out after ${timeout_seconds}s -> $RESULT_LOG"
    else
      log_error "xcodebuild timed out -> $RESULT_LOG"
    fi
    if (( log_total > 0 )); then
      note="timed out (partial)"
    fi
    add_summary "test" "${target}" "error" "$RESULT_LOG" "$log_total" "$log_passed" "$log_failed" "0" "$note"
    update_exit_status "$xc_status"
    return "$xc_status"
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
        elif grep -q "\\*\\* TEST FAILED \\*\\*" "$RESULT_LOG"; then
          log_error "Tests failed (from log marker) -> $RESULT_LOG"
          add_summary "test" "${target}" "error" "$RESULT_LOG" "$log_total" "$log_passed" "0" "0" "failed (log marker)"
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
  local package_start
  package_start=$(date +%s)
  init_result_paths "test_pkg" "$package"
  register_result_log "$RESULT_LOG"
  
  # Check if package has a Tests directory
  local pkg_path="${REPO_ROOT}/Packages/${package}"
  if [[ ! -d "${pkg_path}/Tests" ]]; then
    log_warn "Skipping swift test for package '${package}' (no Tests directory)"
    printf "⚠️ Package %s skipped: no Tests directory found.\n" "$package" | tee "$RESULT_LOG" >/dev/null
    add_summary "test" "package ${package}" "warn" "$RESULT_LOG" "" "" "" "" "skipped (no tests)"
    local package_end package_elapsed
    package_end=$(date +%s)
    package_elapsed=$((package_end - package_start))
    record_package_test_timing "$package" "$package_elapsed" "warn" "$RESULT_LOG"
    return 0
  fi
  
  if package_supports_host_build "$package"; then
    :
  else
    log_warn "Skipping swift test for package '${package}' (host platform unsupported on this machine)"
    printf "⚠️ Package %s skipped: host platform does not match declared platforms.\n" "$package" | tee "$RESULT_LOG" >/dev/null
    add_summary "test" "package ${package}" "warn" "$RESULT_LOG" "" "" "" "" "skipped (host platform unsupported)"
    local package_end package_elapsed
    package_end=$(date +%s)
    package_elapsed=$((package_end - package_start))
    record_package_test_timing "$package" "$package_elapsed" "warn" "$RESULT_LOG"
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
    local package_end package_elapsed
    package_end=$(date +%s)
    package_elapsed=$((package_end - package_start))
    record_package_test_timing "$package" "$package_elapsed" "error" "$RESULT_LOG"
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
  local package_end package_elapsed
  package_end=$(date +%s)
  package_elapsed=$((package_end - package_start))
  record_package_test_timing "$package" "$package_elapsed" "success" "$RESULT_LOG"
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

run_sleep_lint() {
  init_result_paths "lint" "sleep"
  register_result_log "$RESULT_LOG"
  log_section "Sleep usage lint (UI tests)"

  # Search for Thread.sleep or usleep in UI test files
  local violations=""
  violations=$(
    rg -n --no-heading --color never "Thread\.sleep\(|usleep\(" "${REPO_ROOT}/zpodUITests" \
      --glob '!*.md' \
      2>/dev/null || true
  )
  if [[ -n "$violations" ]]; then
    violations=$(printf '%s\n' "$violations" | grep -v "// ALLOWED:" || true)
  fi

  if [[ -n "$violations" ]]; then
    log_warn "Found sleep usage in UI tests - prefer waitUntil() from UITestWait.swift"
    echo "Sleep usage violations:" | tee "$RESULT_LOG"
    echo "$violations" | tee -a "$RESULT_LOG"
    echo "" | tee -a "$RESULT_LOG"
    echo "Migration guide:" | tee -a "$RESULT_LOG"
    echo "  • Thread.sleep() → element.waitUntil(.exists, timeout: X)" | tee -a "$RESULT_LOG"
    echo "  • usleep() → element.waitUntil(.stable(), timeout: X)" | tee -a "$RESULT_LOG"
    echo "" | tee -a "$RESULT_LOG"
    echo "To allow intentional sleep (rare), add comment: // ALLOWED: reason" | tee -a "$RESULT_LOG"

    local violation_count
    violation_count=$(echo "$violations" | wc -l | tr -d ' ')
    add_summary "lint" "sleep usage" "warn" "$RESULT_LOG" "" "" "" "" "${violation_count} violations"
    return 0  # Warning, not error
  fi

  log_success "No sleep usage found in UI tests"
  echo "✅ No Thread.sleep or usleep found (prefer waitUntil() helpers)" | tee "$RESULT_LOG"
  add_summary "lint" "sleep usage" "success" "$RESULT_LOG" "" "" "" "" "clean"
  return 0
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

  if boot_simulator_destination "$resolved_destination" "$label"; then
    :
  else
    local boot_status=$?
    add_summary "test" "${label}" "error" "$RESULT_LOG" "" "" "" "" "failed (simulator boot)"
    update_exit_status "$boot_status"
    return "$boot_status"
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

  local includes_app_smoke=0
  if [[ $integration_run -eq 0 ]]; then
    local selected_filter
    for selected_filter in "${filters[@]}"; do
      if [[ "$selected_filter" == AppSmokeTests* ]]; then
        includes_app_smoke=1
        break
      fi
    done
  fi

  if [[ $clean_flag -eq 1 && $use_test_without_building -eq 0 ]]; then
    args+=(clean)
  fi

  local restored_host_artifact=0
  if [[ -n "${ZPOD_DERIVED_DATA_PATH:-}" ]] \
    && [[ -f "${ZPOD_DERIVED_DATA_PATH}/.zpod-restored-host-artifact" ]]; then
    restored_host_artifact=1
  fi

  local force_app_smoke_build_test=0
  if [[ $use_test_without_building -eq 1 && $includes_app_smoke -eq 1 ]]; then
    if [[ $restored_host_artifact -eq 1 ]]; then
      log_warn "Detected restored host-app artifact in derived data; keeping test-without-building for AppSmoke to avoid module cache mismatches"
    else
      force_app_smoke_build_test=1
    fi
  fi

  # NOTE: AppSmoke is unstable under test-without-building on Xcode 26.2/iOS 26.1
  # (early unexpected exit + signal kill before completion). Force build+test for
  # AppSmoke filters while preserving test-without-building for the heavier suites.
  if [[ $use_test_without_building -eq 1 && $force_app_smoke_build_test -eq 0 ]]; then
    args+=(test-without-building)
  else
    if [[ $force_app_smoke_build_test -eq 1 ]]; then
      log_warn "Forcing build+test for AppSmoke filters (test-without-building is flaky on current runtime)"
    fi
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
  local -a original_args=("${args[@]}")
  local retry_attempted=0
  run_tests_once() {
    set +e
    local timeout_seconds
    timeout_seconds=$(resolve_xcodebuild_timeout "$label")
    if [[ -n "$timeout_seconds" ]]; then
      ZPOD_XCODEBUILD_TIMEOUT_SECONDS="$timeout_seconds" xcodebuild_wrapper "${args[@]}" 2>&1 | tee "$RESULT_LOG"
    else
      ZPOD_XCODEBUILD_TIMEOUT_SECONDS=0 xcodebuild_wrapper "${args[@]}" 2>&1 | tee "$RESULT_LOG"
    fi
    local status=${PIPESTATUS[0]}
    set -e
    return "$status"
  }

  run_tests_once
  local xc_status=$?

  # Attempt ONE retry for infrastructure failures (sim boot, bundle load, crash).
  if [[ $xc_status -ne 0 ]] && [[ -f "$RESULT_LOG" ]]; then
    if is_sim_boot_failure_log "$RESULT_LOG"; then
      retry_with_fresh_sim "$label" "Simulator boot failure detected" run_tests_once
    elif is_system_test_bundle_failure_log "$RESULT_LOG"; then
      retry_with_fresh_sim "$label" "System-level test bundle failure detected" run_tests_once
    elif is_early_test_bootstrap_failure_log "$RESULT_LOG"; then
      retry_with_fresh_sim "$label" "Early test bootstrap crash detected" run_tests_once
    elif is_test_runner_restart_log "$RESULT_LOG" && ! has_explicit_test_case_failures_log "$RESULT_LOG"; then
      retry_with_fresh_sim "$label" "Test runner restarted after unexpected exit" run_tests_once
    fi
  fi

  unregister_ephemeral_simulator "$temp_sim_udid"
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

run_package_suite() {
  local packages=()
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    packages+=("$pkg")
  done < <(list_package_targets)

  if (( ${#packages[@]} == 0 )); then
    log_warn "No Swift packages detected; nothing to test"
    add_summary "test" "Packages" "warn" "" "" "" "" "no packages found"
    return 0
  fi

  for pkg in "${packages[@]}"; do
    test_package_target "$pkg"
  done
  return 0
}

run_test_target() {
  local target
  target=$(resolve_test_identifier "$1") || exit_with_summary 1
  if [[ "$target" == "zpodUITests" ]] && (( UI_PARALLELISM > 1 )); then
    log_info "Routing ${target} through sharded UI suite orchestration (parallelism=${UI_PARALLELISM})"
    local previous_twb="${ZPOD_TEST_WITHOUT_BUILDING:-}"
    export ZPOD_TEST_WITHOUT_BUILDING=1
    run_ui_test_suites
    local status=$?
    if [[ -n "$previous_twb" ]]; then
      export ZPOD_TEST_WITHOUT_BUILDING="$previous_twb"
    else
      unset ZPOD_TEST_WITHOUT_BUILDING
    fi
    return $status
  fi
  if target_includes_ui_tests "$target"; then
    acquire_ui_test_lock "target ${target}" || return $?
  fi
  case "$target" in
    Packages)
      run_package_suite || return $?;;
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

  local normalized
  normalized=$(printf '%s' "$spec" | tr '[:upper:]' '[:lower:]')
  if [[ "$normalized" == "packages" ]]; then
    echo "Packages"
    return 0
  fi

  load_package_test_targets || true
  if lookup_package_for_test_target "$spec" >/dev/null 2>&1; then
    lookup_package_for_test_target "$spec"
    return 0
  fi

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
    if lookup_package_for_test_target "$first_part" >/dev/null 2>&1; then
      local pkg
      pkg=$(lookup_package_for_test_target "$first_part")
      log_warn "Package test filtering is not supported; running full package '${pkg}'"
      echo "$pkg"
      return 0
    fi
    for candidate in "${known_targets[@]}"; do
      if [[ "$first_part" == "$candidate" ]]; then
        echo "$spec"
        return 0
      fi
    done

    if is_package_target "$first_part"; then
      log_warn "Package test filtering is not supported; running full package '$first_part'"
      echo "$first_part"
      return 0
    fi

    if package_match=$(find_package_for_test_target "$first_part" 2>/dev/null); then
      if [[ -n "$package_match" ]]; then
        log_warn "Package test filtering is not supported; running full package '$package_match'"
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

# Resolves a single pre-split test spec to one or more test target specs, printed one per line.
# Accepts: .swift file paths, suite directory names, Target/ClassName slash specs, or package names.
# Bare class names (no path separator, no .swift) that are not known targets are NOT supported.
resolve_single_target() {
  local spec="$1"
  # Normalize: strip leading ./ and convert absolute paths to repo-relative
  spec="${spec#./}"
  [[ "$spec" == /* ]] && spec="${spec#${REPO_ROOT}/}"

  # Case 1: Known suite directory name (case-insensitive)
  local lower_spec
  lower_spec=$(printf '%s' "$spec" | tr '[:upper:]' '[:lower:]')
  case "$lower_spec" in
    zpoduitests)      echo "zpodUITests";      return 0;;
    appsmoketests)    echo "AppSmokeTests";    return 0;;
    integrationtests) echo "IntegrationTests"; return 0;;
    packages)         echo "Packages";         return 0;;
  esac

  # Case 2: Target/ClassName slash spec without .swift (e.g. zpodUITests/CoreUINavigationTests)
  # Pass through directly — test_app_target already handles this via -only-testing.
  if [[ "$spec" == */* && "$spec" != *.swift ]]; then
    echo "$spec"
    return 0
  fi

  # Case 3: Packages/ path ending in .swift
  # Check manifest first for a specific mapping (e.g. production source → UI test).
  # Fall back to the full Packages suite when no manifest entry exists.
  if [[ "$spec" == Packages/* && "$spec" == *.swift ]]; then
    local manifest="${REPO_ROOT}/scripts/test-manifest.json"
    if [[ -f "$manifest" ]]; then
      local manifest_targets
      manifest_targets=$(jq -r --arg p "$spec" '.sourceToTests[$p][]? // empty' "$manifest" 2>/dev/null || true)
      if [[ -n "$manifest_targets" ]]; then
        while IFS= read -r t; do
          [[ -n "$t" ]] && echo "$t"
        done <<< "$manifest_targets"
        return 0
      fi
    fi
    echo "Packages"
    return 0
  fi

  # Case 4: .swift file path
  if [[ "$spec" == *.swift ]]; then
    local abs_path="${REPO_ROOT}/${spec}"
    if [[ ! -f "$abs_path" ]]; then
      log_warn "resolve_single_target: file not found on disk: $spec"
      return 0
    fi

    local class_name
    class_name="${spec##*/}"          # basename
    class_name="${class_name%.swift}" # strip .swift extension

    # Case 4a: Root-level file in a test target directory (not in a subdirectory)
    if [[ "$spec" =~ ^(zpodUITests|AppSmokeTests|IntegrationTests)/[^/]+\.swift$ ]]; then
      local suite_dir="${spec%%/*}"
      echo "${suite_dir}/${class_name}"
      return 0
    fi

    # Case 4b: PageObjects/ or TestSupport/ — grep for test files that reference this class
    if [[ "$spec" == */PageObjects/*.swift || "$spec" == */TestSupport/*.swift ]]; then
      local found=0
      local hit_file
      while IFS= read -r hit_file; do
        local hit_class="${hit_file##*/}"
        hit_class="${hit_class%.swift}"
        local inferred
        inferred=$(infer_target_for_class "$hit_class" 2>/dev/null) || continue
        echo "${inferred}/${hit_class}"
        found=1
      done < <(rg -l --hidden "$class_name" \
                 "${REPO_ROOT}/zpodUITests" \
                 "${REPO_ROOT}/AppSmokeTests" \
                 "${REPO_ROOT}/IntegrationTests" 2>/dev/null | grep '\.swift$' || true)
      if (( found )); then return 0; fi
      log_warn "resolve_single_target: no test files reference '$class_name' (from $spec)"
      return 0
    fi

    # Case 4c: Production source — check manifest first, then grep
    local manifest="${REPO_ROOT}/scripts/test-manifest.json"
    if [[ -f "$manifest" ]]; then
      local manifest_targets
      manifest_targets=$(jq -r --arg p "$spec" '.sourceToTests[$p][]? // empty' "$manifest" 2>/dev/null || true)
      if [[ -n "$manifest_targets" ]]; then
        while IFS= read -r t; do
          [[ -n "$t" ]] && echo "$t"
        done <<< "$manifest_targets"
        return 0
      fi
    fi

    # Grep fallback for production source
    local found=0
    local hit_file
    while IFS= read -r hit_file; do
      local hit_class="${hit_file##*/}"
      hit_class="${hit_class%.swift}"
      local inferred
      inferred=$(infer_target_for_class "$hit_class" 2>/dev/null) || continue
      echo "${inferred}/${hit_class}"
      found=1
    done < <(rg -l --hidden "$class_name" \
               "${REPO_ROOT}/zpodUITests" \
               "${REPO_ROOT}/AppSmokeTests" \
               "${REPO_ROOT}/IntegrationTests" 2>/dev/null | grep '\.swift$' || true)
    if (( found )); then return 0; fi
    log_warn "resolve_single_target: no test target found for production source: $spec"
    return 0
  fi

  # Case 5: No slash, no .swift — could be a package test target (e.g. CoreModels)
  load_package_test_targets 2>/dev/null || true
  if is_package_target "$spec" 2>/dev/null; then
    echo "$spec"
    return 0
  fi

  # Case 6: Unrecognized
  log_warn "resolve_single_target: unrecognized argument '$spec' (expected a .swift file path, suite directory like zpodUITests, or Target/ClassName spec)"
  return 0
}

# Iterates REQUESTED_POSITIONAL_TARGETS, splits comma-separated values, resolves each via
# resolve_single_target, deduplicates, and sets REQUESTED_TESTS as a comma-separated string.
# Returns 1 if no targets could be resolved (caller should fall back to full suite).
resolve_positional_targets() {
  local resolved=()
  local spec sub_spec
  for spec in "${REQUESTED_POSITIONAL_TARGETS[@]}"; do
    spec="$(trim "$spec")"
    [[ -z "$spec" ]] && continue
    # Support comma-separated values in a single positional arg (CI matrix compat)
    split_csv "$spec"
    for sub_spec in "${__ZPOD_SPLIT_RESULT[@]}"; do
      sub_spec="$(trim "$sub_spec")"
      [[ -z "$sub_spec" ]] && continue
      while IFS= read -r target; do
        [[ -n "$target" ]] && resolved+=("$target")
      done < <(resolve_single_target "$sub_spec")
    done
  done

  if (( ${#resolved[@]} == 0 )); then
    return 1
  fi

  # Deduplicate preserving order
  local seen=() deduped=()
  local t s already
  for t in "${resolved[@]}"; do
    already=0
    if (( ${#seen[@]} > 0 )); then
      for s in "${seen[@]}"; do
        [[ "$s" == "$t" ]] && already=1 && break
      done
    fi
    if (( already == 0 )); then
      seen+=("$t")
      deduped+=("$t")
    fi
  done

  REQUESTED_TESTS=$(IFS=','; echo "${deduped[*]}")
}

harness_main() {
# Start timer for entire script execution
ORIGINAL_CLI_ARGS=("$@")
RUN_INVOCATION_ID="$(current_timestamp)-${ROOT_SHELL_PID}"
START_TIME=$(date +%s)
START_TIME_HUMAN=$(date "+%Y-%m-%d %H:%M:%S %Z")
log_time "run-xcode-tests start (${START_TIME_HUMAN}, run_id=${RUN_INVOCATION_ID})"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b)
      REQUESTED_BUILDS="$2"; shift 2;;
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
    --oslog-debug)
      REQUESTED_OSLOG_DEBUG=1; shift;;
    --scheme)
      SCHEME="$2"; shift 2;;
    --workspace)
      WORKSPACE="$2"; shift 2;;
    --sim)
      PREFERRED_SIM="$2"; shift 2;;
    --clear-ui-lock)
      REQUEST_CLEAR_UI_LOCK=1; shift;;
    --reap)
      REQUEST_REAP=1; shift;;
    --reap-dry-run)
      REQUEST_REAP_DRY_RUN=1; shift;;
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
      log_error "Deprecated action '$1'. Use -b/-c/-s flags instead."
      exit_with_summary 1;;
    *)
      # Positional arg: .swift file path or suite directory name (npm-style)
      REQUESTED_POSITIONAL_TARGETS+=("$1"); shift;;
  esac
done

# Resolve positional args (file paths / suite directories) to REQUESTED_TESTS
if (( ${#REQUESTED_POSITIONAL_TARGETS[@]} > 0 )); then
  if ! resolve_positional_targets; then
    log_warn "Positional args produced no resolvable test targets; running full suite"
    DEFAULT_PIPELINE=1
  else
    log_info "Resolved positional targets to: $REQUESTED_TESTS"
  fi
fi

if [[ $REQUESTED_OSLOG_DEBUG -eq 1 ]]; then
  export OS_ACTIVITY_DT_MODE=YES
  export OS_LOG_DEFAULT_LEVEL=debug
  log_info "OSLog debug enabled (OS_ACTIVITY_DT_MODE=YES, OS_LOG_DEFAULT_LEVEL=debug)"
fi

if [[ $REQUEST_CLEAR_UI_LOCK -eq 1 ]]; then
  if [[ -n "$REQUESTED_BUILDS" || -n "$REQUESTED_TESTS" || $REQUESTED_CLEAN -eq 1 || $REQUESTED_SYNTAX -eq 1 || $REQUEST_TESTPLAN -eq 1 || $REQUESTED_LINT -eq 1 || $REQUESTED_OSLOG_DEBUG -eq 1 || $SELF_CHECK -eq 1 ]]; then
    log_error "--clear-ui-lock must be used by itself"
    update_exit_status 1
    finalize_and_exit 1
  fi
  if clear_ui_test_lock; then
    finalize_and_exit 0
  fi
  finalize_and_exit 1
fi

if [[ $REQUEST_REAP_DRY_RUN -eq 1 ]]; then
  reap_orphaned_harness_processes 1
  finalize_and_exit 0
fi

if [[ $REQUEST_REAP -eq 1 ]]; then
  reap_orphaned_harness_processes 0
  finalize_and_exit 0
fi

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

if [[ $REQUESTED_SYNTAX -eq 0 && -z "$REQUESTED_BUILDS" && -z "$REQUESTED_TESTS" && $REQUEST_TESTPLAN -eq 0 && $REQUESTED_LINT -eq 0 && $REQUEST_CLEAR_UI_LOCK -eq 0 ]]; then
  DEFAULT_PIPELINE=1
else
  DEFAULT_PIPELINE=0
fi

UI_PARALLELISM=$(resolve_ui_parallelism)
if (( UI_PARALLELISM > 1 )); then
  if [[ -z "${ZPOD_DERIVED_DATA_PATH:-}" ]]; then
    UI_PARALLEL_SHARED_DERIVED_ROOT=$(resolve_ui_parallel_derived_root)
    export ZPOD_DERIVED_DATA_PATH="$UI_PARALLEL_SHARED_DERIVED_ROOT"
  else
    UI_PARALLEL_SHARED_DERIVED_ROOT="$ZPOD_DERIVED_DATA_PATH"
  fi
  if ! mkdir -p "$ZPOD_DERIVED_DATA_PATH"; then
    log_error "Failed to prepare shared derived data root: $ZPOD_DERIVED_DATA_PATH"
    finalize_and_exit "$UI_PARALLEL_SETUP_EXIT_CODE"
  fi
fi

echo "[DEBUG] REQUESTED_SYNTAX=$REQUESTED_SYNTAX REQUESTED_BUILDS='$REQUESTED_BUILDS' REQUESTED_TESTS='$REQUESTED_TESTS' REQUEST_TESTPLAN=$REQUEST_TESTPLAN REQUEST_TESTPLAN_SUITE='$REQUEST_TESTPLAN_SUITE' REQUESTED_LINT=$REQUESTED_LINT REQUEST_CLEAR_UI_LOCK=$REQUEST_CLEAR_UI_LOCK UI_PARALLELISM=$UI_PARALLELISM"

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
    local explicit_test_status=0
    if execute_phase "Test ${item}" "test" run_test_target "$item"; then
      explicit_test_status=0
    else
      explicit_test_status=$?
      if (( explicit_test_status == UI_LOCK_CONFLICT_EXIT_CODE || explicit_test_status == UI_PARALLEL_SETUP_EXIT_CODE )); then
        finalize_and_exit "$explicit_test_status"
      fi
    fi
    did_run_anything=1
  done
  release_ui_test_lock
fi

if [[ $REQUEST_TESTPLAN -eq 1 ]]; then
  execute_phase "Test plan ${REQUEST_TESTPLAN_SUITE:-default}" "testplan" run_testplan_check "$REQUEST_TESTPLAN_SUITE"
  did_run_anything=1
fi

if [[ $REQUESTED_LINT -eq 1 ]]; then
  execute_phase "Swift lint" "lint" run_swift_lint
  execute_phase "Sleep usage lint" "lint" run_sleep_lint
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
  unset ZPOD_TEST_WITHOUT_BUILDING || true
  finalize_and_exit "$EXIT_STATUS"
fi
execute_phase "Integration tests" "test" run_test_target "IntegrationTests"
local ui_suite_status=0
if execute_phase "UI tests" "test" run_ui_test_suites; then
  ui_suite_status=0
else
  ui_suite_status=$?
fi
release_ui_test_lock
if (( ui_suite_status == UI_LOCK_CONFLICT_EXIT_CODE || ui_suite_status == UI_PARALLEL_SETUP_EXIT_CODE )); then
  unset ZPOD_TEST_WITHOUT_BUILDING || true
  finalize_and_exit "$ui_suite_status"
fi
if (( ui_suite_status != 0 )); then
  log_warn "UI suite orchestration exited with status ${ui_suite_status}; continuing to lint"
  update_exit_status "$ui_suite_status"
fi
unset ZPOD_TEST_WITHOUT_BUILDING || true

execute_phase "Swift lint" "lint" run_swift_lint
execute_phase "Sleep usage lint" "lint" run_sleep_lint

finalize_and_exit "$EXIT_STATUS"
}
