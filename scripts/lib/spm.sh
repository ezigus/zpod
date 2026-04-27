#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__ZPOD_SPM_SH:-}" ]]; then
  return 0
fi
__ZPOD_SPM_SH=1

# Resolve the effective TMPDIR to use for Swift compiler and test processes.
# Checks disk space at call time (not just at source time) so that packages
# tested later in a run still get redirected if the system volume fills up
# mid-run. ZPOD_TMPDIR can be set externally to pin the value permanently.
_resolve_swift_tmpdir() {
  # If externally pinned, use it directly.
  if [[ -n "${ZPOD_TMPDIR:-}" ]]; then
    printf '%s' "${ZPOD_TMPDIR}"
    return
  fi
  local _fallback="/Volumes/zHardDrive/tmp"
  local _avail_kb
  _avail_kb=$(df -k "${TMPDIR:-/tmp}" 2>/dev/null | awk 'NR==2{print $4}' || echo 0)
  if [[ "${_avail_kb}" -lt 1048576 && -d "/Volumes/zHardDrive" ]]; then
    mkdir -p "${_fallback}" 2>/dev/null || true
    printf '%s' "${_fallback}"
    return
  fi
  printf '%s' "${TMPDIR:-/tmp}"
}

run_swift_package_tests() {
  log_info "Running Swift Package tests for all packages (fallback)"
  local found=0
  for pkg in "${REPO_ROOT}"/Packages/*; do
    if [[ -d "$pkg" ]]; then
      found=1
      local pkg_name
      pkg_name="$(basename "$pkg")"
      log_info "→ swift test (package: ${pkg_name})"
      pushd "$pkg" >/dev/null
      local _eff_tmpdir
      _eff_tmpdir="$(_resolve_swift_tmpdir)"
      if ! TMPDIR="${_eff_tmpdir}" MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}" swift test -j "${ZPOD_SWIFT_JOBS:-4}" | tee "${RESULT_LOG}"; then
        popd >/dev/null
        return 1
      fi
      popd >/dev/null
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    log_warn "No Packages/ modules found for swift test fallback"
  fi
}

build_swift_package() {
  local package_name="$1"
  local clean_requested="$2"
  local pkg_path="${REPO_ROOT}/Packages/${package_name}"
  if [[ ! -d "$pkg_path" ]]; then
    log_error "Package '${package_name}' not found at ${pkg_path}"
    return 1
  fi
  pushd "$pkg_path" >/dev/null
  if [[ "$clean_requested" -eq 1 ]]; then
    swift package clean || true
  fi
  local _eff_tmpdir
  _eff_tmpdir="$(_resolve_swift_tmpdir)"
  set +e
  TMPDIR="${_eff_tmpdir}" MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}" swift build -j "${ZPOD_SWIFT_JOBS:-4}" | tee "${RESULT_LOG}"
  local build_status=${PIPESTATUS[0]}
  set -e
  popd >/dev/null
  return "$build_status"
}

run_swift_package_target_tests() {
  local package_name="$1"
  local clean_requested="$2"
  local pkg_path="${REPO_ROOT}/Packages/${package_name}"
  if [[ ! -d "$pkg_path" ]]; then
    log_error "Package '${package_name}' not found at ${pkg_path}"
    return 1
  fi
  pushd "$pkg_path" >/dev/null
  if [[ "$clean_requested" -eq 1 ]]; then
    swift package clean || true
  fi
  local _eff_tmpdir
  _eff_tmpdir="$(_resolve_swift_tmpdir)"
  set +e
  TMPDIR="${_eff_tmpdir}" MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}" swift test -j "${ZPOD_SWIFT_JOBS:-4}" | tee "${RESULT_LOG}"
  local test_status=${PIPESTATUS[0]}
  set -e
  popd >/dev/null
  return "$test_status"
}
