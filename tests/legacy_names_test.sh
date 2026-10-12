#!/usr/bin/env bash
# legacy_names_test.sh — the legacy-names gate (utils/check_legacy_names.sh) on a copy of this repository's tree: the copy passes,
# a pre-kyr name planted in a tracked file or in a new file is refused at its line, an allow entry that fences nothing is refused.
# The planted names are spelled in two pieces, so this file passes the gate itself.
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT_DIR}/utils/check_legacy_names.sh"
export KYR_BUILD_DIR="${KYR_BUILD_DIR:-${ROOT_DIR}/build/sysroot/share/kyr-build}"   # the pinned wrappers, for the copy
[[ -x "${CHECK}" ]] || { printf 'FAIL no executable %s\n' "${CHECK}"; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/legacy_names_test.XXXXXX")"; trap 'rm -rf "${WORK}"' EXIT
T="${WORK}/t"; mkdir -p "${T}"
fails=0
ok() { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; fails=$((fails + 1)); }
expect() { # <exit> <what> [text the output must hold]
    local want="$1" what="$2" text="${3:-}" out rc=0
    out="$("${CHECK}" "${T}" 2>&1)" || rc=$?
    if (( rc == want )) && { [[ -z "${text}" ]] || grep -qF -- "${text}" <<< "${out}"; }; then ok "${what}"
    else printf '%s\n' "${out}" | sed 's/^/       /'; bad "${what} (exit ${rc}, want ${want})"; fi
}

( cd "${ROOT_DIR}" && { git ls-files -z; git ls-files -z --others --exclude-standard; } | sort -zu |
    while IFS= read -r -d '' f; do [[ -f "${f}" || -L "${f}" ]] && printf '%s\0' "${f}"; done | tar --null -T - -cf - ) | tar -xf - -C "${T}"
git -C "${T}" init -q && git -C "${T}" add -A -f || { printf 'FAIL cannot stage the copy\n'; exit 1; }
expect 0 "the tree as it is passes"

printf '\nThe %s answers here.\n' "D""B_server" >> "${T}/README.md"
expect 1 "a name planted in a tracked file is refused at its line" "README.md:$(wc -l < "${T}/README.md"):"
git -C "${T}" checkout -q -- README.md

printf '%s=1\n' "H""S_DOMAIN" > "${T}/planted.env"
expect 1 "a name in a new, unstaged file is refused" "planted.env:1:"
rm -f "${T}/planted.env"

printf 'history no/such/record.md\n' >> "${T}/legacy_names.allow"
expect 1 "an allow entry that fences nothing is refused" "history no/such/record.md fences nothing"

(( fails == 0 )) && { printf 'legacy names test: GREEN\n'; exit 0; }
printf 'legacy names test: %s failed\n' "${fails}"; exit 1
