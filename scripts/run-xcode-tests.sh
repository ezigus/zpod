#!/usr/bin/env bash
set -euo pipefail

# Prevent user shell aliases or environment options from breaking grep behavior
# (some interactive shells set `alias grep='grep --directories=skip'` or similar)
if alias grep >/dev/null 2>&1; then
  unalias grep || true
fi
unset GREP_OPTIONS 2>/dev/null || true
export LC_ALL=C

# Use explicit system tool paths to avoid user aliases or unexpected environment flags
GREP=/usr/bin/grep
SED=/usr/bin/sed
SORT=/usr/bin/sort
HEAD=/usr/bin/head
XCRUN=/usr/bin/xcrun
UNIQ=/usr/bin/uniq

# Default values (restored from backup)
SCHEME="zpod"
WORKSPACE="zpod.xcworkspace"
PREFERRED_SIM="iPhone 16"
REQUESTED_CLEAN=0
REQUESTED_BUILDS=""
REQUESTED_TESTS=""
TESTS="all"

# Print help menu (restored)
print_help() {
  cat <<EOF
Usage: $0 [OPTIONS] [ACTION] [MODULE]

Run Xcode tests or perform builds for the zPod project.

Options:
  -b <builds>           Comma separated list of build targets (e.g. zpod,CoreModels)
  -t <tests>            Comma separated list of test targets/tests (e.g. all,zpodTests,PackageName)
  -c                    Clean requested before build/test
  --scheme, -s <scheme> Xcode scheme to use (default: zpod)
  --workspace, -w <workspace> Xcode workspace file (default: zpod.xcworkspace)
  --sim, -d <simulator> Simulator device name (default: "iPhone 16")
  --tests <tests>       Legacy long-form tests argument (same as -t)
  --help, -h            Show this help menu and exit

Actions:
  full_clean_build
  full_build_no_test
  full_build_and_test
  partial_clean_build <ModuleName>
  partial_build_and_test <ModuleName>

Examples:
  $0                          # Full build and test using defaults
  $0 -b zpod,CoreModels -t zpodTests  # Build app and package then run tests
  $0 full_build_no_test        # Run explicit action
EOF
}

# Setup result bundle and log paths
setup_result_files() {
  local op="${1:-}" ; shift || true
  local target="${1:-}"
  mkdir -p TestResults
  RESULT_STAMP="$(date +%Y%m%d_%H%M%S)"
  local name="${op}"
  if [[ -n "${target:-}" ]]; then
    name+="_${target// /-}"
  fi
  RESULT_BUNDLE="TestResults/TestResults_${RESULT_STAMP}_${name}.xcresult"
  RESULT_LOG="TestResults/TestResults_${RESULT_STAMP}_${name}.log"
}

# Run swift package tests for all packages (fallback)
run_all_package_tests() {
  echo "🔁 Running Swift Package tests for all Packages/* (fallback)"
  local found=0
  for pkg in Packages/*; do
    if [[ -d "$pkg" ]]; then
      found=1
      pushd "$pkg" >/dev/null
      echo "-> swift test (package: $(basename "$pkg"))"
      set -x
      swift test | tee "../../${RESULT_LOG}"
      set +x
      popd >/dev/null
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    echo "ℹ️  No Packages/ found to run swift test against"
  fi
}

# Try to select a simulator using simctl (more robust than parsing xcodebuild output)
get_simulator_via_simctl() {
  # Requires xcrun simctl; returns 0 and sets SELECTED_DEST if found, else returns 1
  if ! command -v "$XCRUN" >/dev/null 2>&1; then
    return 1
  fi

  # Use simctl to list available devices and runtimes
  local simctl_json
  set +e
  simctl_json="$($XCRUN simctl list devices --json 2>/dev/null || true)"
  set -e
  if [[ -z "$simctl_json" ]]; then
    return 1
  fi

  # Try to find a device matching the preferred name and an iOS runtime
  # We use simple string parsing to avoid requiring jq
  local pref="$PREFERRED_SIM"
  # Look for lines like: "name" : "iPhone 16"
  local candidate_name=""
  local candidate_runtime=""
  while IFS= read -r line; do
    if echo "$line" | $GREP -q '"name"'; then
      name_line="$line"
      name_value=$(echo "$name_line" | $SED -En 's/.*"name"\s*:\s*"([^"]+)".*/\1/p')
    fi
    if echo "$line" | $GREP -q '"runtime"'; then
      runtime_line="$line"
      runtime_value=$(echo "$runtime_line" | $SED -En 's/.*"runtime"\s*:\s*"([^"]+)".*/\1/p')
    fi
    if echo "$line" | $GREP -q '"isAvailable"'; then
      avail_line="$line"
      is_avail=$(echo "$avail_line" | $SED -En 's/.*"isAvailable"\s*:\s*(true|false).*/\1/p')
      if [[ "$is_avail" == "true" && -n "$name_value" && -n "$runtime_value" ]]; then
        # runtime looks like com.apple.CoreSimulator.SimRuntime.iOS-18-0
        os_version=$(echo "$runtime_value" | $SED -En 's/.*iOS-([0-9]+)(-[0-9]+)*/\1/p')
        if [[ -z "$os_version" ]]; then
          os_version="18.0"
        else
          os_version="$os_version.0"
        fi
        if [[ "$name_value" == "$pref" ]]; then
          candidate_name="$name_value"
          candidate_runtime="$os_version"
          break
        fi
        # reset temporary values
        name_value=""
        runtime_value=""
      fi
    fi
  done <<< "$(echo "$simctl_json" | tr ',' '\n')"

  if [[ -n "$candidate_name" && -n "$candidate_runtime" ]]; then
    SELECTED_DEST="platform=iOS Simulator,name=${candidate_name},OS=${candidate_runtime}"
    DEST_IS_GENERIC=0
    echo "Using simctl-selected destination: ${SELECTED_DEST}"
    return 0
  fi

  return 1
}

# Device selection logic
select_simulator() {
  local workspace="$1"
  local scheme="$2"
  DEST_IS_GENERIC=0
  SELECTED_DEST=""

  echo "Attempting to select simulator via simctl (preferred)..."
  if get_simulator_via_simctl; then
    return 0
  fi

  echo "Listing destinations for scheme '${scheme}':"
  destinations_output="$(xcodebuild -workspace "${workspace}" -scheme "${scheme}" -showdestinations | cat || true)"
  echo "${destinations_output}"

  local fallback_sims=(
    "${PREFERRED_SIM}"
    "iPhone 16 Pro"
    "iPhone 16 Plus"
    "iPhone 16 Pro Max"
  )

  # Pre-filter to iOS Simulator lines and prefer arm64 entries when available
  local sim_lines
  sim_lines="$(echo "${destinations_output}" | ${GREP} "platform:iOS Simulator" || true)"

  # Early fallback: if only placeholder is visible, use generic platform destination
  if echo "${sim_lines}" | ${GREP} -q "DVTiOSDeviceSimulatorPlaceholder\|name:Any iOS Simulator Device"; then
    if ! echo "${sim_lines}" | ${GREP} -q "OS:"; then
      echo "Using generic iOS Simulator destination (no concrete simulators listed by xcodebuild)."
      SELECTED_DEST="generic/platform=iOS Simulator"
      DEST_IS_GENERIC=1
      echo "Using destination: ${SELECTED_DEST}"
      return 0
    fi
  fi

  # Extract all available iOS versions from simulators
  available_ios_versions="$(echo "${sim_lines}" | ${SED} -En 's/.*OS:([0-9]+(\.[0-9]+)*).*/\1/p' | ${SORT} -V -r | ${UNIQ})"
  echo "Available iOS versions: $(echo "$available_ios_versions" | tr '\n' ' ')"

  local selected_name=""
  local selected_os=""

  # Try each iOS version starting with the latest, with exact name matching
  for ios_version in $available_ios_versions; do
    echo "Trying iOS version: $ios_version"

    for sim_name in "${fallback_sims[@]}"; do
      name_trimmed="$(echo "$sim_name" | ${SED} 's/^ *//;s/ *$//')"
      line="$(echo "${sim_lines}" | ${GREP} -E "OS:${ios_version}" | ${GREP} -E "name:${name_trimmed}(,| })" | ${HEAD} -n1 || true)"
      if [[ -n "${line}" ]]; then
        os="$(echo "$line" | ${SED} -En 's/.*OS:([0-9]+(\.[0-9]+)*).*/\1/p' | ${HEAD} -n1)"
        if [[ -n "${os}" ]]; then
          selected_name="$name_trimmed"
          selected_os="$os"
          echo "Found simulator: $selected_name with iOS $selected_os"
          break 2
        fi
      fi
    done
  done

  # If not found, prefer any iPhone on the highest available iOS version
  if [[ -z "${selected_name}" || -z "${selected_os}" ]]; then
    for ios_version in $available_ios_versions; do
      line="$(echo "${sim_lines}" | ${GREP} -E "OS:${ios_version}" | ${GREP} -E "name:iPhone [^,}]++" | ${HEAD} -n1 || true)"
      if [[ -n "${line}" ]]; then
        selected_name="$(echo "$line" | ${SED} -En 's/.*name:([^,}]+).*/\1/p' | ${HEAD} -n1)"
        selected_os="$(echo "$line" | ${SED} -En 's/.*OS:([0-9]+(\.[0-9]+)*).*/\1/p' | ${HEAD} -n1)"
        if [[ -n "$selected_name" && -n "$selected_os" ]]; then
          echo "Using available iPhone simulator: $selected_name with iOS $selected_os"
          break
        fi
      fi
    done
  fi

  # Final fallback: any iOS simulator line
  if [[ -z "${selected_name}" || -z "${selected_os}" ]]; then
    # Try any iPhone first regardless of OS
    any_sim_line="$(echo "${sim_lines}" | ${GREP} -E "name:iPhone [^,}]++" | ${HEAD} -n1 || true)"
    if [[ -z "${any_sim_line}" ]]; then
      any_sim_line="$(echo "${sim_lines}" | ${HEAD} -n1 || true)"
    fi
    if [[ -n "${any_sim_line}" ]]; then
      selected_name="$(echo "$any_sim_line" | ${SED} -En 's/.*name:([^,}]+).*/\1/p' | ${HEAD} -n1)"
      selected_os="$(echo "$any_sim_line" | ${SED} -En 's/.*OS:([0-9]+(\.[0-9]+)*).*/\1/p' | ${HEAD} -n1)"
      if [[ -n "$selected_name" && -n "$selected_os" ]]; then
        echo "Using fallback simulator: $selected_name with iOS $selected_os"
      fi
    fi
  fi

  if [[ -z "${selected_name}" || -z "${selected_os}" ]]; then
    # As a last resort, allow generic platform destination to enable build-only flows
    if echo "${destinations_output}" | ${GREP} -q "DVTiOSDeviceSimulatorPlaceholder\|name:Any iOS Simulator Device"; then
      echo "Using generic iOS Simulator destination (no concrete simulators available)."
      SELECTED_DEST="generic/platform=iOS Simulator"
      DEST_IS_GENERIC=1
      echo "Using destination: ${SELECTED_DEST}"
      return 0
    fi
    echo "❌ No iOS simulators found at all. Available destinations:" >&2
    echo "${destinations_output}" >&2
    exit 3
  fi

  SELECTED_DEST="platform=iOS Simulator,name=${selected_name},OS=${selected_os}"
  echo "Using destination: ${SELECTED_DEST}"
}

# Core build functions (unchanged API)
full_clean_build() {
  echo "🧹 Performing full clean build of entire project"
  setup_result_files "full_clean_build"
  select_simulator "${WORKSPACE}" "${SCHEME}"

  set -x
  if [[ "${DEST_IS_GENERIC}" -eq 1 ]]; then
    xcodebuild -workspace "${WORKSPACE}" \
               -scheme "${SCHEME}" \
               -sdk iphonesimulator \
               -destination "${SELECTED_DEST}" \
               -resultBundlePath "${RESULT_BUNDLE}" \
               clean build | tee "${RESULT_LOG}"
  else
    xcodebuild -workspace "${WORKSPACE}" \
               -scheme "${SCHEME}" \
               -sdk iphonesimulator \
               -destination "${SELECTED_DEST}" \
               -resultBundlePath "${RESULT_BUNDLE}" \
               clean build | tee "${RESULT_LOG}"
  fi
  set +x

  echo "✅ Full clean build completed"
  echo "Build results bundle: ${RESULT_BUNDLE}"
  echo "Log: ${RESULT_LOG}"
}

full_build_no_test() {
  echo "🔨 Performing full build without tests"
  setup_result_files "full_build_no_test"
  select_simulator "${WORKSPACE}" "${SCHEME}"

  set -x
  if [[ "${DEST_IS_GENERIC}" -eq 1 ]]; then
    xcodebuild -workspace "${WORKSPACE}" \
               -scheme "${SCHEME}" \
               -sdk iphonesimulator \
               -destination "${SELECTED_DEST}" \
               -resultBundlePath "${RESULT_BUNDLE}" \
               build | tee "${RESULT_LOG}"
  else
    xcodebuild -workspace "${WORKSPACE}" \
               -scheme "${SCHEME}" \
               -sdk iphonesimulator \
               -destination "${SELECTED_DEST}" \
               -resultBundlePath "${RESULT_BUNDLE}" \
               build | tee "${RESULT_LOG}"
  fi
  set +x

  echo "✅ Full build (no tests) completed"
  echo "Build results bundle: ${RESULT_BUNDLE}"
  echo "Log: ${RESULT_LOG}"
}

full_build_and_test() {
  echo "🚀 Performing full build and test"
  setup_result_files "full_build_and_test"
  select_simulator "${WORKSPACE}" "${SCHEME}"

  # If only generic destination is available, we cannot run xcodebuild tests; build-only and run SPM tests instead.
  if [[ "${DEST_IS_GENERIC}" -eq 1 ]]; then
    echo "⚠️  No concrete iOS Simulator available. Building for generic iOS Simulator and running Swift Package tests."
    set -x
    xcodebuild -workspace "${WORKSPACE}" \
               -scheme "${SCHEME}" \
               -sdk iphonesimulator \
               -destination "${SELECTED_DEST}" \
               -resultBundlePath "${RESULT_BUNDLE}" \
               clean build | tee "${RESULT_LOG}"
    set +x
    run_all_package_tests
    echo "✅ Build completed and package tests executed"
    echo "Test results bundle (build logs only for app target): ${RESULT_BUNDLE}"
    echo "Log: ${RESULT_LOG}"
    return 0
  fi

  set -x
  xcodebuild -workspace "${WORKSPACE}" \
             -scheme "${SCHEME}" \
             -sdk iphonesimulator \
             -destination "${SELECTED_DEST}" \
             -resultBundlePath "${RESULT_BUNDLE}" \
             clean build test | tee "${RESULT_LOG}"
  set +x

  echo "✅ Full build and test completed"
  echo "Test results bundle: ${RESULT_BUNDLE}"
  echo "Log: ${RESULT_LOG}"
}

partial_clean_build() {
  local module_name="$1"
  if [[ -z "$module_name" ]]; then
    echo "❌ Module name required for partial_clean_build" >&2
    exit 1
  fi

  echo "🧹 Performing clean build of module: $module_name"
  setup_result_files "partial_clean_build" "$module_name"

  local package_path="Packages/$module_name"
  if [[ ! -d "$package_path" ]]; then
    echo "❌ Module '$module_name' not found at $package_path" >&2
    exit 1
  fi

  echo "Building package at: $package_path"
  pushd "$package_path" > /dev/null

  set -x
  swift build | tee "../../${RESULT_LOG}"
  set +x

  popd > /dev/null

  echo "✅ Partial clean build of $module_name completed"
  echo "Log: ${RESULT_LOG}"
}

partial_build_and_test() {
  local module_name="$1"
  if [[ -z "$module_name" ]]; then
    echo "❌ Module name required for partial_build_and_test" >&2
    exit 1
  fi

  echo "🚀 Performing build and test of module: $module_name"
  setup_result_files "partial_build_and_test" "$module_name"

  local package_path="Packages/$module_name"
  if [[ ! -d "$package_path" ]]; then
    echo "❌ Module '$module_name' not found at $package_path" >&2
    exit 1
  fi

  echo "Building and testing package at: $package_path"
  pushd "$package_path" > /dev/null

  set -x
  swift test | tee "../../${RESULT_LOG}"
  set +x

  popd > /dev/null

  echo "✅ Partial build and test of $module_name completed"
  echo "Log: ${RESULT_LOG}"
}

# New helpers: targeted build/test
is_package() {
  local name="$1"
  [[ -d "Packages/$name" ]]
}

run_build_target() {
  local target="$1"
  if [[ "$target" == "all" || "$target" == "zpod" ]]; then
    echo "🔨 Build app scheme (target: $target)"
    setup_result_files "build" "$target"
    select_simulator "${WORKSPACE}" "${SCHEME}"
    local args=( -workspace "${WORKSPACE}" -scheme "${SCHEME}" -sdk iphonesimulator -destination "${SELECTED_DEST}" -resultBundlePath "${RESULT_BUNDLE}" )
    if [[ $REQUESTED_CLEAN -eq 1 ]]; then args+=( clean ); fi
    args+=( build )
    set -x
    xcodebuild "${args[@]}" | tee "${RESULT_LOG}"
    set +x
    echo "✅ Build completed (target: $target)"
  elif is_package "$target"; then
    echo "🔨 Build package (target: $target)"
    setup_result_files "build_pkg" "$target"
    pushd "Packages/$target" > /dev/null
    if [[ $REQUESTED_CLEAN -eq 1 ]]; then
      swift package clean || true
    fi
    set -x
    swift build | tee "../../${RESULT_LOG}"
    set +x
    popd > /dev/null
    echo "✅ Package build completed (target: $target)"
  else
    echo "❌ Unknown build target: $target" >&2
    echo "Hint: Use 'zpod' for app or a package name under Packages/." >&2
    exit 1
  fi
}

run_test_target() {
  local target="$1"
  # App scheme tests via xcodebuild
  if [[ "$target" == "all" || "$target" == "zpod" || "$target" == "zpodTests" || "$target" == "zpodUITests" || "$target" == "IntegrationTests" || "$target" == *"/"* ]]; then
    echo "🧪 Test app via xcodebuild (target: $target)"
    setup_result_files "test" "$target"
    select_simulator "${WORKSPACE}" "${SCHEME}"

    if [[ "${DEST_IS_GENERIC}" -eq 1 ]]; then
      echo "⚠️  No concrete iOS Simulator available; building only. Consider running on a machine with simulators for UI/unit tests."
      local args=( -workspace "${WORKSPACE}" -scheme "${SCHEME}" -sdk iphonesimulator -destination "${SELECTED_DEST}" -resultBundlePath "${RESULT_BUNDLE}" )
      if [[ $REQUESTED_CLEAN -eq 1 ]]; then args+=( clean ); fi
      args+=( build )
      set -x
      xcodebuild "${args[@]}" | tee "${RESULT_LOG}"
      set +x
      echo "ℹ️  Falling back to Swift Package tests due to missing simulator"
      run_all_package_tests
      return 0
    fi

    local args=( -workspace "${WORKSPACE}" -scheme "${SCHEME}" -sdk iphonesimulator -destination "${SELECTED_DEST}" -resultBundlePath "${RESULT_BUNDLE}" )
    if [[ $REQUESTED_CLEAN -eq 1 ]]; then args+=( clean ); fi
    if [[ "$target" == "zpod" || "$target" == "all" ]]; then
      args+=( build test )
    elif [[ "$target" == "zpodTests" || "$target" == "zpodUITests" || "$target" == "IntegrationTests" ]]; then
      args+=( build test -only-testing:"$target" )
    else
      # Target/Class pattern
      args+=( build test -only-testing:"$target" )
    fi
    set -x
    xcodebuild "${args[@]}" | tee "${RESULT_LOG}"
    set +x
    echo "✅ Tests completed (target: $target)"
  # Package tests via swift test
  elif is_package "$target"; then
    echo "🧪 Test package via swift test (target: $target)"
    setup_result_files "test_pkg" "$target"
    pushd "Packages/$target" > /dev/null
    if [[ $REQUESTED_CLEAN -eq 1 ]]; then
      swift package clean || true
    fi
    set -x
    swift test | tee "../../${RESULT_LOG}"
    set +x
    popd > /dev/null
    echo "✅ Package tests completed (target: $target)"
  else
    echo "❌ Unknown test target: $target" >&2
    echo "Hint: Use 'zpod', app test targets (zpodTests, zpodUITests, IntegrationTests), a TestTarget/Class, or a package name under Packages/." >&2
    exit 1
  fi
}

# Legacy support for existing functionality
run_legacy_mode() {
  echo "🔄 Running in legacy compatibility mode"

  # Infer scheme if not explicitly set and tests are specified
  if [[ -z "${SCHEME_EXPLICIT:-}" && "$TESTS" != "all" ]]; then
    IFS=', ' read -r -a TEST_ARRAY <<< "$TESTS"
    FIRST_TEST="${TEST_ARRAY[0]}"
    SUITE_NAME="${FIRST_TEST%%/*}"
    case "$SUITE_NAME" in
      zpodTests|zpodUITests)
        SCHEME="zpod"
        ;;
      IntegrationTests)
        SCHEME="IntegrationTests"
        ;;
      *)
        SCHEME="zpod"
        ;;
    esac
    echo "[run-xcode-tests.sh] Inferred scheme: $SCHEME (from test suite: $SUITE_NAME)"
  fi

  # Handle test class search
  if [[ "$TESTS" != "all" && "$TESTS" != *"/"* ]]; then
    echo "[run-xcode-tests.sh] Searching for test class '$TESTS' in workspace..."
    MATCH_PATH=$(find .. -type f -name "*.swift" -path "*Tests*" -exec ${GREP} -l "class $TESTS" {} + | ${HEAD} -n1)
    if [[ -z "$MATCH_PATH" ]]; then
      echo "❌ Test class '$TESTS' not found in any test target." >&2
      exit 1
    fi

    TARGET_DIR=$(basename $(dirname "$MATCH_PATH"))
    PACKAGE_DIR=$(basename $(dirname $(dirname "$MATCH_PATH")))

    if [[ "$TARGET_DIR" == "zpodTests" || "$TARGET_DIR" == "zpodUITests" || "$TARGET_DIR" == "IntegrationTests" ]]; then
      TEST_TARGET="$TARGET_DIR"
      SCHEME="zpod"
      TESTS="$TEST_TARGET/$TESTS"
      echo "[run-xcode-tests.sh] Found in main app test target: $TEST_TARGET (scheme: $SCHEME)"
      USE_XCODEBUILD=1
    elif [[ "$PACKAGE_DIR" == "Tests" ]]; then
      TEST_TARGET="$TARGET_DIR"
      PACKAGE_NAME=$(basename $(dirname $(dirname $(dirname "$MATCH_PATH"))))
      echo "[run-xcode-tests.sh] Found in package: $PACKAGE_NAME, test target: $TEST_TARGET"
      USE_XCODEBUILD=0
      PACKAGE_PATH="$(dirname "$0")/../Packages/$PACKAGE_NAME"
    else
      echo "❌ Could not determine test target for '$TESTS'." >&2
      exit 2
    fi
  fi

  setup_result_files "legacy_test" "${TESTS}"

  # Execute based on mode
  if [[ "${TESTS}" == "all" || "${USE_XCODEBUILD:-}" == "1" ]]; then
    select_simulator "${WORKSPACE}" "${SCHEME}"

    # If only generic destination exists, we cannot run xcodebuild tests; build and run package tests
    if [[ "${DEST_IS_GENERIC}" -eq 1 ]]; then
      echo "⚠️  No concrete iOS Simulator available in legacy mode. Building only and running Swift Package tests."
      set -x
      xcodebuild -workspace "${WORKSPACE}" \
                 -scheme "${SCHEME}" \
                 -sdk iphonesimulator \
                 -destination "${SELECTED_DEST}" \
                 -resultBundlePath "${RESULT_BUNDLE}" \
                 clean build | tee "${RESULT_LOG}"
      set +x
      run_all_package_tests
      echo "✅ Build completed and package tests executed (legacy mode)"
      echo "Log: ${RESULT_LOG}"
      return 0
    fi

    XCODEBUILD_ARGS=(
      -workspace "${WORKSPACE}"
      -scheme "${SCHEME}"
      -sdk iphonesimulator
      -destination "${SELECTED_DEST}"
      -resultBundlePath "${RESULT_BUNDLE}"
    )
    if [[ "${TESTS}" != "all" ]]; then
      XCODEBUILD_ARGS+=( -only-testing:"${TESTS}" )
    fi

    set -x
    xcodebuild "${XCODEBUILD_ARGS[@]}" clean test | tee "${RESULT_LOG}"
    set +x

    echo "Test results bundle: ${RESULT_BUNDLE}"
    echo "Log: ${RESULT_LOG}"
  elif [[ "${USE_XCODEBUILD:-}" == "0" ]]; then
    if [[ -z "${TEST_TARGET:-}" || -z "${PACKAGE_PATH:-}" ]]; then
      echo "❌ Internal error: TEST_TARGET or PACKAGE_PATH not set for package test run." >&2
      exit 4
    fi
    echo "[run-xcode-tests.sh] Running package test: $TEST_TARGET in $PACKAGE_PATH"
    pushd "$PACKAGE_PATH" > /dev/null
    set -x
    swift test --target "$TEST_TARGET" --filter "$TESTS"
    set +x
    popd > /dev/null
  else
    echo "❌ Internal error: Could not determine test execution mode." >&2
    exit 5
  fi
}

# Ensure xcodebuild is available (allow help even without xcodebuild)
if ! command -v xcodebuild >/dev/null 2>&1; then
  # Check if this is just a help request
  for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
      print_help
      exit 0
    fi
  done
  echo "xcodebuild not found. Install Xcode and ensure command line tools are selected (xcode-select)." >&2
  echo "Note: This script requires macOS with Xcode for actual build operations." >&2
  exit 1
fi

# Show basic Xcode info
xcodebuild -version || true

# Parse arguments
ACTION=""
MODULE_NAME=""
LEGACY_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b)
      REQUESTED_BUILDS="$2"; shift 2;;
    -t)
      # New short -t for test targets; preserve legacy --tests too below
      if [[ "$2" != -* ]]; then REQUESTED_TESTS="$2"; shift 2; else shift 1; fi;;
    -c)
      REQUESTED_CLEAN=1; shift 1;;
    --scheme|-s)
      SCHEME="$2"; export SCHEME_EXPLICIT=1; LEGACY_MODE=true; shift 2;;
    --workspace|-w)
      WORKSPACE="$2"; LEGACY_MODE=true; shift 2;;
    --sim|-d)
      PREFERRED_SIM="$2"; LEGACY_MODE=true; shift 2;;
    --tests)
      TESTS="$2"; LEGACY_MODE=true; shift 2;;
    --help|-h)
      print_help; exit 0;;
    full_clean_build|full_build_no_test|full_build_and_test|partial_clean_build|partial_build_and_test)
      ACTION="$1"; shift;;
    *)
      if [[ -n "$ACTION" && -z "$MODULE_NAME" ]]; then
        MODULE_NAME="$1"
      elif [[ -z "$ACTION" && "$1" != -* ]]; then
        # Positional argument for legacy mode (test class)
        TESTS="$1"; LEGACY_MODE=true
      else
        echo "Unknown option: $1" >&2; print_help; exit 1
      fi
      shift;;
  esac
done

# New mode: handle -b/-t flags if provided
if [[ -n "$REQUESTED_BUILDS" || -n "$REQUESTED_TESTS" ]]; then
  # Build targets first (if any)
  if [[ -n "$REQUESTED_BUILDS" ]]; then
    IFS=',' read -r -a BUILD_LIST <<< "$REQUESTED_BUILDS"
    for tgt in "${BUILD_LIST[@]}"; do
      tgt_trimmed="$(echo "$tgt" | $SED 's/^ *//;s/ *$//')"
      [[ -z "$tgt_trimmed" ]] && continue
      run_build_target "$tgt_trimmed"
    done
  fi
  # Then test targets (if any)
  if [[ -n "$REQUESTED_TESTS" ]]; then
    IFS=',' read -r -a TEST_LIST <<< "$REQUESTED_TESTS"
    for tgt in "${TEST_LIST[@]}"; do
      tgt_trimmed="$(echo "$tgt" | $SED 's/^ *//;s/ *$//')"
      [[ -z "$tgt_trimmed" ]] && continue
      run_test_target "$tgt_trimmed"
    done
  fi
  echo "🎉 Operation completed successfully"
  exit 0
fi

# Determine execution mode (legacy/actions)
if [[ "$LEGACY_MODE" == "true" ]]; then
  run_legacy_mode
elif [[ -n "$ACTION" ]]; then
  case "$ACTION" in
    full_clean_build)
      full_clean_build;;
    full_build_no_test)
      full_build_no_test;;
    full_build_and_test)
      full_build_and_test;;
    partial_clean_build)
      partial_clean_build "$MODULE_NAME";;
    partial_build_and_test)
      partial_build_and_test "$MODULE_NAME";;
    *)
      echo "❌ Unknown action: $ACTION" >&2
      print_help
      exit 1;;
  esac
else
  # Default behavior: full build and test
  full_build_and_test
fi

echo "🎉 Operation completed successfully"
