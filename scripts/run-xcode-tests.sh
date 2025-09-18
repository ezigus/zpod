#!/usr/bin/env bash
set -euo pipefail

# Run Xcode build and test operations with modular functions
# Usage:
#   scripts/run-xcode-tests.sh [--scheme|-s SCHEME] [--workspace|-w WORKSPACE] [--sim|-d SIM_NAME] [--tests|-t TEST1,TEST2,...]
#   scripts/run-xcode-tests.sh [ACTION] [MODULE_NAME]
# 
# Actions:
#   full_clean_build        - Performs a clean build of the entire project
#   full_build_no_test      - Performs a full build without running any tests
#   full_build_and_test     - Performs a full build and runs all tests (default)
#   partial_clean_build     - Performs a clean build of a specific module
#   partial_build_and_test  - Performs a clean build and runs tests for a specific module
#
# Defaults:
#   --scheme/-s     zpod
#   --workspace/-w  zpod.xcworkspace
#   --sim/-d        iPhone 16
#   --tests/-t      all

# Default values
SCHEME="zpod"
WORKSPACE="zpod.xcworkspace"
PREFERRED_SIM="iPhone 16"
TESTS="all"

# Initialize result directories
mkdir -p TestResults

# Utility functions
print_help() {
  cat <<EOF
Usage: $0 [OPTIONS] [ACTION] [MODULE_NAME]

Run Xcode build and test operations for the zPod app on an iOS simulator.

Actions:
  full_clean_build        Performs a clean build of the entire project
  full_build_no_test      Performs a full build without running any tests  
  full_build_and_test     Performs a full build and runs all tests (default)
  partial_clean_build     Performs a clean build of a specific module
  partial_build_and_test  Performs a clean build and runs tests for a specific module

Options (for legacy compatibility):
  --scheme,    -s  <scheme>      Xcode scheme to test (default: zpod)
  --workspace, -w  <workspace>   Xcode workspace file (default: zpod.xcworkspace)
  --sim,       -d  <simulator>   Simulator device name (default: iPhone 16)
  --tests,     -t  <tests>       Comma or space separated list of tests to run (default: all)
  --help,      -h                Show this help menu and exit

Available Modules:
  CoreModels, DiscoverFeature, FeedParsing, LibraryFeature, Networking,
  Persistence, PlaybackEngine, PlayerFeature, PlaylistFeature, 
  RecommendationDomain, SearchDomain, SettingsDomain, SharedUtilities, TestSupport

Examples:
  $0                                    # Run full build and test (default)
  $0 full_clean_build                   # Clean build entire project
  $0 full_build_no_test                 # Build without tests
  $0 partial_build_and_test CoreModels  # Build and test CoreModels package
  $0 -t MyTests                         # Legacy: Run specific tests
EOF
}

# Logging and result management
setup_result_files() {
  local action="$1"
  local module="${2:-all}"
  RESULT_STAMP="$(date +%Y%m%d_%H%M%S)"
  RESULT_BUNDLE="TestResults/TestResults_${RESULT_STAMP}_${action}_${module// /-}.xcresult"
  RESULT_LOG="TestResults/TestResults_${RESULT_STAMP}_${action}_${module// /-}.log"
}

# Device selection logic
select_simulator() {
  local workspace="$1"
  local scheme="$2"
  
  echo "Listing destinations for scheme '${scheme}':"
  destinations_output="$(xcodebuild -workspace "${workspace}" -scheme "${scheme}" -showdestinations | cat || true)"
  echo "${destinations_output}"

  local fallback_sims=(
    "${PREFERRED_SIM}"
    "iPhone 16 Pro"
    "iPhone 16 Plus"  
    "iPhone 16 Pro Max"
    "iPhone 15 Pro"
    "iPhone 15"
    "iPhone 14 Pro"
    "iPhone 14"
  )
  
  # Extract all available iOS versions from simulators
  available_ios_versions="$(echo "${destinations_output}" | grep "platform:iOS Simulator" | sed -En 's/.*OS:([0-9]+(\.[0-9]+)*).*/\1/p' | sort -V -r | uniq)"
  echo "Available iOS versions: $(echo "$available_ios_versions" | tr '\n' ' ')"
  
  local selected_name=""
  local selected_os=""
  
  # Try each iOS version starting with the latest
  for ios_version in $available_ios_versions; do
    echo "Trying iOS version: $ios_version"
    
    for sim_name in "${fallback_sims[@]}"; do
      name_trimmed="$(echo "$sim_name" | sed 's/^ *//;s/ *$//')"
      line="$(echo "${destinations_output}" | grep "platform:iOS Simulator" | grep "name:${name_trimmed}" | grep "OS:${ios_version}" | head -n1 || true)"
      if [[ -n "${line}" ]]; then
        os="$(echo "$line" | sed -En 's/.*OS:([0-9]+(\.[0-9]+)*).*/\1/p' | head -n1)"
        if [[ -n "${os}" ]]; then
          selected_name="$name_trimmed"
          selected_os="$os"
          echo "Found simulator: $selected_name with iOS $selected_os"
          break 2
        fi
      fi
    done
  done

  if [[ -z "${selected_name}" || -z "${selected_os}" ]]; then
    echo "No preferred simulators found. Trying any available iOS simulator..." >&2
    
    # Fallback: try any iOS simulator
    any_sim_line="$(echo "${destinations_output}" | grep "platform:iOS Simulator" | head -n1 || true)"
    if [[ -n "${any_sim_line}" ]]; then
      selected_name="$(echo "$any_sim_line" | sed -En 's/.*name:([^,}]+).*/\1/p' | head -n1)"
      selected_os="$(echo "$any_sim_line" | sed -En 's/.*OS:([0-9]+(\.[0-9]+)*).*/\1/p' | head -n1)"
      echo "Using fallback simulator: $selected_name with iOS $selected_os"
    fi
  fi
  
  if [[ -z "${selected_name}" || -z "${selected_os}" ]]; then
    echo "❌ No iOS simulators found at all. Available destinations:" >&2
    echo "${destinations_output}" >&2
    exit 3
  fi

  SELECTED_DEST="platform=iOS Simulator,name=${selected_name},OS=${selected_os}"
  echo "Using destination: ${SELECTED_DEST}"
}

# Core build functions
full_clean_build() {
  echo "🧹 Performing full clean build of entire project"
  setup_result_files "full_clean_build"
  select_simulator "${WORKSPACE}" "${SCHEME}"
  
  set -x
  xcodebuild -workspace "${WORKSPACE}" \
             -scheme "${SCHEME}" \
             -sdk iphonesimulator \
             -destination "${SELECTED_DEST}" \
             -resultBundlePath "${RESULT_BUNDLE}" \
             clean build | tee "${RESULT_LOG}"
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
  xcodebuild -workspace "${WORKSPACE}" \
             -scheme "${SCHEME}" \
             -sdk iphonesimulator \
             -destination "${SELECTED_DEST}" \
             -resultBundlePath "${RESULT_BUNDLE}" \
             build | tee "${RESULT_LOG}"
  set +x
  
  echo "✅ Full build (no tests) completed"
  echo "Build results bundle: ${RESULT_BUNDLE}"
  echo "Log: ${RESULT_LOG}"
}

full_build_and_test() {
  echo "🚀 Performing full build and test"
  setup_result_files "full_build_and_test"
  select_simulator "${WORKSPACE}" "${SCHEME}"
  
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
    MATCH_PATH=$(find . -type f -name "*.swift" -path "*Tests*" -exec grep -l "class $TESTS" {} + | head -n1)
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
      PACKAGE_PATH="Packages/$PACKAGE_NAME"
    else
      echo "❌ Could not determine test target for '$TESTS'." >&2
      exit 2
    fi
  fi

  setup_result_files "legacy_test" "${TESTS}"
  
  # Execute based on mode
  if [[ "${TESTS}" == "all" || "${USE_XCODEBUILD:-}" == "1" ]]; then
    select_simulator "${WORKSPACE}" "${SCHEME}"
    
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
    --scheme|-s)
      SCHEME="$2"; export SCHEME_EXPLICIT=1; LEGACY_MODE=true; shift 2;;
    --workspace|-w)
      WORKSPACE="$2"; LEGACY_MODE=true; shift 2;;
    --sim|-d)
      PREFERRED_SIM="$2"; LEGACY_MODE=true; shift 2;;
    --tests|-t)
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

# Determine execution mode
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