#!/usr/bin/env bash
# gcc_build_profiles.sh — thin wrapper: the catalog is the pinned kyr-build's (deps.txt), never a copy in this repository.
# Sourced: loads it. Executed: runs its CLI (explain | print-cppflags|print-cflags|print-ldflags <profile>).
_kyr_build_dir() {
    local root d
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    for d in "${KYR_BUILD_DIR:-}" "${root}/build/sysroot/share/kyr-build" /usr/local/share/kyr-build; do
        [[ -n "${d}" && -f "${d}/gcc_build_profiles.sh" ]] && { printf '%s\n' "${d}"; return 0; }
    done
    printf 'kyr-build not found: run ./utils/deps.sh sysroot\n' >&2
    return 1
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    _d="$(_kyr_build_dir)" || exit 1
    ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" exec bash "${_d}/gcc_build_profiles.sh" "$@"
fi
KYR_BUILD_DIR="$(_kyr_build_dir)" || return 1
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=/dev/null
source "${KYR_BUILD_DIR}/gcc_build_profiles.sh"
