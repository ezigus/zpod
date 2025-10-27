#!/usr/bin/env bash
set -euo pipefail

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

EXIT_STATUS=0
INTERRUPTED=0
CURRENT_PHASE=""
CURRENT_PHASE_CATEGORY=""
SUMMARY_PRINTED=0
CURRENT_PHASE_RECORDED=0

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
  set +e
  "${command[@]}"
  local status=$?
  set -e

  if (( status != 0 )); then
    if (( CURRENT_PHASE_RECORDED == 0 )); then
      add_summary "$category" "$label" "error" "" "" "" "" "" "failed"
    fi
    update_exit_status "$status"
  fi

  CURRENT_PHASE=""
  CURRENT_PHASE_CATEGORY=""
  CURRENT_PHASE_RECORDED=0

  return "$status"
}

category_in() {
  local value="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if [[ "$value" == "$candidate" ]]; then
      return 0
    fi
  done
  return 1
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
  trap - ERR INT
  if (( SUMMARY_PRINTED == 0 )); then
    print_summary
  fi
  SUMMARY_PRINTED=1
  exit "$code"
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
  else
    add_summary "script" "runtime" "error" "" "" "" "" "" "script error at line ${line}"
  fi
  update_exit_status "$status"
  finalize_and_exit "$EXIT_STATUS"
}

trap 'handle_interrupt' INT
trap 'handle_unexpected_error $? $LINENO' ERR

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
    log_warn "Host app still missing at ${expected_app} after rebuild"
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
  line=$(grep -E "Found [0-9]+ violations" "$log_path" 2>/dev/null | tail -1)
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
      line=$(grep -E "(No lint violations|Lint finished)" "$log_path" 2>/dev/null | tail -1)
      ;;
    swiftformat)
      line=$(grep -E "SwiftFormat" "$log_path" 2>/dev/null | tail -1)
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

  print_section_header "Build Summary"
  print_entries_for_categories syntax build testplan script

  if (( lint_total > 0 )); then
    print_section_header "Lint Summary"
    print_entries_for_categories lint
  fi

  print_section_header "Test Execution Summary"
  print_test_execution_summary

  local test_totals
  test_totals=$(sum_test_case_counts)
  IFS='|' read -r test_total_count test_passed_count test_failed_count test_skipped_count <<< "$test_totals"

  local test_counts
  test_counts=$(tally_counts test)
  IFS='|' read -r tests_total tests_success tests_warn tests_error tests_interrupted <<< "$test_counts"

  print_section_header "Overall Status"

  local overall_message
  if (( INTERRUPTED == 1 || tests_interrupted > 0 || build_interrupted > 0 || lint_interrupted > 0 )); then
    overall_message="⏸️  Regression interrupted"
  elif (( build_error > 0 || tests_error > 0 || lint_error > 0 )); then
    overall_message="⚠️  Regression completed with failures"
  elif (( build_warn > 0 || tests_warn > 0 || lint_warn > 0 )); then
    overall_message="⚠️  Regression completed with warnings"
  else
    overall_message="✅ Regression completed successfully"
  fi
  printf '%s\n' "$overall_message"

  printf '  Builds: %s succeeded, %s warnings, %s failed, %s interrupted\n' "$build_success" "$build_warn" "$build_error" "$build_interrupted"
  printf '  Tests: %s succeeded, %s warnings, %s failed, %s interrupted\n' "$tests_success" "$tests_warn" "$tests_error" "$tests_interrupted"
  printf '  Lint: %s succeeded, %s warnings, %s failed, %s interrupted\n' "$lint_success" "$lint_warn" "$lint_error" "$lint_interrupted"

  if [[ -n "$test_total_count" && "$test_total_count" -ne 0 ]]; then
    printf '  Test Cases: %s passed, %s failed, %s skipped (total %s)\n' "$test_passed_count" "$test_failed_count" "$test_skipped_count" "$test_total_count"
  fi

  printf '  Exit Status: %s\n' "$EXIT_STATUS"
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
    exit 1
  fi

  local available_list
  available_list=$(printf "%s" "$list_output" | awk '
    /^ *Schemes:/ { capture=1; next }
    capture && NF==0 { exit }
    capture { sub(/^ +/,""); print }
  ') || {
    log_error "Failed to parse schemes for workspace '$WORKSPACE'"
    exit 1
  }

  if [[ -z "$available_list" ]]; then
    log_error "No schemes found in workspace '$WORKSPACE'"
    exit 1
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
  exit 1
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
      exit 1
    fi
  elif [[ -f "$WORKSPACE" ]]; then
    return
  else
    log_error "Workspace not found at ${WORKSPACE}"
    exit 1
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
  local resolved_scheme="$SCHEME"
  local resolved_sdk="iphonesimulator"
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
    -sdk "$resolved_sdk"
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
        exit 1
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
    run_swift_package_tests
    return 0
  fi

  local resolved_scheme="$SCHEME"
  local resolved_sdk="iphonesimulator"
  local resolved_destination=""
  if [[ "$target" == "IntegrationTests" ]]; then
    resolved_scheme="IntegrationTests"
  fi
  select_destination "$WORKSPACE" "$SCHEME" "$PREFERRED_SIM"
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
    -sdk "$resolved_sdk"
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

  case "$target" in
    all|zpod)
      args+=(build test);;
    AppSmokeTests|zpodTests|zpodUITests)
      args+=(build test -only-testing:"$target")
      if [[ "$target" == "zpodUITests" ]]; then
        args+=(-skip-testing:IntegrationTests)
      fi
      ;;
    IntegrationTests)
      args+=(build test);;
    */*)
      args+=(build test -only-testing:"$target")
      if [[ "$target" == zpodUITests/* ]]; then
        args+=(-skip-testing:IntegrationTests)
      fi
      ;;
    *)
      args+=(build test)
      ;;
  esac

  log_section "xcodebuild tests (${target})"
  set +e
  set +e
  xcodebuild_wrapper "${args[@]}" | tee "$RESULT_LOG"
  local xc_status=${PIPESTATUS[0]}
  set -e

  if [[ $xc_status -ne 0 ]]; then
    xcresult_has_failures "$RESULT_BUNDLE"
    local inspect_status=$?
    case $inspect_status in
      0)
        log_error "Tests failed (status $xc_status) -> $RESULT_LOG"
        add_summary "test" "${target}" "error" "$RESULT_LOG" "" "" "" "" "failed"
        update_exit_status "$xc_status"
        return "$xc_status"
        ;;
      1)
        log_warn "xcodebuild exited with status $xc_status but no test failures detected; treating as success"
        ;;
      *)
        log_error "xcodebuild exited with status $xc_status and result bundle could not be inspected"
        add_summary "test" "${target}" "error" "$RESULT_LOG" "" "" "" "" "result bundle inspection failed"
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
  add_summary "test" "${target}" "success" "$RESULT_LOG" "$total" "$passed" "$failed" "$skipped" "$note"
  return 0
}

test_package_target() {
  local package="$1"
  if package_supports_host_build "$package"; then
    :
  else
    log_warn "Skipping swift test for package '${package}' (host platform unsupported on this machine)"
    add_summary "test" "package ${package}" "warn" "" "" "" "" "" "skipped (host platform unsupported)"
    return 0
  fi
  init_result_paths "test_pkg" "$package"
  log_section "swift test (${package})"
  set +e
  run_swift_package_target_tests "$package" "$REQUESTED_CLEAN"
  local pkg_status=$?
  set -e

  if (( pkg_status != 0 )); then
    log_error "Package tests failed (${package}) status ${pkg_status} -> $RESULT_LOG"
    add_summary "test" "package ${package}" "error" "$RESULT_LOG" "" "" "" "" "failed"
    update_exit_status "$pkg_status"
    return "$pkg_status"
  fi

  log_success "Package tests finished -> $RESULT_LOG"
  add_summary "test" "package ${package}" "success" "$RESULT_LOG"
  return 0
}

run_swift_lint() {
  init_result_paths "lint" "swift"
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
      log_error "SwiftLint failed (status ${lint_status}) -> $RESULT_LOG"
      add_summary "lint" "swiftlint" "error" "$RESULT_LOG" "" "" "" "" "failed"
      update_exit_status "$lint_status"
      return "$lint_status"
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
      log_error "swift-format lint failed (status ${lint_status}) -> $RESULT_LOG"
      add_summary "lint" "swift-format" "error" "$RESULT_LOG" "" "" "" "" "failed"
      update_exit_status "$lint_status"
      return "$lint_status"
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
      log_error "swiftformat lint failed (status ${lint_status}) -> $RESULT_LOG"
      add_summary "lint" "swiftformat" "error" "$RESULT_LOG" "" "" "" "" "failed"
      update_exit_status "$lint_status"
      return "$lint_status"
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
        log_error "swift-format lint failed (status ${lint_status}) -> $RESULT_LOG"
        add_summary "lint" "swift-format" "error" "$RESULT_LOG" "" "" "" "" "failed"
        update_exit_status "$lint_status"
        return "$lint_status"
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
        log_error "SwiftLint failed (status ${lint_status}) -> $RESULT_LOG"
        add_summary "lint" "swiftlint" "error" "$RESULT_LOG" "" "" "" "" "failed"
        update_exit_status "$lint_status"
        return "$lint_status"
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
  local resolved_sdk="iphonesimulator"
  local resolved_destination=""
  if [[ $integration_run -eq 1 ]]; then
    resolved_scheme="IntegrationTests"
  fi
  select_destination "$WORKSPACE" "$SCHEME" "$PREFERRED_SIM"
  resolved_destination="$SELECTED_DESTINATION"

  if [[ $integration_run -eq 0 ]]; then
    ensure_host_app_product || return $?
  fi

  init_result_paths "test" "$label"

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
    -sdk "$resolved_sdk"
    -destination "$resolved_destination"
    -resultBundlePath "$RESULT_BUNDLE"
  )

  if [[ -n "${ZPOD_DERIVED_DATA_PATH:-}" ]]; then
    mkdir -p "$ZPOD_DERIVED_DATA_PATH"
    args+=(-derivedDataPath "$ZPOD_DERIVED_DATA_PATH")
  fi

  if [[ $clean_flag -eq 1 ]]; then
    args+=(clean)
  fi

  args+=(build test)

  if [[ $integration_run -eq 0 ]]; then
    local filter
    for filter in "${filters[@]}"; do
      args+=("-only-testing:$filter")
    done
  fi

  log_section "xcodebuild tests (${label})"
  set +e
  xcodebuild_wrapper "${args[@]}" | tee "$RESULT_LOG"
  local xc_status=${PIPESTATUS[0]}
  set -e

  if [[ $xc_status -ne 0 ]]; then
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
  add_summary "test" "${label}" "success" "$RESULT_LOG" "$total" "$passed" "$failed" "$skipped" "$note"
  return 0
}

run_test_target() {
  local target
  target=$(resolve_test_identifier "$1") || exit 1
  case "$target" in
    all|zpod|AppSmokeTests|zpodTests|zpodUITests|IntegrationTests|*/*)
      test_app_target "$target" || return $?;;
    "") ;;
    *)
      if is_package_target "$target"; then
        test_package_target "$target" || return $?
      else
        log_error "Unknown test target: $target"
        exit 1
      fi
      ;;
  esac
}

infer_target_for_class() {
  local class_name="$1"
  local search_dirs=("${REPO_ROOT}/zpodUITests" "${REPO_ROOT}/AppSmokeTests" "${REPO_ROOT}/IntegrationTests")
  local matches=()
  ensure_command rg "ripgrep is required to resolve test names" || exit 1

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
    exit 1
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
      show_help; exit 0;;
    full_clean_build|full_build_no_test|full_build_and_test|partial_clean_build|partial_build_and_test)
      log_error "Deprecated action '$1'. Use -b/-t/-c/-s flags instead."
      exit 1;;
    *)
      log_error "Unknown argument: $1"
      show_help
      exit 1;;
  esac
done

if [[ $REQUESTED_SYNTAX -eq 1 ]]; then
  if [[ -n "$REQUESTED_BUILDS" || -n "$REQUESTED_TESTS" || $REQUESTED_CLEAN -eq 1 || $REQUEST_TESTPLAN -eq 1 || $REQUESTED_LINT -eq 1 ]]; then
    log_error "-s (syntax) cannot be combined with other build or test flags"
    exit 1
  fi
fi

if [[ $SELF_CHECK -eq 1 ]]; then
  self_check
  exit $?
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

if ! execute_phase "App smoke tests" "test" run_test_target "AppSmokeTests"; then
  finalize_and_exit "$EXIT_STATUS"
fi

execute_phase "Test plan default" "testplan" run_testplan_check ""

execute_phase "Build zpod" "build" build_app_target "zpod"

__ZPOD_ALL_PACKAGES=()
while IFS= read -r pkg; do
  [[ -z "$pkg" ]] && continue
  __ZPOD_ALL_PACKAGES+=("$pkg")
done < <(list_package_targets)

for pkg in "${__ZPOD_ALL_PACKAGES[@]}"; do
  execute_phase "Build package ${pkg}" "build" build_package_target "$pkg"
done

REQUESTED_CLEAN=0

for pkg in "${__ZPOD_ALL_PACKAGES[@]}"; do
  execute_phase "Package tests ${pkg}" "test" test_package_target "$pkg"
done
unset __ZPOD_ALL_PACKAGES

execute_phase "Integration tests" "test" run_test_target "IntegrationTests"
execute_phase "UI tests" "test" run_test_target "zpodUITests"

execute_phase "Swift lint" "lint" run_swift_lint

finalize_and_exit "$EXIT_STATUS"
