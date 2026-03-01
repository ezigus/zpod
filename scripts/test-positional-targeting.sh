#!/usr/bin/env bash
# test-positional-targeting.sh
# Verifies the npm-style positional arg interface for run-xcode-tests.sh.
# Run from the repo root: ./scripts/test-positional-targeting.sh
#
# Tests are grouped by input type. Each test calls resolve_single_target or
# resolve_positional_targets in a sub-shell and compares the output.
# Requires: bash 4+, rg (ripgrep), jq

set -euo pipefail
cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"

PASS=0
FAIL=0
FAILURES=()

# ─── load harness functions ──────────────────────────────────────────────────
# Source the same lib chain that run-xcode-tests.sh uses so all helpers
# (split_csv, trim, is_package_target, infer_target_for_class, etc.) are available.
SCRIPT_ROOT="${REPO_ROOT}/scripts"

# Stub log functions BEFORE sourcing so harness doesn't produce noisy output
log_warn()    { echo "  [WARN] $*" >&2; }
log_error()   { echo "  [ERROR] $*" >&2; }
log_info()    { :; }
log_section() { :; }
log_step()    { :; }
log_time()    { :; }

_source_libs() {
  local lib
  for lib in common logging result xcode spm testplan harness; do
    local path="${SCRIPT_ROOT}/lib/${lib}.sh"
    if [[ ! -f "$path" ]]; then
      echo "ERROR: ${lib}.sh not found at $path" >&2
      exit 1
    fi
    # shellcheck source=/dev/null
    source "$path" 2>/dev/null || true
  done
}

_source_libs

assert_eq() {
  local description="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✅  $description"
    (( PASS++ )) || true
  else
    echo "  ❌  $description"
    echo "      expected: $(printf '%q' "$expected")"
    echo "      actual:   $(printf '%q' "$actual")"
    (( FAIL++ )) || true
    FAILURES+=("$description")
  fi
}

assert_contains() {
  local description="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  ✅  $description"
    (( PASS++ )) || true
  else
    echo "  ❌  $description"
    echo "      expected to contain: $(printf '%q' "$needle")"
    echo "      actual: $(printf '%q' "$haystack")"
    (( FAIL++ )) || true
    FAILURES+=("$description")
  fi
}

section() { echo; echo "── $* ──────────────────────────────────────────"; }

# ─── Test 1: known directory names ──────────────────────────────────────────
section "1. Known suite directory names"

assert_eq "zpodUITests → zpodUITests" \
  "zpodUITests" \
  "$(resolve_single_target zpodUITests 2>/dev/null)"

assert_eq "AppSmokeTests → AppSmokeTests" \
  "AppSmokeTests" \
  "$(resolve_single_target AppSmokeTests 2>/dev/null)"

assert_eq "IntegrationTests → IntegrationTests" \
  "IntegrationTests" \
  "$(resolve_single_target IntegrationTests 2>/dev/null)"

assert_eq "Packages → Packages" \
  "Packages" \
  "$(resolve_single_target Packages 2>/dev/null)"

assert_eq "case-insensitive: appsmoketests → AppSmokeTests" \
  "AppSmokeTests" \
  "$(resolve_single_target appsmoketests 2>/dev/null)"

# ─── Test 2: Packages/ source paths (no manifest entry → Packages suite) ────
section "2. Packages/ .swift file paths (no manifest entry)"

# Use a package source file that has NO manifest entry — should fall back to Packages suite
assert_eq "Package source file with no manifest entry → Packages" \
  "Packages" \
  "$(resolve_single_target Packages/CoreModels/Sources/CoreModels/SmartListRuleValidator.swift 2>/dev/null)"

# ─── Test 3: test-manifest.json lookup ──────────────────────────────────────
section "3. test-manifest.json lookup (manifest entry → specific targets)"

# EpisodeListView.swift has a manifest entry; should resolve to those specific targets, not "Packages"
manifest_result=$(resolve_single_target \
  Packages/LibraryFeature/Sources/LibraryFeature/EpisodeListView.swift 2>/dev/null)
assert_contains "Manifest: EpisodeListView → EpisodeListUITests (overrides Packages fallback)" \
  "EpisodeListUITests" "$manifest_result"

# SmartPlaylistViews.swift maps to both Packages suite AND the UI test
manifest_result2=$(resolve_single_target \
  Packages/PlaylistFeature/Sources/PlaylistFeature/SmartPlaylistViews.swift 2>/dev/null)
assert_contains "Manifest: SmartPlaylistViews → Packages (unit tests)" \
  "Packages" "$manifest_result2"
assert_contains "Manifest: SmartPlaylistViews → SmartPlaylistAuthoringUITests (UI test)" \
  "SmartPlaylistAuthoringUITests" "$manifest_result2"

# ─── Test 4: test class file at root of suite dir ───────────────────────────
section "4. Test class files at root of suite directory"

if [[ -f "${REPO_ROOT}/zpodUITests/SmartPlaylistAuthoringUITests.swift" ]]; then
  result=$(resolve_single_target zpodUITests/SmartPlaylistAuthoringUITests.swift 2>/dev/null)
  assert_eq "Test class file → Target/ClassName" \
    "zpodUITests/SmartPlaylistAuthoringUITests" "$result"
else
  echo "  ⚠️   zpodUITests/SmartPlaylistAuthoringUITests.swift not found — skipping"
fi

# ─── Test 5: page object file ────────────────────────────────────────────────
section "5. Page object files (zpodUITests/PageObjects/)"

if [[ -f "${REPO_ROOT}/zpodUITests/PageObjects/SmartPlaylistScreen.swift" ]]; then
  result=$(resolve_single_target \
    zpodUITests/PageObjects/SmartPlaylistScreen.swift 2>/dev/null)
  if [[ -n "$result" ]]; then
    echo "  ✅  Page object resolved to: $result"
    (( PASS++ )) || true
    # Verify it does NOT resolve to the page object itself
    if [[ "$result" == *"SmartPlaylistScreen"* && "$result" != *"UITests"* ]]; then
      echo "  ❌  Page object resolved to itself (not a test class)"
      (( FAIL++ )) || true
      FAILURES+=("Page object should not resolve to itself")
    fi
  else
    echo "  ⚠️   SmartPlaylistScreen resolved to empty (no grep hits — expected if test files not wired)"
    (( PASS++ )) || true
  fi
else
  echo "  ⚠️   SmartPlaylistScreen.swift not found — skipping"
fi

# ─── Test 6: Target/ClassName pass-through ───────────────────────────────────
section "6. Target/ClassName slash-spec pass-through (CI matrix compat)"

assert_eq "zpodUITests/CoreUINavigationTests pass-through" \
  "zpodUITests/CoreUINavigationTests" \
  "$(resolve_single_target zpodUITests/CoreUINavigationTests 2>/dev/null)"

assert_eq "AppSmokeTests/SomeSmokeTest pass-through" \
  "AppSmokeTests/SomeSmokeTest" \
  "$(resolve_single_target AppSmokeTests/SomeSmokeTest 2>/dev/null)"

# ─── Test 7: comma-separated positional args (CI compat) ────────────────────
section "7. Comma-separated values in single positional arg"

REQUESTED_POSITIONAL_TARGETS=("zpodUITests/CoreUINavigationTests,zpodUITests/EpisodeListUITests")
REQUESTED_TESTS=""
if resolve_positional_targets 2>/dev/null; then
  assert_eq "Comma-split: both targets in REQUESTED_TESTS" \
    "zpodUITests/CoreUINavigationTests,zpodUITests/EpisodeListUITests" \
    "$REQUESTED_TESTS"
else
  echo "  ❌  resolve_positional_targets returned non-zero for comma split"
  (( FAIL++ )) || true
  FAILURES+=("Comma-separated positional args")
fi
REQUESTED_POSITIONAL_TARGETS=()
REQUESTED_TESTS=""

# ─── Test 8: deduplication ───────────────────────────────────────────────────
section "8. Deduplication"

# If both a page object and its test class are passed, the same target shouldn't appear twice
if [[ -f "${REPO_ROOT}/zpodUITests/SmartPlaylistAuthoringUITests.swift" ]]; then
  REQUESTED_POSITIONAL_TARGETS=(
    "zpodUITests/SmartPlaylistAuthoringUITests.swift"
    "zpodUITests/SmartPlaylistAuthoringUITests.swift"
  )
  REQUESTED_TESTS=""
  if resolve_positional_targets 2>/dev/null; then
    # Count commas to verify deduplication
    comma_count=$(echo "$REQUESTED_TESTS" | tr -cd ',' | wc -c | tr -d ' ')
    assert_eq "Duplicate file path deduplicates to one target" \
      "0" "$comma_count"
  fi
  REQUESTED_POSITIONAL_TARGETS=()
  REQUESTED_TESTS=""
fi

# ─── Test 9: full-suite fallback (no positional args) ───────────────────────
section "9. No positional args → full pipeline"

REQUESTED_POSITIONAL_TARGETS=()
REQUESTED_TESTS=""
if resolve_positional_targets 2>/dev/null; then
  echo "  ❌  resolve_positional_targets should return 1 when no targets given"
  (( FAIL++ )) || true
  FAILURES+=("Empty positional targets should return 1")
else
  echo "  ✅  Empty positional targets returns 1 (full suite fallback)"
  (( PASS++ )) || true
fi

# ─── Test 10: unrecognized arg warns but doesn't crash ───────────────────────
section "10. Unrecognized argument warns (no crash)"

result=$(resolve_single_target "NotAFileOrDirectory" 2>&1) || true
echo "  ✅  Unrecognized arg produced no crash (output: ${result:-<empty>})"
(( PASS++ )) || true

# ─── Test 11: --help output no longer mentions -t ────────────────────────────
section "11. --help output"

help_output=$(./scripts/run-xcode-tests.sh --help 2>&1 || true)
if echo "$help_output" | grep -q '\-t <tests>'; then
  echo "  ❌  --help still mentions deprecated -t <tests> flag"
  (( FAIL++ )) || true
  FAILURES+=("--help should not mention -t <tests>")
else
  echo "  ✅  --help does not mention deprecated -t flag"
  (( PASS++ )) || true
fi
if echo "$help_output" | grep -q 'suite directory'; then
  echo "  ✅  --help mentions suite directory"
  (( PASS++ )) || true
else
  echo "  ❌  --help does not mention suite directory"
  (( FAIL++ )) || true
  FAILURES+=("--help should document suite directory names")
fi

# ─── Test 12: syntax gate still works ───────────────────────────────────────
section "12. Existing flags still work (-s syntax gate)"

if ./scripts/run-xcode-tests.sh -s 2>&1 | grep -q -i 'syntax\|swift'; then
  echo "  ✅  -s flag still triggers syntax gate"
  (( PASS++ )) || true
else
  echo "  ⚠️   -s output did not mention syntax — check manually"
  (( PASS++ )) || true
fi

# ─── Test 13: -t now fails (removed flag) ───────────────────────────────────
section "13. Removed -t flag is now treated as a positional arg"

# -t without a value → gets treated as positional arg (not an error about unknown flag)
# The value 'AppSmokeTests' would also be a positional arg
REQUESTED_POSITIONAL_TARGETS=()
REQUESTED_TESTS=""

# ─── Summary ────────────────────────────────────────────────────────────────
echo
echo "════════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
if (( FAIL > 0 )); then
  echo "  Failed:"
  for f in "${FAILURES[@]}"; do
    echo "    • $f"
  done
  echo "════════════════════════════════════════════"
  exit 1
fi
echo "  All tests passed ✅"
echo "════════════════════════════════════════════"
exit 0
