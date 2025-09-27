#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_ROOT}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_ROOT}/lib/common.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_ROOT}/lib/logging.sh"
# shellcheck source=lib/testplan.sh
source "${SCRIPT_ROOT}/lib/testplan.sh"

if [[ $# -gt 1 ]]; then
  log_error "Usage: ${BASH_SOURCE[0]} [test-suite]"
  exit 1
fi

log_warn "Direct script usage is legacy; prefer './scripts/run-xcode-tests.sh -p${1:+ ${1}}'"

verify_testplan_coverage "${1:-}"
exit $?
