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

SCHEME="zpod"
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
}

build_app_target() {
  local target_label="$1"
  require_xcodebuild || return 1
  require_workspace
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
}

build_package_target() {
  local package="$1"
  if package_supports_host_build "$package"; then
    :
  else
    log_warn "Skipping swift build for package '${package}' (host platform unsupported; built via workspace targets)"
    return 0
  fi
  init_result_paths "build_pkg" "$package"
  log_section "swift build (${package})"
  build_swift_package "$package" "$REQUESTED_CLEAN" | tee "$RESULT_LOG"
  log_success "Package build finished -> $RESULT_LOG"
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
  if ! command_exists xcodebuild; then
    log_warn "xcodebuild unavailable, running package fallback"
    init_result_paths "test_fallback" "$target"
    run_swift_package_tests
    return 0
  fi

  init_result_paths "test" "$target"
  select_destination "$WORKSPACE" "$SCHEME" "$PREFERRED_SIM"

  if [[ $DESTINATION_IS_GENERIC -eq 1 ]]; then
    log_warn "Generic simulator destination detected; running build only and skipping UI/unit tests"
    build_app_target "$target"
    log_warn "Swift Package tests skipped due to simulator unavailability"
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
  xcodebuild_wrapper "${args[@]}" | tee "$RESULT_LOG"
  log_success "Tests finished -> $RESULT_LOG"
}

test_package_target() {
  local package="$1"
  if package_supports_host_build "$package"; then
    :
  else
    log_warn "Skipping swift test for package '${package}' (host platform unsupported on this machine)"
    return 0
  fi
  init_result_paths "test_pkg" "$package"
  log_section "swift test (${package})"
  run_swift_package_target_tests "$package" "$REQUESTED_CLEAN" | tee "$RESULT_LOG"
  log_success "Package tests finished -> $RESULT_LOG"
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
    return 0
  fi

  if command_exists swift-format; then
    (
      cd "$REPO_ROOT"
      swift-format lint --recursive .
    ) | tee "$RESULT_LOG"
    log_success "swift-format lint finished -> $RESULT_LOG"
    return 0
  fi

  if command_exists swiftformat; then
    (
      cd "$REPO_ROOT"
      swiftformat --lint .
    ) | tee "$RESULT_LOG"
    log_success "swiftformat lint finished -> $RESULT_LOG"
    return 0
  fi

  log_warn "No Swift lint tool available (swiftlint/swift-format/swiftformat)."

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
  return 1
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
  verify_testplan_coverage "$REQUEST_TESTPLAN_SUITE"
  case $? in
    0)
      ;;
    2)
      log_warn "Test plan coverage incomplete"
      exit 2
      ;;
    *)
      log_error "Failed to verify test plan coverage"
      exit 1
      ;;
  esac
  did_run_anything=1
fi

if [[ $REQUESTED_LINT -eq 1 ]]; then
  run_swift_lint
  did_run_anything=1
fi

if [[ $did_run_anything -eq 1 ]]; then
  log_success "Requested operations complete"
  exit 0
fi

REQUESTED_CLEAN=1
run_syntax_check

verify_testplan_coverage ""
case $? in
  0)
    ;;
  2)
    log_warn "Test plan coverage incomplete"
    exit 2
    ;;
  *)
    log_error "Failed to verify test plan coverage"
    exit 1
    ;;
esac

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
log_success "Default build, test, and lint complete"
