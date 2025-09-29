#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__ZPOD_TESTPLAN_SH:-}" ]]; then
  return 0
fi
__ZPOD_TESTPLAN_SH=1

# Requires logging/common to be sourced.

_locate_scheme_file() {
  local scheme="$1"
  local -a candidates=(
    "${REPO_ROOT}/zpod.xcodeproj/xcshareddata/xcschemes/${scheme}.xcscheme"
    "${REPO_ROOT}/zpod.xcodeproj/xcuserdata/${USER:-}/xcshareddata/xcschemes/${scheme}.xcscheme"
    "${REPO_ROOT}/zpod.xcworkspace/xcshareddata/xcschemes/${scheme}.xcscheme"
    "${REPO_ROOT}/.swiftpm/xcode/xcshareddata/xcschemes/${scheme}.xcscheme"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  candidate=$(find "$REPO_ROOT" -maxdepth 6 -name "${scheme}.xcscheme" -print -quit 2>/dev/null || true)
  if [[ -n "$candidate" && -f "$candidate" ]]; then
    echo "$candidate"
    return 0
  fi
  return 1
}

_scheme_container_root() {
  local scheme_file="$1"
  local dir1 dir2 dir3
  dir1=$(dirname "$scheme_file") || return 1
  dir2=$(dirname "$dir1") || return 1
  dir3=$(dirname "$dir2") || return 1
  echo "$dir3"
}

_resolve_test_plan_reference() {
  local reference="$1"
  local scheme_file="$2"
  local workspace_path="$3"

  if [[ -z "$reference" ]]; then
    return 1
  fi

  local workspace_dir
  if [[ -d "$workspace_path" ]]; then
    workspace_dir="$workspace_path"
  else
    workspace_dir="$(dirname "$workspace_path")"
  fi

  case "$reference" in
    container:/*)
      echo "${reference#container:}"
      return 0
      ;;
    container:*)
      echo "${REPO_ROOT}/${reference#container:}"
      return 0
      ;;
    workspace:/*)
      echo "${reference#workspace:}"
      return 0
      ;;
    workspace:*)
      echo "${workspace_dir}/${reference#workspace:}"
      return 0
      ;;
    group:*)
      local container_root
      container_root=$(_scheme_container_root "$scheme_file") || container_root="$REPO_ROOT"
      echo "${container_root}/${reference#group:}"
      return 0
      ;;
  esac

  if [[ -f "$reference" ]]; then
    echo "$reference"
    return 0
  fi
  if [[ "$reference" == /* ]]; then
    echo "$reference"
    return 0
  fi

  echo "${REPO_ROOT}/${reference}"
  return 0
}

_verify_testplan_scheme_for_suite() {
  local suite="$1"
  case "$suite" in
    ""|zpod|default)
      echo "zpod"
      ;;
    zpodTests|zpodUITests)
      echo "zpod"
      ;;
    IntegrationTests)
      echo "IntegrationTests"
      ;;
    *)
      echo "zpod"
      ;;
  esac
}

verify_testplan_coverage() {
  local suite="${1:-}"
  local workspace="${WORKSPACE:-${REPO_ROOT}/zpod.xcworkspace}"
  local scheme
  scheme=$(_verify_testplan_scheme_for_suite "$suite")

  TESTPLAN_LAST_DISCOVERED=0
  TESTPLAN_LAST_INCLUDED=0
  TESTPLAN_LAST_MISSING=0
  TESTPLAN_LAST_PACKAGES=0
  TESTPLAN_LAST_WORKSPACE=0
  TESTPLAN_LAST_MISSING_NAMES=""

  ensure_command python3 "python3 is required to parse test plan metadata"

  log_section "Test Plan Coverage"
  if [[ -n "$suite" ]]; then
    log_info "Requested test suite: $suite"
  else
    log_info "No test suite specified; using default scheme"
  fi
  log_info "Workspace: $workspace"
  log_info "Scheme: $scheme"

  local scheme_file
  if ! scheme_file=$(_locate_scheme_file "$scheme"); then
    log_error "Unable to locate scheme file for '$scheme'"
    return 1
  fi
  log_info "Scheme file: $scheme_file"

  local test_plan_reference
  test_plan_reference=$(SCHEME_FILE="$scheme_file" python3 - <<'PY'
import os
import sys
from xml.etree import ElementTree as ET

scheme_path = os.environ.get('SCHEME_FILE')
if not scheme_path:
    raise SystemExit(1)

try:
    tree = ET.parse(scheme_path)
except ET.ParseError:
    raise SystemExit(1)

root = tree.getroot()
plans = root.findall('.//TestPlans/TestPlanReference')
if not plans:
    raise SystemExit(0)

default_plan = next((p for p in plans if p.get('default', 'NO').upper() == 'YES'), None)
target = default_plan or plans[0]
reference = target.get('reference')
if reference:
    print(reference)
PY
  ) || true

  if [[ -z "$test_plan_reference" ]]; then
    log_error "Scheme '$scheme' does not reference a test plan"
    return 1
  fi
  log_info "Resolved test plan reference: $test_plan_reference"

  local test_plan_file
  test_plan_file=$(_resolve_test_plan_reference "$test_plan_reference" "$scheme_file" "$workspace")
  if [[ -z "$test_plan_file" || ! -f "$test_plan_file" ]]; then
    log_error "Test plan file '$test_plan_reference' not found"
    return 1
  fi
  log_info "Test plan file: $test_plan_file"

  log_section "Discovered Test Targets"
  local targets_output
  if ! targets_output=$(REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import os
import sys

root = os.environ.get('REPO_ROOT')
if not root:
    raise SystemExit(1)

skip_markers = {'.build', 'DerivedData', 'xcuserdata', 'TestResults', '.swiftpm', 'Build', '.git'}
discovered = {}

for dirpath, dirnames, _ in os.walk(root):
    rel = os.path.relpath(dirpath, root)
    if rel.startswith('..'):
        continue

    depth = 0 if rel == '.' else rel.count(os.sep)
    if depth >= 5:
        dirnames[:] = []
        continue

    dirnames[:] = [d for d in dirnames if d not in skip_markers]

    parts = set(dirpath.split(os.sep))
    if parts & skip_markers:
        continue

    base = os.path.basename(dirpath)
    if base.endswith('Tests') and base != 'Tests':
        location = 'package' if '/Packages/' in dirpath else 'workspace'
        discovered[base] = location

for name in sorted(discovered):
    print(f"{name}\t{discovered[name]}")
PY
  ); then
    log_error "Failed to enumerate test targets"
    return 1
  fi

  local -a all_targets=()
  local package_targets=""
  if [[ -n "$targets_output" ]]; then
    while IFS=$'\t' read -r name location; do
      [[ -z "$name" ]] && continue
      all_targets+=("$name")
      if [[ "$location" == "package" ]]; then
        package_targets+="${name}"$'\n'
      fi
    done <<< "$targets_output"
  fi

  for candidate in "${all_targets[@]}"; do
    if printf '%s' "$package_targets" | grep -qx "$candidate"; then
      continue
    fi
    if [[ -f "$REPO_ROOT/Package.swift" ]] && \
       grep -q ".testTarget(name: \"${candidate}\"" "$REPO_ROOT/Package.swift"; then
      package_targets+="${candidate}"$'\n'
    fi
  done

  if [[ ${#all_targets[@]} -eq 0 ]]; then
    log_warn "No test targets discovered"
  else
    local target
    for target in "${all_targets[@]}"; do
      log_info "  - $target"
    done
  fi

  log_section "Test Plan Entries"
  local included_output
  if ! included_output=$(TEST_PLAN_PATH="$test_plan_file" python3 - <<'PY'
import json
import os
import sys

path = os.environ.get('TEST_PLAN_PATH')
if not path:
    raise SystemExit(1)

try:
    with open(path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)

names = sorted({
    entry.get('target', {}).get('name')
    for entry in data.get('testTargets', [])
    if isinstance(entry, dict)
})

for name in names:
    if name:
        print(name)
PY
  ); then
    log_error "Failed to parse test plan JSON"
    return 1
  fi

  local -a included_targets=()
  if [[ -n "$included_output" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      included_targets+=("$line")
    done <<< "$included_output"
  fi

  if [[ ${#included_targets[@]} -eq 0 ]]; then
    log_warn "No test targets listed in plan"
  else
    local included
    for included in "${included_targets[@]}"; do
      log_info "  - $included"
    done
  fi

  local -a missing=()
  local candidate
  for candidate in "${all_targets[@]}"; do
    if printf '%s' "$package_targets" | grep -qx "$candidate"; then
      continue
    fi
    local found=0
    local entry
    for entry in "${included_targets[@]}"; do
      if [[ "$candidate" == "$entry" ]]; then
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      missing+=("$candidate")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    TESTPLAN_LAST_DISCOVERED=${#all_targets[@]}
    TESTPLAN_LAST_INCLUDED=${#included_targets[@]}
    local pkg_count=0
    local workspace_count=0
    for candidate in "${all_targets[@]}"; do
      if printf '%s' "$package_targets" | grep -qx "$candidate"; then
        ((pkg_count++))
      else
        ((workspace_count++))
      fi
    done
    TESTPLAN_LAST_PACKAGES=$pkg_count
    TESTPLAN_LAST_WORKSPACE=$workspace_count
    TESTPLAN_LAST_MISSING=0
    TESTPLAN_LAST_MISSING_NAMES=""
    log_success "All discovered test targets are present in the test plan"
    return 0
  fi

  TESTPLAN_LAST_DISCOVERED=${#all_targets[@]}
  TESTPLAN_LAST_INCLUDED=${#included_targets[@]}
  TESTPLAN_LAST_MISSING=${#missing[@]}
  local pkg_count=0
  local workspace_count=0
  for candidate in "${all_targets[@]}"; do
    if printf '%s' "$package_targets" | grep -qx "$candidate"; then
      ((pkg_count++))
    else
      ((workspace_count++))
    fi
  done
  TESTPLAN_LAST_PACKAGES=$pkg_count
  TESTPLAN_LAST_WORKSPACE=$workspace_count

  local missing_list=""
  log_warn "Missing targets in test plan:"
  for candidate in "${missing[@]}"; do
    log_warn "  - $candidate"
    if [[ -z "$missing_list" ]]; then
      missing_list="$candidate"
    else
      missing_list+=$'\n'
      missing_list+="$candidate"
    fi
  done
  TESTPLAN_LAST_MISSING_NAMES="$missing_list"
  return 2
}
