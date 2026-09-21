#!/usr/bin/env bash
# =============================================================================
# format.sh — clang-format every C source and header under app/ and tests/
# with the repository's .clang-format (the canonical house style, identical in
# every sibling library).
#
#   ./utils/format.sh          rewrite files in place
#   ./utils/format.sh --check  exit non-zero if any file would change (CI gate)
#
# CLANG_FORMAT overrides the binary (CI pins a major version so the gate does
# not drift with whatever `clang-format` the runner image happens to ship).
#
# author  Roman Horshkov <github.com/RomanHorshkov>
# date    2026
# (c) 2026
# =============================================================================
set -euo pipefail

START_DIR="$(pwd -P)"
cleanup() { cd -- "${START_DIR}"; }
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd -- "${ROOT_DIR}"

CLANG_FORMAT="${CLANG_FORMAT:-clang-format}"
if ! command -v "${CLANG_FORMAT}" >/dev/null 2>&1; then
    printf 'format.sh: %s not found (apt install clang-format)\n' "${CLANG_FORMAT}" >&2
    exit 1
fi
[[ -f .clang-format ]] || { printf 'format.sh: .clang-format missing at repository root\n' >&2; exit 1; }

mapfile -t FILES < <(find app tests -type f \( -name '*.c' -o -name '*.h' \) -not -path '*/extern/*' -not -path '*/third_party/*' | sort)
if ((${#FILES[@]} == 0)); then
    printf 'format.sh: no C sources found under app/ or tests/\n' >&2
    exit 1
fi

if [[ "${1:-}" == "--check" ]]; then
    "${CLANG_FORMAT}" --style=file --dry-run -Werror "${FILES[@]}"
    printf 'format check passed: %d file(s) already canonical\n' "${#FILES[@]}"
else
    "${CLANG_FORMAT}" --style=file -i "${FILES[@]}"
    printf 'formatted %d file(s)\n' "${#FILES[@]}"
fi
