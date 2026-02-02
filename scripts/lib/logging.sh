#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${__ZPOD_LOGGING_SH:-}" ]]; then
  return 0
fi
__ZPOD_LOGGING_SH=1

# ANSI colour codes (fall back to no colour when not a TTY)
if [[ -t 1 ]]; then
  __LOG_RESET="\033[0m"
  __LOG_BLUE="\033[0;34m"
  __LOG_GREEN="\033[0;32m"
  __LOG_YELLOW="\033[0;33m"
  __LOG_RED="\033[0;31m"
else
  __LOG_RESET=""
  __LOG_BLUE=""
  __LOG_GREEN=""
  __LOG_YELLOW=""
  __LOG_RED=""
fi

log_info() {
  printf "%b\n" "${__LOG_BLUE}ℹ️  ${*}${__LOG_RESET}"
}

log_time() {
  # Timestamped info line for duration tracing
  printf "%b\n" "${__LOG_BLUE}⏱️  $(date '+%H:%M:%S') - ${*}${__LOG_RESET}"
}

log_success() {
  printf "%b\n" "${__LOG_GREEN}✅ ${*}${__LOG_RESET}"
}

log_warn() {
  printf "%b\n" "${__LOG_YELLOW}⚠️  ${*}${__LOG_RESET}"
}

log_error() {
  printf "%b\n" "${__LOG_RED}❌ ${*}${__LOG_RESET}" >&2
}

log_section() {
  local title="$*"
  printf "%b\n" "${__LOG_BLUE}================================${__LOG_RESET}"
  printf "%b\n" "${__LOG_BLUE}${title}${__LOG_RESET}"
  printf "%b\n" "${__LOG_BLUE}================================${__LOG_RESET}"
}
