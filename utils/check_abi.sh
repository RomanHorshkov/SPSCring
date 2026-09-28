#!/usr/bin/env bash
# check_abi.sh — thin wrapper: the ABI gate is the pinned kyr-build's (share/abi/check_abi.sh), never a copy in this repository.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR
for d in "${KYR_BUILD_DIR:-}" "${ROOT_DIR}/build/sysroot/share/kyr-build" /usr/local/share/kyr-build; do
    [[ -n "${d}" && -x "${d}/abi/check_abi.sh" ]] && exec "${d}/abi/check_abi.sh" "$@"
done
printf 'kyr-build not found: run ./utils/deps.sh sysroot\n' >&2
exit 1
