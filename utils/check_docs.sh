#!/usr/bin/env bash
# check_docs.sh — the documents say what the code does; a repository gate the pipeline runs among its checks (KYR_PIPELINE_EXTRA).
#   1. Doxygen over the public header, every warning an error: a @file, @param or @ref naming what is not there fails. Without doxygen
#      on the machine (the release build root has none) this part prints SKIP and the rest still runs.
#   2. README.md's API contract, compiled and run against app/spscring.c: each "- `spsc_ring_<f>(NULL…)` returns `<v>`." line is one
#      check of the value, each "- `spsc_ring_<f>(NULL)` is a no-op." line one call; every function the header declares but
#      spsc_ring_init must have its line, so the list cannot fall behind the header.
#   3. README.md's wrap times: each "- At <r> ops/s, a `uint<N>_t` counter wraps in about <t> <unit>." line within 1 % of 2^N / r.
# Exit 1 on any failure, each one named.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
HEADER="app/spscring.h"
README="README.md"
WORK="build/docs"
rm -rf "${WORK}"; mkdir -p "${WORK}"
FAILED=0
fail() { printf 'check_docs: %s\n' "$*" >&2; FAILED=1; }

# 1. Doxygen
if command -v doxygen > /dev/null; then
    if ! printf '%s\n' "INPUT = ${HEADER}" "OUTPUT_DIRECTORY = ${WORK}/doxygen" "OPTIMIZE_OUTPUT_FOR_C = YES" "GENERATE_HTML = NO" \
        "GENERATE_LATEX = NO" "GENERATE_XML = YES" "QUIET = YES" "WARNINGS = YES" "WARN_IF_UNDOCUMENTED = YES" "WARN_IF_DOC_ERROR = YES" \
        "WARN_IF_INCOMPLETE_DOC = YES" "WARN_NO_PARAMDOC = YES" "WARN_AS_ERROR = FAIL_ON_WARNINGS" | doxygen - > "${WORK}/doxygen.log" 2>&1; then
        sed 's/^/  /' "${WORK}/doxygen.log" >&2
        fail "doxygen warns on ${HEADER} (above)"
    else
        printf 'check_docs: doxygen %s over %s: no warning\n' "$(doxygen --version)" "${HEADER}"
    fi
else
    printf 'check_docs: SKIP doxygen (not installed); the README checks still run\n'
fi

# 2. The API contract of README.md, as a program
PROBE="${WORK}/readme_contract.c"
declare -A LISTED=()
{
    printf '#include <stddef.h>\n#include <stdio.h>\n\n#include "spscring.h"\n\nint main(void)\n{\n    int bad = 0;\n'
    while IFS= read -r line; do
        if [[ "${line}" =~ ^-\ \`(spsc_ring_[a-z_]+)\(NULL(,\ \.\.\.)?\)\`\ returns\ \`(-?[0-9]+)\`\.$ ]]; then
            f="${BASH_REMATCH[1]}"; args="NULL${BASH_REMATCH[2]:+, 0}"; want="${BASH_REMATCH[3]}"; LISTED["${f}"]=1
            printf '    if((long long)%s(%s) != %sLL)\n    {\n' "${f}" "${args}" "${want}"
            printf '        fprintf(stderr, "README.md: %s(%s) returns %s; the code returns %%lld\\n", (long long)%s(%s));\n' \
                "${f}" "${args}" "${want}" "${f}" "${args}"
            printf '        bad = 1;\n    }\n'
        elif [[ "${line}" =~ ^-\ \`(spsc_ring_[a-z_]+)\(NULL\)\`\ is\ a\ no-op\.$ ]]; then
            f="${BASH_REMATCH[1]}"; LISTED["${f}"]=1
            printf '    %s(NULL);\n' "${f}"
        fi
    done < "${README}"
    printf '    return bad;\n}\n'
} > "${PROBE}"
mapfile -t DECLARED < <(grep -oE '^[a-z_0-9]+[ *]+spsc_ring_[a-z_]+\(' "${HEADER}" | sed -E 's/.*(spsc_ring_[a-z_]+)\($/\1/' | sort -u)
(( ${#DECLARED[@]} )) || fail "no function declaration found in ${HEADER}"
for f in "${DECLARED[@]}"; do
    [[ "${f}" == spsc_ring_init || -n "${LISTED[${f}]:-}" ]] || fail "README.md's API contract does not say what ${f}(NULL) does"
done
if ! "${CC:-cc}" -std=c11 -Wall -Wextra -Werror -Iapp app/spscring.c "${PROBE}" -o "${WORK}/readme_contract" > "${WORK}/cc.log" 2>&1; then
    sed 's/^/  /' "${WORK}/cc.log" >&2
    fail "the README contract probe (${PROBE}) does not build"
elif ! "${WORK}/readme_contract"; then
    fail "README.md's API contract disagrees with the code (above)"
else
    printf 'check_docs: README.md API contract: %s functions, as the code does\n' "${#LISTED[@]}"
fi

# 3. The wrap times of README.md
WRAPS=0
while IFS= read -r line; do
    [[ "${line}" =~ ^-\ At\ ([0-9,]+)\ ops/s,\ a\ \`uint([0-9]+)_t\`\ counter\ wraps\ in\ about\ ([0-9,.]+)\ (seconds|minutes|hours|days|years)\.$ ]] ||
        continue
    WRAPS=$((WRAPS + 1))
    rate="${BASH_REMATCH[1]//,/}"; bits="${BASH_REMATCH[2]}"; said="${BASH_REMATCH[3]//,/}"; unit="${BASH_REMATCH[4]}"
    if ! verdict="$(awk -v r="${rate}" -v n="${bits}" -v t="${said}" -v u="${unit}" 'BEGIN {
            s = (u == "seconds") ? 1 : (u == "minutes") ? 60 : (u == "hours") ? 3600 : (u == "days") ? 86400 : 31557600
            v = 2 ^ n / r / s
            printf "%.4g %s", v, u
            exit (t >= v * 0.99 && t <= v * 1.01) ? 0 : 1 }')"; then
        fail "README.md: a uint${bits}_t counter at ${rate} ops/s wraps in about ${verdict}, not ${said} ${unit}"
    fi
done < "${README}"
(( WRAPS )) || fail "README.md: no wrap-time line found"

(( FAILED )) && exit 1
printf 'check_docs: %s, %s and %s wrap times agree with the code\n' "${HEADER}" "${README}" "${WRAPS}"
