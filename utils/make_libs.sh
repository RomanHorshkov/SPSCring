#!/usr/bin/env bash
# =============================================================================
# make_libs.sh — DEPRECATED wrapper, kept for old callers
#
# author  Roman Horshkov <github.com/RomanHorshkov>
# date    2026
# (c) 2026
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf 'make_libs.sh is deprecated → build_libs.sh\n' >&2
exec "${SCRIPT_DIR}/build_libs.sh" "$@"
