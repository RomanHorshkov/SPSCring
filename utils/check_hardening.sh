#!/usr/bin/env bash
# =============================================================================
# check_hardening.sh
#
# author  Roman Horshkov <github.com/RomanHorshkov>
# date    2026
# (c) 2026
# =============================================================================
#
# Assert that built ELF artifacts actually carry the hardening the release
# profile promises. Flags drift silently (stale profile copies, scripts that
# never adopted the catalog, a stray asm object) — this script turns drift
# into a loud red build, same philosophy as the fs_expect permission checks.
#
# Usage:
#   check_hardening.sh <elf> [<elf> ...]
#
# File kind is auto-detected:
#   shared library : ELF DYN with a DT_SONAME (or no PT_INTERP)
#   executable     : ELF with PT_INTERP (dynamic exe) or DF_1_PIE
#
# HARD checks (any failure => exit 2, fail the build):
#   all   : GNU_STACK segment present and NOT executable
#   all   : GNU_RELRO segment present
#   all   : immediate binding (DT_BIND_NOW / DF_BIND_NOW / DF_1_NOW)
#   all   : no TEXTREL (writable code relocations)
#   exe   : PIE (ELF type DYN + DF_1_PIE)
#
# SOFT checks (reported as WARN, never fail the build — presence depends on
# code shape, not on build correctness):
#   all   : __stack_chk_fail referenced   (-fstack-protector-strong took effect;
#           a tiny lib with no arrays/address-taken locals legitimately has none)
#   all   : some __*_chk fortified symbol (-D_FORTIFY_SOURCE took effect; absent
#           when every checked call was proven safe at compile time)
#
# Exit codes: 0 all hard checks pass; 2 at least one hard failure; 3 usage.
# =============================================================================
set -euo pipefail

if (($# < 1)); then
    printf 'usage: %s <elf> [<elf> ...]\n' "$0" >&2
    exit 3
fi

FAILURES=0

_fail() { printf '  \342\234\227 %s\n' "$1"; FAILURES=$((FAILURES + 1)); }
_pass() { printf '  \342\234\223 %s\n' "$1"; }
_warn() { printf '  ! %s (WARN)\n' "$1"; }

check_file() {
    local f="$1"
    local hdr dyn segs dynsyms kind=lib

    if [[ ! -f "${f}" ]]; then
        printf '%s\n' "${f}"
        _fail "file not found"
        return 0
    fi

    hdr="$(readelf -hW "${f}" 2>/dev/null)" || { printf '%s\n' "${f}"; _fail "not an ELF file"; return 0; }
    dyn="$(readelf -dW "${f}" 2>/dev/null || true)"
    segs="$(readelf -lW "${f}" 2>/dev/null || true)"
    dynsyms="$(readelf -sW "${f}" 2>/dev/null || true)"

    # --- kind detection ------------------------------------------------------
    if grep -q "INTERP" <<< "${segs}" || grep -q "Flags: .*PIE" <<< "${dyn}"; then
        kind=exe
    fi
    printf '%s  [%s]\n' "${f}" "${kind}"

    # --- GNU_STACK: present, not executable ----------------------------------
    local stack_line
    stack_line="$(grep "GNU_STACK" <<< "${segs}" || true)"
    if [[ -z "${stack_line}" ]]; then
        _fail "no GNU_STACK segment (stack executability is unspecified)"
    elif grep -qE "RW?E" <<< "${stack_line}"; then
        _fail "executable stack (GNU_STACK has E) — link with -Wl,-z,noexecstack and find the offending object"
    else
        _pass "non-executable stack"
    fi

    # --- GNU_RELRO ------------------------------------------------------------
    if grep -q "GNU_RELRO" <<< "${segs}"; then
        _pass "GNU_RELRO segment present"
    else
        _fail "no GNU_RELRO segment — link with -Wl,-z,relro"
    fi

    # --- immediate binding (full RELRO) ---------------------------------------
    if grep -qE "BIND_NOW|\(FLAGS_1\).*NOW|\(FLAGS\).*BIND_NOW" <<< "${dyn}"; then
        _pass "immediate binding (full RELRO)"
    else
        _fail "lazy binding — link with -Wl,-z,now (partial RELRO leaves the GOT writable)"
    fi

    # --- TEXTREL ----------------------------------------------------------------
    if grep -qE "TEXTREL" <<< "${dyn}"; then
        _fail "TEXTREL present (writable code relocations) — objects missing -fPIC/-fPIE"
    else
        _pass "no TEXTREL"
    fi

    # --- PIE (executables only) ------------------------------------------------
    if [[ "${kind}" == "exe" ]]; then
        if grep -q "Type:[[:space:]]*DYN" <<< "${hdr}" && grep -qE "\(FLAGS_1\).*PIE" <<< "${dyn}"; then
            _pass "PIE executable (ASLR applies to the image)"
        else
            _fail "not a PIE — compile with -fPIE, link with -pie"
        fi
    fi

    # --- soft: stack canaries ---------------------------------------------------
    if grep -q "__stack_chk_fail" <<< "${dynsyms}"; then
        _pass "stack canaries referenced"
    else
        _warn "no __stack_chk_fail reference — no protected frames (fine for tiny libs) or missing -fstack-protector-strong"
    fi

    # --- soft: fortified libc calls ----------------------------------------------
    if grep -qE "__[a-z_]+_chk" <<< "${dynsyms}"; then
        _pass "fortified libc calls present"
    else
        _warn "no __*_chk symbols — all checked calls proven safe, no fortifiable calls, or missing -D_FORTIFY_SOURCE"
    fi
}

for f in "$@"; do
    check_file "${f}"
    printf '\n'
done

if ((FAILURES > 0)); then
    printf 'check_hardening: %d HARD failure(s)\n' "${FAILURES}" >&2
    exit 2
fi
printf 'check_hardening: all hard checks passed (%d file(s))\n' "$#"
