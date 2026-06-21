#!/usr/bin/env bash
#
# Local unit tests for the install script's pure functions.
#
# SAFE BY DESIGN: this only extracts and sources the functions
# (_log, validate_governor, get_wifi_credentials) from the installer and runs
# them against temporary fixtures. It never executes the installer body, apt,
# any omv-* command, network reconfiguration, or a reboot.
#
# Usage: tests/run.sh [path-to-install]   (defaults to ../install)

set -u
cd "$(dirname "$0")" || exit 1

INSTALL="${1:-../install}"
if [ ! -f "${INSTALL}" ]; then
  echo "install script not found: ${INSTALL}" >&2
  exit 2
fi

# shellcheck source=tests/lib.sh
source ./lib.sh

FUNCS_FILE="$(mktemp)"
trap 'rm -f "${FUNCS_FILE}"' EXIT
extract_functions "${INSTALL}" "${FUNCS_FILE}" _log validate_governor get_wifi_credentials
# shellcheck disable=SC1090
source "${FUNCS_FILE}"

for t in test_*.sh; do
  printf '# %s\n' "${t}"
  # shellcheck disable=SC1090
  source "./${t}"
done

summary
