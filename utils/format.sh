#!/usr/bin/env bash
# format.sh [--check] — thin wrapper: the formatter is the pinned kyr-build's (share/format.sh), never a copy in this repository.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR
for d in "${KYR_BUILD_DIR:-}" "${ROOT_DIR}/build/sysroot/share/kyr-build" /usr/local/share/kyr-build; do
    [[ -n "${d}" && -x "${d}/format.sh" ]] && exec "${d}/format.sh" "$@"
done
printf 'kyr-build not found: run ./utils/deps.sh sysroot\n' >&2
exit 1
