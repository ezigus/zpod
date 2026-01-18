#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_ROOT}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_ROOT}/lib/common.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_ROOT}/lib/logging.sh"
# shellcheck source=lib/result.sh
source "${SCRIPT_ROOT}/lib/result.sh"
# shellcheck source=lib/xcode.sh
source "${SCRIPT_ROOT}/lib/xcode.sh"
# shellcheck source=lib/spm.sh
source "${SCRIPT_ROOT}/lib/spm.sh"
# shellcheck source=lib/testplan.sh
source "${SCRIPT_ROOT}/lib/testplan.sh"
# shellcheck source=lib/harness.sh
source "${SCRIPT_ROOT}/lib/harness.sh"

harness_main "$@"
