#!/usr/bin/env bash
set -euo pipefail

# verify-testplan-coverage.sh
# Verifies that all test targets in the workspace are included in the correct test plan.
# Usage: ./verify-testplan-coverage.sh [TestSuiteName]

WORKSPACE="zpod.xcworkspace"

# Accept test suite name as an argument (optional)
TEST_SUITE="${1:-}"

# Determine scheme based on test suite name
if [[ -z "$TEST_SUITE" ]]; then
    SCHEME="zpod"
    echo "No test suite specified. Defaulting to scheme: $SCHEME"
else
    case "$TEST_SUITE" in
        zpodTests|zpodUITests)
            SCHEME="zpod"
            ;;
        IntegrationTests)
            SCHEME="IntegrationTests" # Example: add more mappings as needed
            ;;
        *)
            SCHEME="zpod" # Default fallback
            ;;
    esac
    echo "Test suite: $TEST_SUITE → Using scheme: $SCHEME"
fi

# Find all test targets by looking for *Tests directories at the top level and in Packages
ALL_TEST_TARGETS=()
while IFS= read -r dir; do
    target=$(basename "$dir")
    ALL_TEST_TARGETS+=("$target")
done < <(find .. -type d -name '*Tests' -maxdepth 4)

# Remove duplicates and sort
ALL_TEST_TARGETS=($(printf "%s\n" "${ALL_TEST_TARGETS[@]}" | sort -u))

printf "\n🧪 All discovered test targets in workspace:\n"
for t in "${ALL_TEST_TARGETS[@]}"; do echo "  - $t"; done

# Get the test plan name for the scheme
TEST_PLAN=$(xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -showTestPlans | grep -Eo '^[^ ]+$' | grep -v '^Test' | grep -v '^xcodebuild$' | grep -v '^COMMAND' | grep -v '^$' | head -n 1 | xargs)
if [[ -z "$TEST_PLAN" ]]; then
    echo "❌ No test plan found for scheme '$SCHEME'." >&2
    exit 1
fi

# Find the test plan file (search from the workspace root)
TEST_PLAN_FILE=$(find . -name "$TEST_PLAN.xctestplan" | head -n 1)
if [[ ! -f "$TEST_PLAN_FILE" ]]; then
    echo "❌ Test plan file '$TEST_PLAN.xctestplan' not found." >&2
    exit 1
fi

printf "\n📋 Test plan file: %s\n" "$TEST_PLAN_FILE"
printf "\nRaw test plan JSON:\n"
plutil -p "$TEST_PLAN_FILE"
printf "\nExtracted test targets from test plan JSON:\n"
plutil -extract testTargets json -o - "$TEST_PLAN_FILE"
printf "\n✅ Test targets in test plan:\n"
# Extract included target names from test plan JSON
INCLUDED_TARGETS=($(plutil -extract testTargets json -o - "$TEST_PLAN_FILE" | grep '"name"' | sed 's/.*: \"\(.*\)\".*/\1/'))
for t in "${INCLUDED_TARGETS[@]}"; do echo "  - $t"; done

# Compare and report missing targets
MISSING=()
for t in "${ALL_TEST_TARGETS[@]}"; do
    if ! printf "%s\n" "${INCLUDED_TARGETS[@]}" | grep -qx "$t"; then
        MISSING+=("$t")
    fi
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo -e "\n🎉 All discovered test targets are included in the test plan!"
    exit 0
else
    echo -e "\n⚠️  The following test targets are NOT included in the test plan and should be added in Xcode:\n"
    for t in "${MISSING[@]}"; do echo "  - $t"; done
    exit 2
fi
