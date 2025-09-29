#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__ZPOD_RESULT_SH:-}" ]]; then
  return 0
fi
__ZPOD_RESULT_SH=1

RESULTS_DIR="${REPO_ROOT}/TestResults"
mkdir -p "$RESULTS_DIR"

init_result_paths() {
  local operation="$1"
  local target="${2:-}"
  local stamp
  stamp="$(current_timestamp)"
  local suffix=""
  if [[ -n "$target" ]]; then
    # Remove spaces/slashes for filenames
    suffix="_${target//[\ \/]/-}"
  fi
  RESULT_BUNDLE="${RESULTS_DIR}/TestResults_${stamp}_${operation}${suffix}.xcresult"
  RESULT_LOG="${RESULTS_DIR}/TestResults_${stamp}_${operation}${suffix}.log"
  export RESULT_BUNDLE RESULT_LOG
}

xcresult_summary() {
  local bundle="$1"
  if [[ -z "$bundle" || ! -d "$bundle" ]]; then
    return 1
  fi
  if ! command_exists python3 || ! command_exists xcrun; then
    return 1
  fi

  python3 - "$bundle" <<'PY'
import json
import subprocess
import sys

bundle = sys.argv[1]

def run_xcresult(identifier=None):
  args = ['xcrun', 'xcresulttool', 'get', '--path', bundle, '--format', 'json', '--legacy']
  if identifier is not None:
    args.extend(['--id', identifier])
  result = subprocess.run(args, capture_output=True, text=True)
  if result.returncode != 0:
    raise RuntimeError('xcresulttool failed')
  return json.loads(result.stdout or '{}')

try:
  root = run_xcresult()
except Exception:
  raise SystemExit(1)

actions = root.get('actions', {}).get('_values', [])
if not actions:
  print('0 run, 0 passed, 0 failed, 0 skipped')
  raise SystemExit(0)

test_ids = []
for action in actions:
  tests_ref = action.get('actionResult', {}).get('testsRef')
  if tests_ref:
    identifier = tests_ref.get('id', {}).get('_value')
    if identifier:
      test_ids.append(identifier)

if not test_ids:
  print('0 run, 0 passed, 0 failed, 0 skipped')
  raise SystemExit(0)

def tally(node):
  total = failed = skipped = 0
  status = node.get('testStatus', {}).get('_value')
  if status:
    total += 1
    status_lower = status.lower()
    if status_lower == 'failure':
      failed += 1
    elif status_lower == 'skipped':
      skipped += 1
  for child in node.get('subtests', {}).get('_values', []):
    t, f, s = tally(child)
    total += t
    failed += f
    skipped += s
  return total, failed, skipped

total = failed = skipped = 0

try:
  for identifier in test_ids:
    data = run_xcresult(identifier)
    for summary in data.get('summaries', {}).get('_values', []):
      for testable in summary.get('testableSummaries', {}).get('_values', []):
        for test in testable.get('tests', {}).get('_values', []):
          t, f, s = tally(test)
          total += t
          failed += f
          skipped += s
except Exception:
  raise SystemExit(1)

passed = total - failed - skipped
if passed < 0:
  passed = 0

print(f"{total} run, {passed} passed, {failed} failed, {skipped} skipped")
PY
}

xcresult_has_failures() {
  local bundle="$1"
  if [[ ! -d "$bundle" ]]; then
    return 2
  fi

  if ! command_exists python3 || ! command_exists xcrun; then
    return 3
  fi

  local failure_count
  if ! failure_count=$(xcrun xcresulttool get --legacy --path "$bundle" --format json 2>/dev/null | \
    python3 - <<'PY'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    print("parse_error", end="")
    raise SystemExit(2)

issues = data.get("issues", {})
failures = issues.get("testFailureSummaries", {})
values = failures.get("_values")
if not isinstance(values, list):
    values = []
print(len(values), end="")
PY
  ); then
    return 3
  fi

  if [[ "$failure_count" == "parse_error" ]]; then
    return 3
  fi

  if [[ -z "$failure_count" ]]; then
    return 3
  fi

  if (( failure_count > 0 )); then
    return 0
  fi
  return 1
}
