#!/usr/bin/env bash
# check_hardening.sh — thin wrapper: the gate is the pinned kyr-build's (deps.txt), never a copy in this repository.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for d in "${KYR_BUILD_DIR:-}" "${ROOT_DIR}/build/sysroot/share/kyr-build" /usr/local/share/kyr-build; do
    [[ -n "${d}" && -x "${d}/check_hardening.sh" ]] && exec "${d}/check_hardening.sh" "$@"
done
printf 'kyr-build not found: run ./utils/deps.sh sysroot\n' >&2
exit 1
