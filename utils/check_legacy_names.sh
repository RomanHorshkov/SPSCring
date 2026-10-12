#!/usr/bin/env bash
# check_legacy_names.sh [repo-root] — refuse a pre-kyr name (legacy_names.pat beside this script, one PCRE per line) in the
# repository's text files: the tracked ones and the new unignored ones (git ls-files), never build output. One line per hit,
# then "legacy names: none" or "legacy names: found" (exit 1).
#
#   legacy_names.allow   at the root, history only, '#' comments, not read for names itself; an entry that fences nothing fails
#     history <path>        a dated record kept verbatim: every hit in it is fenced
#     line <path> <text>    one kept sentence in a live file: <text> is cut from the lines holding it, the rest is still read
#   kyr-build's wrappers in utils/, byte-identical to the pinned kyr-build's (the template stage proves it), are kyr_build's
#   text: kyr_build's own gate reads them.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${1:-${ROOT_DIR:-$(pwd -P)}}" && pwd -P)"
PAT_FILE="${SCRIPT_DIR}/legacy_names.pat"
ALLOW_FILE="${ROOT_DIR}/legacy_names.allow"
KB="${KYR_BUILD_DIR:-}"; [[ -d "${KB}/wrappers" ]] || KB="${SCRIPT_DIR}"; [[ -d "${KB}/wrappers" ]] || KB="${ROOT_DIR}/build/sysroot/share/kyr-build"
die() { printf 'check_legacy_names: %s\n' "$*" >&2; exit 2; }
[[ -f "${PAT_FILE}" ]] || die "no ${PAT_FILE}"
git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree > /dev/null 2>&1 || die "${ROOT_DIR} is not a git work tree"
RE="$(grep -vE '^[[:space:]]*(#|$)' "${PAT_FILE}" | sed 's/.*/(?:&)/' | paste -sd '|')"
[[ -n "${RE}" ]] || die "no pattern in ${PAT_FILE}"
printf '' | grep -P -- "${RE}" > /dev/null; (( $? < 2 )) || die "grep -P refuses the patterns of ${PAT_FILE}"

declare -A HISTORY=() USED=()
LINE_PATH=(); LINE_TEXT=(); LINE_KEY=()
rc=0
if [[ -f "${ALLOW_FILE}" ]]; then
    n=0
    while IFS= read -r raw || [[ -n "${raw}" ]]; do
        n=$((n + 1)); [[ "${raw}" =~ ^[[:space:]]*(#|$) ]] && continue
        read -r kind path text <<< "${raw}"
        case "${kind}" in
            history) [[ -n "${path}" && -z "${text}" ]] || { printf '  BAD     legacy_names.allow:%s: history <path>\n' "${n}"; rc=1; continue; }
                     HISTORY["${path}"]="history ${path}" ;;
            line)    [[ -n "${path}" && -n "${text}" ]] || { printf '  BAD     legacy_names.allow:%s: line <path> <text>\n' "${n}"; rc=1; continue; }
                     LINE_PATH+=("${path}"); LINE_TEXT+=("${text}"); LINE_KEY+=("line ${path} ${text}") ;;
            *)       printf '  BAD     legacy_names.allow:%s: an entry is history or line\n' "${n}"; rc=1 ;;
        esac
    done < "${ALLOW_FILE}"
fi

kyr_build_wrapper() { [[ "$1" == utils/* && "$1" != utils/*/* && -f "${KB}/wrappers/${1#utils/}" ]] && cmp -s "${KB}/wrappers/${1#utils/}" "${ROOT_DIR}/$1"; }

hits=0
while IFS= read -r -d '' path && IFS= read -r line; do
    lineno="${line%%:*}"; text="${line#*:}"
    [[ "${path}" == legacy_names.allow ]] && continue
    if [[ -n "${HISTORY[${path}]+x}" ]]; then USED["${HISTORY[${path}]}"]=1; continue; fi
    kyr_build_wrapper "${path}" && continue
    rest="${text}"
    for i in "${!LINE_PATH[@]}"; do
        [[ "${LINE_PATH[i]}" == "${path}" && "${rest}" == *"${LINE_TEXT[i]}"* ]] || continue
        rest="${rest//"${LINE_TEXT[i]}"/ }"; USED["${LINE_KEY[i]}"]=1
    done
    if [[ "${rest}" != "${text}" ]] && ! printf '%s\n' "${rest}" | grep -qP -- "${RE}"; then continue; fi
    printf '  %s:%s: %s\n' "${path}" "${lineno}" "$(printf '%s' "${text}" | sed 's/^[[:space:]]*//' | cut -c1-160)"
    hits=$((hits + 1))
done < <(cd "${ROOT_DIR}" && { git ls-files -z; git ls-files -z --others --exclude-standard; } | sort -zu |
    while IFS= read -r -d '' f; do [[ -f "${f}" && ! -L "${f}" ]] && printf '%s\0' "${f}"; done |
    xargs -0 -r grep -IPnHZ -- "${RE}")

for key in "${HISTORY[@]}" "${LINE_KEY[@]}"; do
    [[ -n "${USED[${key}]+x}" ]] || { printf '  STALE   legacy_names.allow: %s fences nothing\n' "${key}"; rc=1; }
done
(( hits )) && rc=1
(( rc == 0 )) && printf 'legacy names: none\n' || printf 'legacy names: found (%s lines)\n' "${hits}"
exit "${rc}"
