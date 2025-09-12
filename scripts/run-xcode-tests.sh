#!/usr/bin/env bash
set -euo pipefail

# Run Xcode test suite on an iOS 18.x simulator, preferring iPhone 16 family.
# Usage:
#   scripts/run-xcode-tests.sh [--scheme|-s SCHEME] [--workspace|-w WORKSPACE] [--sim|-d SIM_NAME] [--tests|-t TEST1,TEST2,...]
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

# Print help menu
print_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Run Xcode tests for the zPod app on an iOS 18.x simulator (iPhone 16 family preferred).

Options:
  --scheme,    -s  <scheme>      Xcode scheme to test (default: zpod)
  --workspace, -w  <workspace>   Xcode workspace file (default: zpod.xcworkspace)
  --sim,       -d  <simulator>   Simulator device name (default: iPhone 16)
  --tests,     -t  <tests>       Comma or space separated list of tests to run (default: all)
  --help,      -h                Show this help menu and exit

Examples:
  $0                                 # Run all tests with defaults
  $0 -t MyTests                      # Run only 'MyTests' test suite
  $0 --tests MyTests/testExample     # Run a specific test method
  $0 -s MyScheme -d "iPhone 16 Pro" # Specify scheme and simulator
  $0 -t "MyTests,OtherTests/testFoo" # Run multiple tests
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme|-s)
      SCHEME="$2"; shift 2;;
    --workspace|-w)
      WORKSPACE="$2"; shift 2;;
    --sim|-d)
      PREFERRED_SIM="$2"; shift 2;;
    --tests|-t)
      TESTS="$2"; shift 2;;
    --help|-h)
      print_help; exit 0;;
    *)
      echo "Unknown option: $1" >&2; print_help; exit 1;;
  esac
done

FALLBACK_SIMS=(
  "${PREFERRED_SIM}"
  "iPhone 16 Pro"
  "iPhone 16 Plus"
  "iPhone 16 Pro Max"
  "iPhone 16e"
  "iPhone 15 Pro"
  "iPhone 15"
)

# Ensure xcodebuild is available
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode and ensure command line tools are selected (xcode-select)." >&2
  exit 1
fi

# Show basic Xcode info
xcodebuild -version || true

# Helpers
list_devices() {
  xcrun simctl list devices available | cat
}

# Get the first iOS 18.x runtime header (e.g., "-- iOS 18.0 --") for informational output only
get_ios18_runtime_header() {
  list_devices | grep -E "^-- iOS 18(\\.[0-9]+)? --" | head -n1 || true
}

runtime_header="$(get_ios18_runtime_header)"
if [[ -n "${runtime_header}" ]]; then
  echo "Detected iOS 18 runtime block: ${runtime_header#-- }"
fi

echo "Listing available simulator devices (available only):"
list_devices || true

echo "Listing destinations for scheme '${SCHEME}':"
destinations_output="$(xcodebuild -workspace "${WORKSPACE}" -scheme "${SCHEME}" -showdestinations | cat || true)"
echo "${destinations_output}"

# From -showdestinations, pick the first iPhone 16 family device with OS 18.x and extract its exact OS
SELECTED_NAME=""
SELECTED_OS=""
while IFS= read -r sim_name; do
  # shellcheck disable=SC2001
  name_trimmed="$(echo "$sim_name" | sed 's/^ *//;s/ *$//')"
  # try to find a matching destination line containing this name and iOS 18 OS
  line="$(echo "${destinations_output}" | grep "platform:iOS Simulator" | grep "name:${name_trimmed}" | grep -E "OS:18(\\.[0-9]+){0,2}")"
  if [[ -n "${line}" ]]; then
    os="$(echo "$line" | sed -En 's/.*OS:([0-9]+(\.[0-9]+){0,2}).*/\1/p' | head -n1)"
    if [[ -n "${os}" && ${os} == 18* ]]; then
      SELECTED_NAME="$name_trimmed"
      SELECTED_OS="$os"
      break
    fi
  fi
# Iterate candidate names
done < <(printf '%s
' "${FALLBACK_SIMS[@]}")

if [[ -z "${SELECTED_NAME}" || -z "${SELECTED_OS}" ]]; then
  echo "No preferred iOS 18.x simulators found via -showdestinations. Please create an iPhone 16 simulator on iOS 18.x or pass a specific name as the 3rd arg." >&2
  exit 3
fi

SELECTED_DEST="platform=iOS Simulator,name=${SELECTED_NAME},OS=${SELECTED_OS}"
echo "Using destination: ${SELECTED_DEST}"

mkdir -p TestResults
RESULT_STAMP="$(date +%Y%m%d_%H%M%S)"
RESULT_BUNDLE="TestResults/TestResults_${RESULT_STAMP}_ios_sim_${SELECTED_NAME// /-}_OS-${SELECTED_OS}.xcresult"
RESULT_LOG="TestResults/TestResults_${RESULT_STAMP}_ios18_sim_${SELECTED_NAME// /-}_OS-${SELECTED_OS}.log"

# Run the full test suite; this will include all test targets attached to the scheme
set -x
XCODEBUILD_ARGS=(
  -workspace "${WORKSPACE}"
  -scheme "${SCHEME}"
  -sdk iphonesimulator
  -destination "${SELECTED_DEST}"
  -resultBundlePath "${RESULT_BUNDLE}"
)

if [[ -z "${TESTS}" || "${TESTS}" == "all" ]]; then
  # Run all tests
  xcodebuild "${XCODEBUILD_ARGS[@]}" clean test | tee "${RESULT_LOG}"
else
  # Support comma or space separated test names
  IFS=',' read -ra TEST_ARRAY <<< "${TESTS// /,}"
  for test_name in "${TEST_ARRAY[@]}"; do
    XCODEBUILD_ARGS+=( -only-testing:"$test_name" )
  done
  xcodebuild "${XCODEBUILD_ARGS[@]}" clean test | tee "${RESULT_LOG}"
fi
set +x

echo "\nTest results bundle: ${RESULT_BUNDLE}"
echo "Log: ${RESULT_LOG}"
