#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__ZPOD_TESTPLAN_SH:-}" ]]; then
  return 0
fi
__ZPOD_TESTPLAN_SH=1

# Requires logging/common to be sourced.

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

  ensure_command xcodebuild "xcodebuild is required to inspect test plans"
  ensure_command plutil "plutil is required to parse test plans"

  log_section "Test Plan Coverage"
  if [[ -n "$suite" ]]; then
    log_info "Requested test suite: $suite"
  else
    log_info "No test suite specified; using default scheme"
  fi
  log_info "Workspace: $workspace"
  log_info "Scheme: $scheme"

  local test_plan
  test_plan=$(xcodebuild -workspace "$workspace" -scheme "$scheme" -showTestPlans 2>/dev/null \
    | grep -Eo '^[^ ]+$' | grep -Ev '^(COMMAND|Test|xcodebuild)$' | head -n 1 | xargs)
  if [[ -z "$test_plan" ]]; then
    log_error "No test plan found for scheme '$scheme'"
    return 1
  fi
  log_info "Resolved test plan: $test_plan"

  local test_plan_file
  test_plan_file=$(find "$REPO_ROOT" -name "$test_plan.xctestplan" -print -quit)
  if [[ ! -f "$test_plan_file" ]]; then
    log_error "Test plan file '$test_plan.xctestplan' not found"
    return 1
  fi
  log_info "Test plan file: $test_plan_file"

  # Discover test targets by scanning filesystem
  log_section "Discovered Test Targets"
  local -a all_targets
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    all_targets+=("$(basename "$dir")")
  done < <(find "$REPO_ROOT" -maxdepth 4 -type d -name '*Tests')
  IFS=$'\n' all_targets=($(printf "%s\n" "${all_targets[@]}" | sort -u))
  IFS=$' \t\n'

  for target in "${all_targets[@]}"; do
    log_info "  - $target"
  done
  [[ ${#all_targets[@]} -eq 0 ]] && log_warn "No test targets discovered"

  # Extract included targets from plan
  log_section "Test Plan Entries"
  local plan_json
  plan_json=$(plutil -extract testTargets json -o - "$test_plan_file")
  local -a included_targets
  IFS=$'\n' included_targets=($(printf "%s" "$plan_json" | \
    grep '"name"' | sed 's/.*: \"\(.*\)\".*/\1/'))
  IFS=$' \t\n'
  for target in "${included_targets[@]}"; do
    log_info "  - $target"
  done
  if [[ ${#included_targets[@]} -eq 0 ]]; then
    log_warn "No test targets listed in plan"
  fi

  # Compare
  local -a missing
  for target in "${all_targets[@]}"; do
    if ! printf "%s\n" "${included_targets[@]}" | grep -qx "$target"; then
      missing+=("$target")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_success "All discovered test targets are present in the test plan"
    return 0
  fi

  log_warn "Missing targets in test plan:" 
  for target in "${missing[@]}"; do
    log_warn "  - $target"
  done
  return 2
}
