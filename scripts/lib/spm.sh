#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__ZPOD_SPM_SH:-}" ]]; then
  return 0
fi
__ZPOD_SPM_SH=1

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
      if ! MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}" swift test | tee "${RESULT_LOG}"; then
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
  MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}" swift build | tee "${RESULT_LOG}"
  popd >/dev/null
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
  MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}" swift test | tee "${RESULT_LOG}"
  popd >/dev/null
}
