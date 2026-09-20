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
#   all   : no DT_RPATH / DT_RUNPATH — a runpath bakes a build-host path into
#           the shipped bytes and makes the loader search it first; installed
#           libraries resolve through ldconfig, never through the artifact
#   all   : every DT_NEEDED is on the allowlist (libc family, libsodium, liblmdb,
#           zlib, and the platform's own sonames) — an unexpected dependency
#           is a supply-chain change, not a build detail. Extend per call with
#           CHECK_HARDENING_NEEDED_EXTRA='<ERE>' when a build legitimately adds one
#   exe   : PIE (ELF type DYN + DF_1_PIE)
#   lib   : DT_SONAME present and versioned (lib<x>.so.<N>) — an unversioned
#           soname makes every consumer record an ABI-less dependency
#   ar    : (static archive input) every member is position-independent: no
#           absolute R_X86_64_32/32S relocations, so the archive links into a
#           PIE executable or a shared object on ANY toolchain
#
# SOFT checks (reported as WARN, never fail the build — presence depends on
# code shape, not on build correctness):
#   all   : __stack_chk_fail referenced   (-fstack-protector-strong took effect;
#           a tiny lib with no arrays/address-taken locals legitimately has none)
#   all   : some __*_chk fortified symbol (-D_FORTIFY_SOURCE took effect; absent
#           when every checked call was proven safe at compile time)
#   all   : no "/home/" string anywhere in the file (a build-host path leaked
#           in — debug info, __FILE__, or an embedded path); WARN because
#           debug/native profiles legitimately carry -g comp_dir strings
#   all   : .symtab absent (stripped) — informational: build_libs gates the
#           freshly linked object BEFORE strip, build_deb gates the staged one
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

# DT_NEEDED allowlist (extended regex over the soname). The platform's own
# libraries, the libc family, and the three system dependencies the release
# stack is allowed to have. Anything else must be added HERE deliberately (or
# passed per call via CHECK_HARDENING_NEEDED_EXTRA) — a NEEDED that nobody
# decided on is exactly the kind of dependency drift this gate exists for.
NEEDED_ALLOW='^(libc|libm|libpthread|libdl|librt|libgcc_s|ld-linux[^ ]*|libsodium|liblmdb|libz|libdb_[a-z]+|libDB_[a-z]+|libemlog|libspscring|libmpscring|libuuid7|libfsutil|libio_rms)\.so(\.[0-9]+)*$'
if [[ -n "${CHECK_HARDENING_NEEDED_EXTRA:-}" ]]; then
    NEEDED_ALLOW="${NEEDED_ALLOW%\$}|${CHECK_HARDENING_NEEDED_EXTRA})\.so(\.[0-9]+)*$"
    NEEDED_ALLOW="^(${NEEDED_ALLOW#^(}"
fi

# Static archive: every member object must be position-independent. An
# absolute R_X86_64_32 / R_X86_64_32S relocation means the object was compiled
# without -fPIC/-fPIE and cannot go into a PIE executable or a shared object.
check_archive() {
    local a="$1" tmp member rel bad=0 count=0 abs
    printf '%s  [archive]\n' "${a}"
    abs="$(readlink -f "${a}")"
    tmp="$(mktemp -d)"
    if ! (cd "${tmp}" && ar x "${abs}" 2>/dev/null); then
        _fail "cannot extract archive members"
        rm -rf "${tmp}"; return 0
    fi
    for member in "${tmp}"/*.o; do
        [[ -f "${member}" ]] || continue
        count=$((count + 1))
        rel="$(readelf -rW "${member}" 2>/dev/null | awk '$3 ~ /^R_X86_64_32S?$/ {print $3}' | head -1)"
        if [[ -n "${rel}" ]]; then
            _fail "$(basename "${member}"): absolute relocation ${rel} — not position-independent (compile with -fPIC)"
            bad=1
        fi
    done
    rm -rf "${tmp}"
    if (( count == 0 )); then
        _fail "archive has no object members"
    elif (( bad == 0 )); then
        _pass "all ${count} member object(s) position-independent"
    fi
}

check_file() {
    local f="$1"
    local hdr dyn segs dynsyms kind=lib

    if [[ ! -f "${f}" ]]; then
        printf '%s\n' "${f}"
        _fail "file not found"
        return 0
    fi

    # Static archives get the member-level PIC check and nothing else.
    # (7 bytes: command substitution strips the trailing newline of the 8-byte
    # ar magic; tr drops the NULs an ELF header would otherwise feed bash)
    if [[ "$(head -c 7 "${f}" 2>/dev/null | tr -d '\0')" == '!<arch>' ]]; then
        check_archive "${f}"
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

    # --- no RPATH / RUNPATH ------------------------------------------------------
    local rp
    rp="$(grep -E "\((RPATH|RUNPATH)\)" <<< "${dyn}" || true)"
    if [[ -n "${rp}" ]]; then
        _fail "$(sed -E 's/.*\((RPATH|RUNPATH)\)[[:space:]]*/\1 /' <<< "${rp}" | head -1) — drop -Wl,-rpath from the link; installed libs resolve via ldconfig"
    else
        _pass "no RPATH/RUNPATH"
    fi

    # --- DT_NEEDED allowlist -----------------------------------------------------
    local needed n unexpected=()
    needed="$(grep -E "\(NEEDED\)" <<< "${dyn}" | sed -E 's/.*\[([^]]+)\].*/\1/' || true)"
    while IFS= read -r n; do
        [[ -n "${n}" ]] || continue
        if ! [[ "${n}" =~ ${NEEDED_ALLOW} ]]; then unexpected+=("${n}"); fi
    done <<< "${needed}"
    if (( ${#unexpected[@]} > 0 )); then
        _fail "unexpected DT_NEEDED: ${unexpected[*]} — not on the allowlist (decide it, then extend NEEDED_ALLOW or CHECK_HARDENING_NEEDED_EXTRA)"
    else
        _pass "every DT_NEEDED on the allowlist"
    fi

    # --- versioned SONAME (shared libraries only) -------------------------------
    if [[ "${kind}" == "lib" ]]; then
        local soname
        soname="$(grep -E "\(SONAME\)" <<< "${dyn}" | sed -E 's/.*\[([^]]+)\].*/\1/' || true)"
        if [[ -z "${soname}" ]]; then
            _fail "no DT_SONAME — link with -Wl,-soname,lib<x>.so.<MAJOR>"
        elif ! [[ "${soname}" =~ \.so\.[0-9]+$ ]]; then
            _fail "unversioned SONAME '${soname}' — consumers would record an ABI-less dependency; use lib<x>.so.<MAJOR>"
        else
            _pass "versioned SONAME ${soname}"
        fi
    fi

    # --- soft: no build-host paths -------------------------------------------------
    if strings -a "${f}" 2>/dev/null | grep -q '/home/'; then
        _warn "'/home/' string present — a build-host path leaked in (debug comp_dir, __FILE__, or an embedded path)"
    else
        _pass "no build-host path strings"
    fi

    # --- soft: stripped ------------------------------------------------------------
    if readelf -SW "${f}" 2>/dev/null | grep -q '\.symtab'; then
        _warn "not stripped (.symtab present) — expected before build_deb's strip, unexpected in a staged deb payload"
    else
        _pass "stripped"
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
