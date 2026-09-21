#!/usr/bin/env bash
# =============================================================================
# run_stress.sh — run the stress test built by build_stress.sh and keep its
# output under tests/results/stress/ (CI uploads that directory).
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
BUILD_DIR="${ROOT_DIR}/build/stress"
RESULT_DIR="${ROOT_DIR}/tests/results/stress"
cd -- "${ROOT_DIR}"

[[ -x "${BUILD_DIR}/stress_mt" ]] || { printf 'run_stress: %s missing — run build_stress.sh first\n' "${BUILD_DIR}/stress_mt" >&2; exit 1; }
mkdir -p "${RESULT_DIR}"

RESULT_FILE="${RESULT_DIR}/stress_mt_result.txt"
if "${BUILD_DIR}/stress_mt" 2>&1 | tee "${RESULT_FILE}"; then
    :
fi
rc="${PIPESTATUS[0]}"
printf 'result: %s (exit %d)\n' "${RESULT_FILE}" "${rc}"
exit "${rc}"
