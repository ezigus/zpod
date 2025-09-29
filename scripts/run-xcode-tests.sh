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
PREFERRED_SIM="iPhone 16"
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
  SUMMARY_ITEMS+=("${category}|${name}|${status}|${log_path}|${total}|${passed}|${failed}|${skipped}|${note}")
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

print_summary() {
  if [[ ${#SUMMARY_ITEMS[@]} -eq 0 ]]; then
    return
  fi
  log_section "Summary"
  local entry
  for entry in "${SUMMARY_ITEMS[@]}"; do
    IFS='|' read -r category name status log_path total passed failed skipped note <<< "$entry"

    local category_label
    case "$category" in
      build) category_label="Build" ;;
      lint) category_label="Lint" ;;
      syntax) category_label="Syntax" ;;
      test) category_label="Tests" ;;
      testplan) category_label="Test Plan" ;;
      *) category_label="$category" ;;
    esac

    local prefix="${category_label}: ${name}"
    local detail="${prefix}"
    local -a extra_parts=()
    if [[ "$category" == "test" && -n "$total" ]]; then
      extra_parts+=("${total} total (passed ${passed}, failed ${failed}, skipped ${skipped})")
    fi
    if [[ -n "$note" ]]; then
      extra_parts+=("${note}")
    fi
    if [[ -n "$log_path" ]]; then
      extra_parts+=("log: ${log_path}")
    fi
    if [[ ${#extra_parts[@]} -gt 0 ]]; then
      detail="${prefix} – ${extra_parts[0]}"
      local idx=1
      while [[ $idx -lt ${#extra_parts[@]} ]]; do
        detail+="; ${extra_parts[$idx]}"
        ((idx++))
      done
    fi

    case "$status" in
      success)
        log_success "$detail"
        ;;
      warn)
        log_warn "$detail"
        ;;
      error|fail|failed)
        log_error "$detail"
        ;;
      *)
        log_info "$detail"
        ;;
    esac
  done
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
  -p [suite]        Verify test plan coverage (optional suite: default, zpodTests, zpodUITests, IntegrationTests)
  --scheme <name>   Xcode scheme to use (default: "zpod (zpod project)")
  --workspace <ws>  Path to workspace (default: zpod.xcworkspace)
  --sim <device>    Preferred simulator name (default: "iPhone 16")
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
  REQUESTED_TESTS="zpodTests"
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
  if grep -q ".macOS" "$manifest"; then
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
  (
    cd "$REPO_ROOT"
    dev_build_enhanced_syntax
  ) | tee "$RESULT_LOG"

  log_success "Syntax check finished -> $RESULT_LOG"
  local note=""
  note=$(summarize_syntax_log "$RESULT_LOG")
  add_summary "syntax" "Swift syntax" "success" "$RESULT_LOG" "" "" "" "" "$note"
}

build_app_target() {
  local target_label="$1"
  require_xcodebuild || return 1
  require_workspace
  ensure_scheme_available
  init_result_paths "build" "$target_label"
  select_destination "$WORKSPACE" "$SCHEME" "$PREFERRED_SIM"

  local -a args=(
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -sdk iphonesimulator
    -destination "$SELECTED_DESTINATION"
    -resultBundlePath "$RESULT_BUNDLE"
  )
  if [[ $REQUESTED_CLEAN -eq 1 ]]; then
    args+=(clean)
  fi
  args+=(build)

  log_section "xcodebuild ${target_label}"
  xcodebuild_wrapper "${args[@]}" | tee "$RESULT_LOG"
  log_success "Build finished -> $RESULT_LOG"
  local note=""
  note=$(collect_build_summary_info "$RESULT_LOG")
  add_summary "build" "${target_label}" "success" "$RESULT_LOG" "" "" "" "" "$note"
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
  build_swift_package "$package" "$REQUESTED_CLEAN" | tee "$RESULT_LOG"
  log_success "Package build finished -> $RESULT_LOG"
  local note=""
  note=$(collect_build_summary_info "$RESULT_LOG")
  add_summary "build" "package ${package}" "success" "$RESULT_LOG" "" "" "" "" "$note"
}

run_build_target() {
  local target="$1"
  case "$target" in
    all)
      build_app_target "zpod"
      local pkg
      while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        build_package_target "$pkg"
      done < <(list_package_targets)
      ;;
    zpod)
      build_app_target "$target";;
    "") ;;
    *)
      if is_package_target "$target"; then
        build_package_target "$target"
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

  select_destination "$WORKSPACE" "$SCHEME" "$PREFERRED_SIM"

  if [[ "$target" == "zpod" ]]; then
    local clean_flag=$REQUESTED_CLEAN
    run_filtered_xcode_tests "${target}-unit" "$clean_flag" "zpodTests"
    run_filtered_xcode_tests "${target}-ui" 0 "zpodUITests"
    return
  fi

  init_result_paths "test" "$target"
  if [[ $DESTINATION_IS_GENERIC -eq 1 ]]; then
    log_warn "Generic simulator destination detected; running build only and skipping UI/unit tests"
    build_app_target "$target"
    log_warn "Swift Package tests skipped due to simulator unavailability"
    add_summary "test" "${target}" "warn" "" "" "" "" "" "skipped (generic simulator destination)"
    return 0
  fi

  local -a args=(
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -sdk iphonesimulator
    -destination "$SELECTED_DESTINATION"
    -resultBundlePath "$RESULT_BUNDLE"
  )
  if [[ $REQUESTED_CLEAN -eq 1 ]]; then
    args+=(clean)
  fi

  case "$target" in
    all|zpod)
      args+=(build test);;
    zpodTests|zpodUITests|IntegrationTests)
      args+=(build test -only-testing:"$target");;
    */*)
      args+=(build test -only-testing:"$target");;
    *)
      args+=(build test)
      ;;
  esac

  log_section "xcodebuild tests (${target})"
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
        exit $xc_status
        ;;
      1)
        log_warn "xcodebuild exited with status $xc_status but no test failures detected; treating as success"
        ;;
      *)
        log_error "xcodebuild exited with status $xc_status and result bundle could not be inspected"
        exit $xc_status
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
  run_swift_package_target_tests "$package" "$REQUESTED_CLEAN" | tee "$RESULT_LOG"
  log_success "Package tests finished -> $RESULT_LOG"
  add_summary "test" "package ${package}" "success" "$RESULT_LOG"
}

run_swift_lint() {
  init_result_paths "lint" "swift"
  log_section "Swift lint"

  if command_exists swiftlint; then
    (
      cd "$REPO_ROOT"
      swiftlint lint
    ) | tee "$RESULT_LOG"
    log_success "SwiftLint finished -> $RESULT_LOG"
    local note=""
    note=$(summarize_lint_log "swiftlint" "$RESULT_LOG")
    add_summary "lint" "swiftlint" "success" "$RESULT_LOG" "" "" "" "" "$note"
    return 0
  fi

  if command_exists swift-format; then
    (
      cd "$REPO_ROOT"
      swift-format lint --recursive .
    ) | tee "$RESULT_LOG"
    log_success "swift-format lint finished -> $RESULT_LOG"
    local note=""
    note=$(summarize_lint_log "swift-format" "$RESULT_LOG")
    add_summary "lint" "swift-format" "success" "$RESULT_LOG" "" "" "" "" "$note"
    return 0
  fi

  if command_exists swiftformat; then
    (
      cd "$REPO_ROOT"
      swiftformat --lint .
    ) | tee "$RESULT_LOG"
    log_success "swiftformat lint finished -> $RESULT_LOG"
    local note=""
    note=$(summarize_lint_log "swiftformat" "$RESULT_LOG")
    add_summary "lint" "swiftformat" "success" "$RESULT_LOG" "" "" "" "" "$note"
    return 0
  fi

  if ensure_swift_format_tool; then
    if command_exists swift-format; then
      (
        cd "$REPO_ROOT"
        swift-format lint --recursive .
      ) | tee "$RESULT_LOG"
      log_success "swift-format lint finished -> $RESULT_LOG"
      local note=""
      note=$(summarize_lint_log "swift-format" "$RESULT_LOG")
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
      (
        cd "$REPO_ROOT"
        swiftlint lint
      ) | tee "$RESULT_LOG"
      log_success "SwiftLint finished -> $RESULT_LOG"
      local note=""
      note=$(summarize_lint_log "swiftlint" "$RESULT_LOG")
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
  select_destination "$WORKSPACE" "$SCHEME" "$PREFERRED_SIM"

  init_result_paths "test" "$label"

  local -a args=(
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -sdk iphonesimulator
    -destination "$SELECTED_DESTINATION"
    -resultBundlePath "$RESULT_BUNDLE"
  )

  if [[ $clean_flag -eq 1 ]]; then
    args+=(clean)
  fi

  args+=(build test)

  local filter
  for filter in "${filters[@]}"; do
    args+=("-only-testing:$filter")
  done

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
        exit $xc_status
        ;;
      1)
        log_warn "xcodebuild exited with status $xc_status for ${label} but no test failures detected; treating as success"
        ;;
      *)
        log_error "xcodebuild exited with status $xc_status for ${label} and result bundle could not be inspected"
        exit $xc_status
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
}

run_test_target() {
  local target
  target=$(resolve_test_identifier "$1") || exit 1
  case "$target" in
    all|zpod|zpodTests|zpodUITests|IntegrationTests|*/*)
      test_app_target "$target";;
    "") ;;
    *)
      if is_package_target "$target"; then
        test_package_target "$target"
      else
        log_error "Unknown test target: $target"
        exit 1
      fi
      ;;
  esac
}

infer_target_for_class() {
  local class_name="$1"
  local search_dirs=("${REPO_ROOT}/zpodUITests" "${REPO_ROOT}/zpodTests" "${REPO_ROOT}/IntegrationTests")
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
    */zpodTests/*) echo "zpodTests";;
    */IntegrationTests/*) echo "IntegrationTests";;
    *) return 1;;
  esac
}

resolve_test_identifier() {
  local spec="$1"
  [[ -z "$spec" ]] && { log_error "Empty test identifier"; return 1; }

  local known_targets=(all zpod zpodTests zpodUITests IntegrationTests)
  local candidate
  for candidate in "${known_targets[@]}"; do
    if [[ "$spec" == "$candidate" ]]; then
      echo "$spec"
      return 0
    fi
  done

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
  build_app_target "zpod"
}

full_build_no_test() {
  build_app_target "zpod"
}

full_build_and_test() {
  REQUESTED_CLEAN=1
  build_app_target "zpod"
  test_app_target "zpod"
}

partial_clean_build() {
  local module="$1"
  REQUESTED_CLEAN=1
  run_build_target "$module"
}

partial_build_and_test() {
  local module="$1"
  run_build_target "$module"
  run_test_target "$module"
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
  run_syntax_check
  did_run_anything=1
fi

if [[ -n "$REQUESTED_BUILDS" ]]; then
  split_csv "$REQUESTED_BUILDS"
  for item in "${__ZPOD_SPLIT_RESULT[@]}"; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    run_build_target "$item"
    did_run_anything=1
  done
fi

if [[ -n "$REQUESTED_TESTS" ]]; then
  split_csv "$REQUESTED_TESTS"
  for item in "${__ZPOD_SPLIT_RESULT[@]}"; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    run_test_target "$item"
    did_run_anything=1
  done
fi

if [[ $REQUEST_TESTPLAN -eq 1 ]]; then
  if run_testplan_check "$REQUEST_TESTPLAN_SUITE"; then
    :
  else
    status=$?
    case $status in
      2)
        log_warn "Test plan coverage incomplete"
        print_summary
        exit 2
        ;;
      *)
        log_error "Failed to verify test plan coverage"
        print_summary
        exit 1
        ;;
    esac
  fi
  did_run_anything=1
fi

if [[ $REQUESTED_LINT -eq 1 ]]; then
  run_swift_lint
  did_run_anything=1
fi

if [[ $did_run_anything -eq 1 ]]; then
  print_summary
  exit 0
fi

REQUESTED_CLEAN=1
run_syntax_check

if run_testplan_check ""; then
  :
else
  status=$?
  case $status in
    2)
      log_warn "Test plan coverage incomplete"
      print_summary
      exit 2
      ;;
    *)
      log_error "Failed to verify test plan coverage"
      print_summary
      exit 1
      ;;
  esac
fi

run_build_target "all"
REQUESTED_CLEAN=0

if mapfile -t __ZPOD_ALL_PACKAGES < <(list_package_targets); then
  for pkg in "${__ZPOD_ALL_PACKAGES[@]}"; do
    run_test_target "$pkg"
  done
  unset __ZPOD_ALL_PACKAGES
fi

run_test_target "zpod"
run_swift_lint
print_summary
