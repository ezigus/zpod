#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_ROOT}/.." && pwd)"

# TODO: [Issue #02.1.3.2] Consolidate invocation flags (add syntax flag) and update AGENTS.md guidance

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

SCHEME="zpod"
WORKSPACE="${REPO_ROOT}/zpod.xcworkspace"
PREFERRED_SIM="iPhone 16"
REQUESTED_CLEAN=0
REQUESTED_BUILDS=""
REQUESTED_TESTS=""
REQUESTED_SYNTAX=0
LEGACY_TEST_SPEC="all"
SELF_CHECK=0

show_help() {
  cat <<EOF
Usage: scripts/run-xcode-tests.sh [OPTIONS]

Options:
  -b <targets>      Comma-separated list of build targets (e.g. zpod,CoreModels)
  -t <tests>        Comma-separated list of test targets (zpodTests,zpodUITests,PackageName)
  -c                Clean before running build/test
  -s                Run Swift syntax verification via dev-build-enhanced.sh
  --scheme <name>   Xcode scheme to use (default: zpod)
  --workspace <ws>  Path to workspace (default: zpod.xcworkspace)
  --sim <device>    Preferred simulator name (default: "iPhone 16")
  --tests <class>   Legacy single test/class selection
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

run_syntax_check() {
  local syntax_script="${REPO_ROOT}/scripts/dev-build-enhanced.sh"
  if [[ ! -x "$syntax_script" ]]; then
    log_error "Syntax helper not found at ${syntax_script}"
    exit 1
  fi

  init_result_paths "syntax" "swift"
  log_section "Syntax check"
  (
    cd "$REPO_ROOT"
    "$syntax_script" syntax
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
  init_result_paths "build_pkg" "$package"
  log_section "swift build (${package})"
  build_swift_package "$package" "$REQUESTED_CLEAN" | tee "$RESULT_LOG"
  log_success "Package build finished -> $RESULT_LOG"
}

run_build_target() {
  local target="$1"
  case "$target" in
    all|zpod)
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
  init_result_paths "test_pkg" "$package"
  log_section "swift test (${package})"
  run_swift_package_target_tests "$package" "$REQUESTED_CLEAN" | tee "$RESULT_LOG"
  log_success "Package tests finished -> $RESULT_LOG"
}

run_test_target() {
  local target="$1"
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
    --scheme)
      SCHEME="$2"; shift 2;;
    --workspace)
      WORKSPACE="$2"; shift 2;;
    --sim)
      PREFERRED_SIM="$2"; shift 2;;
    --tests)
      LEGACY_TEST_SPEC="$2"; shift 2;;
    --self-check)
      SELF_CHECK=1; shift;;
    --help|-h)
      show_help; exit 0;;
    full_clean_build|full_build_no_test|full_build_and_test|partial_clean_build|partial_build_and_test)
      log_error "Deprecated action '$1'. Use -b/-t/-c/-s flags instead."
      exit 1;;
    *)
      if [[ "$LEGACY_TEST_SPEC" == "all" ]]; then
        LEGACY_TEST_SPEC="$1"; shift
      else
        log_error "Unknown argument: $1"
        show_help
        exit 1
      fi;;
  esac
done

if [[ $SELF_CHECK -eq 1 ]]; then
  self_check
  exit $?
fi

echo "[DEBUG] REQUESTED_SYNTAX=$REQUESTED_SYNTAX REQUESTED_BUILDS='$REQUESTED_BUILDS' REQUESTED_TESTS='$REQUESTED_TESTS' LEGACY_TEST_SPEC='$LEGACY_TEST_SPEC'"

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

if [[ "$LEGACY_TEST_SPEC" != "all" ]]; then
  run_test_target "$LEGACY_TEST_SPEC"
  did_run_anything=1
fi

if [[ $did_run_anything -eq 1 ]]; then
  log_success "Requested operations complete"
  exit 0
fi

run_syntax_check
build_app_target "zpod"
test_app_target "zpod"
log_success "Default build & test complete"
