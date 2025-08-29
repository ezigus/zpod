#!/usr/bin/env bash
set -euo pipefail

# Run full Xcode test suite on an iOS 18.x simulator, preferring iPhone 16 family.
# Usage:
#   scripts/run-xcode-tests.sh [SCHEME] [WORKSPACE] [SIM_NAME]
# Defaults:
#   SCHEME=zpod
#   WORKSPACE=zpod.xcworkspace
#   SIM_NAME=iPhone 16

SCHEME="${1:-zpod}"
WORKSPACE="${2:-zpod.xcworkspace}"
PREFERRED_SIM="${3:-iPhone 16}"

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
xcodebuild \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -sdk iphonesimulator \
  -destination "${SELECTED_DEST}" \
  -resultBundlePath "${RESULT_BUNDLE}" \
  clean test | tee "${RESULT_LOG}"
set +x

echo "\nTest results bundle: ${RESULT_BUNDLE}"
echo "Log: ${RESULT_LOG}"
