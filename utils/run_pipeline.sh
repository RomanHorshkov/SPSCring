#!/usr/bin/env bash
# =============================================================================
# run_pipeline.sh — the full SPSCring pipeline, end to end
#
# author  Roman Horshkov <github.com/RomanHorshkov>
#
# Builds the library, builds+runs the release and coverage unit tests
# and the integration test, then builds the Debian package.
# It finishes by telling you EXACTLY where the .deb is, what is in it, and how
# to install it. One command:
#
#     ./utils/run_pipeline.sh
#
# ThreadSanitizer is OFF by default (it misbehaves on this host); set
# GCC_BUILD_ENABLE_TSAN=1 to add the tsan profile where profiles apply.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd -- "${ROOT_DIR}"

PKG_LABEL="SPSCring"

# shellcheck source=/dev/null
[ -f "${SCRIPT_DIR}/gcc_build_profiles.sh" ] && source "${SCRIPT_DIR}/gcc_build_profiles.sh"

# =============================================================================
# Shared pipeline machinery (identical across every repo's run_pipeline.sh)
# =============================================================================
LOG_DIR="${ROOT_DIR}/build/pipeline"
mkdir -p "${LOG_DIR}"

c_bold=$'\033[1m'; c_grn=$'\033[32m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'
declare -a RESULTS=()
FAILED=0

# stage <label> <cmd...> : run, tee to a log, record PASS/FAIL, keep going.
stage() {
    local label="$1"; shift
    local log="${LOG_DIR}/${label//[^A-Za-z0-9_.-]/_}.log"
    printf '\n%s== [%s] %s ==%s\n' "${c_bold}" "${PKG_LABEL}" "${label}" "${c_rst}"
    printf '%s  $ %s%s\n' "${c_dim}" "$*" "${c_rst}"
    local rc
    "$@" 2>&1 | tee "${log}"; rc=$?
    if (( rc == 0 )); then
        printf '%s  ✓ %s%s  (%s)\n' "${c_grn}" "${label}" "${c_rst}" "${log}"
        RESULTS+=("PASS|${label}|${rc}")
    else
        printf '%s  ✗ %s (exit %d)%s  → %s\n' "${c_red}" "${label}" "${rc}" "${c_rst}" "${log}"
        tail -n 15 "${log}" | sed 's/^/      /'
        RESULTS+=("FAIL|${label}|${rc}")
        FAILED=1
    fi
    return 0
}

# Print where the produced .deb(s) are, their metadata, and how to install them.
report_debs() {
    shopt -s nullglob
    local all=( "${ROOT_DIR}"/build/debs/*.deb "${ROOT_DIR}"/build/deb/*.deb )
    shopt -u nullglob
    printf '\n%s== Debian package(s) ==%s\n' "${c_bold}" "${c_rst}"
    if (( ${#all[@]} == 0 )); then
        printf '%s  no .deb produced (see the package stage log above)%s\n' "${c_red}" "${c_rst}"
        return 1
    fi
    # Keep only the NEWEST file per package name (a stale older version may linger
    # in build/debs from a previous run — never point the user at it).
    declare -A newest=()
    local f pkg
    for f in "${all[@]}"; do
        pkg="$(dpkg-deb -f "${f}" Package 2>/dev/null)" || continue
        [[ -z "${pkg}" ]] && continue
        if [[ -z "${newest[${pkg}]:-}" || "${f}" -nt "${newest[${pkg}]}" ]]; then newest[${pkg}]="${f}"; fi
    done
    local d
    for d in "${newest[@]}"; do
        printf '\n%s  %s%s\n' "${c_bold}" "${d}" "${c_rst}"
        printf '    size:    %s\n' "$(du -h "${d}" | cut -f1)"
        dpkg-deb -f "${d}" Package Version Architecture Depends Description 2>/dev/null | sed 's/^/    /'
        printf '    files:   %s payload path(s)\n' "$(dpkg-deb -c "${d}" 2>/dev/null | grep -cE '[^/]$')"
        printf '    install: %ssudo apt-get install ./%s%s\n' "${c_bold}" "$(basename "${d}")" "${c_rst}"
    done
    printf '\n  Across the platform, install every built deb in dependency order with:\n'
    printf '    sudo bash install/packages/install-all.sh --skip-apt --only %s\n' "${PKG_LABEL}"
    return 0
}

printf '%s\u2554\u2550\u2550 %s pipeline \u2550\u2550\u2550\u2550%s\n' "${c_bold}" "${PKG_LABEL}" "${c_rst}"

stage "build"          bash "${SCRIPT_DIR}/build_libs.sh"
stage "unit-tests-release" bash "${SCRIPT_DIR}/make_UTs_release.sh"
stage "unit-tests-coverage" bash "${SCRIPT_DIR}/make_UTs_cov.sh"
stage "integration-tests"  bash "${SCRIPT_DIR}/make_ITs.sh"
stage "sanitizer-tests"    bash "${SCRIPT_DIR}/make_sanitizer_tests.sh"
stage "package"        bash "${SCRIPT_DIR}/build_deb.sh"

report_debs || FAILED=1

# --- summary -----------------------------------------------------------------
printf '\n%s== pipeline summary (%s) ==%s\n' "${c_bold}" "${PKG_LABEL}" "${c_rst}"
for r in "${RESULTS[@]}"; do
    IFS='|' read -r st label rc <<<"${r}"
    if [[ "${st}" == PASS ]]; then printf '  %s✓%s %-26s\n' "${c_grn}" "${c_rst}" "${label}"
    else printf '  %s✗%s %-26s exit=%s\n' "${c_red}" "${c_rst}" "${label}" "${rc}"; fi
done
if (( FAILED )); then printf '\n%s✗ pipeline FAILED%s\n' "${c_red}" "${c_rst}"; exit 1; fi
printf '\n%s✓ pipeline GREEN%s\n' "${c_grn}" "${c_rst}"
