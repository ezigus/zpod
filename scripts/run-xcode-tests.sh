#!/usr/bin/env bash
set -euo pipefail

# Run full Xcode test suite on a simulator, preferring iPhone 16.
# Usage:
#   scripts/run-xcode-tests.sh [SCHEME] [WORKSPACE] [SIM_NAME] [IOS_OS_VERSION]
# Defaults:
#   SCHEME=zpod
#   WORKSPACE=zpod.xcworkspace
#   SIM_NAME=iPhone 16
#   IOS_OS_VERSION=18.5

SCHEME="${1:-zpod}"
WORKSPACE="${2:-zpod.xcworkspace}"
PREFERRED_SIM="${3:-iPhone 16}"
IOS_OS_VERSION="${4:-18.5}"

FALLBACK_SIMS=(
  "${PREFERRED_SIM}"
  "iPhone 16 Pro"
  "iPhone 16 Plus"
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

echo "Listing available simulator devices (available only):"
xcrun simctl list devices available || true

echo "Listing destinations for scheme '${SCHEME}':"
xcodebuild -workspace "${WORKSPACE}" -scheme "${SCHEME}" -showdestinations || true

# Pick the first available simulator from the preferred list
SELECTED_DEST=""
for name in "${FALLBACK_SIMS[@]}"; do
  if xcrun simctl list devices available | grep -q "${name}"; then
    SELECTED_DEST="platform=iOS Simulator,name=${name},OS=${IOS_OS_VERSION}"
    break
  fi
  # As a fallback, accept if showdestinations includes the name
  if xcodebuild -workspace "${WORKSPACE}" -scheme "${SCHEME}" -showdestinations 2>/dev/null | grep -q "${name}"; then
    SELECTED_DEST="platform=iOS Simulator,name=${name},OS=${IOS_OS_VERSION}"
    break
  fi
done

if [[ -z "${SELECTED_DEST}" ]]; then
  echo "No preferred simulators found. Please create an iOS ${IOS_OS_VERSION} simulator (e.g., iPhone 16) in Xcode or pass a specific name and OS as args." >&2
  exit 2
fi

echo "Using destination: ${SELECTED_DEST}"
RESULT_DIR="./TestResults_$(date +%Y%m%d_%H%M%S)"

# Run the full test suite; this will include all test targets attached to the scheme
set -x
xcodebuild \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -sdk iphonesimulator \
  -destination "${SELECTED_DEST}" \
  -resultBundlePath "${RESULT_DIR}" \
  clean test | tee "${RESULT_DIR}.log"
set +x

echo "\nTest results bundle: ${RESULT_DIR}"
echo "Log: ${RESULT_DIR}.log"
