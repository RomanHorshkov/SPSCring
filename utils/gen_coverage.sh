#!/usr/bin/env bash
set -euo pipefail

# Generate HTML coverage for the cmocka unit tests.
# Optional env vars:
#   BUILD_DIR  - build directory (defaults to <repo>/build/coverage)
#   BUILD_TYPE - CMake build type (default Debug)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build/coverage}"
BUILD_TYPE="${BUILD_TYPE:-Debug}"
RESULT_DIR="${REPO_ROOT}/tests/results"

printf '[coverage] configuring build with instrumentation...\n'
cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DSPSCRING_BUILD_TESTS=ON \
      -DSPSCRING_ENABLE_COVERAGE=ON

printf '[coverage] cleaning previous .gcda data...\n'
find "${BUILD_DIR}" -name "*.gcda" -delete 2>/dev/null || true

printf '[coverage] building unit tests...\n'
cmake --build "${BUILD_DIR}" --target spsc_ring_unit_tests

printf '[coverage] running unit tests with instrumentation...\n'
ctest --test-dir "${BUILD_DIR}" -R spsc_ring_unit -V

mkdir -p "${RESULT_DIR}"

if command -v gcovr >/dev/null 2>&1; then
    printf '[coverage] generating reports via gcovr...\n'
    gcovr -r "${REPO_ROOT}" \
          --object-directory "${BUILD_DIR}" \
          --exclude 'tests/' \
          --html --html-details \
          -o "${RESULT_DIR}/UT_coverage.html"
    gcovr -r "${REPO_ROOT}" \
          --object-directory "${BUILD_DIR}" \
          --exclude 'tests/' \
          --xml \
          -o "${RESULT_DIR}/UT_coverage.xml"
    gcovr -r "${REPO_ROOT}" \
          --object-directory "${BUILD_DIR}" \
          --exclude 'tests/' \
          --json-summary \
          -o "${RESULT_DIR}/coverage-summary.json"
    printf '[coverage] report ready: %s/UT_coverage.html\n' "${RESULT_DIR}"
elif command -v lcov >/dev/null 2>&1 && command -v genhtml >/dev/null 2>&1; then
    printf '[coverage] generating HTML via lcov/genhtml...\n'
    INFO_FILE="${RESULT_DIR}/UT_coverage.info"
    lcov --capture --directory "${BUILD_DIR}" --output-file "${INFO_FILE}"
    lcov --remove "${INFO_FILE}" '/usr/*' 'tests/*' --output-file "${INFO_FILE}"
    genhtml "${INFO_FILE}" --output-directory "${RESULT_DIR}/UT_coverage_html"
    printf '[coverage] report ready: %s/UT_coverage_html/index.html\n' "${RESULT_DIR}"
    cat <<'JSON' > "${RESULT_DIR}/coverage-summary.json"
{"line_percent": -1, "message": "lcov run - JSON summary unavailable"}
JSON
else
    echo "[coverage] gcovr or lcov/genhtml not found. Please install one of them."
    exit 1
fi

if command -v jq >/dev/null 2>&1 && [ -f "${RESULT_DIR}/coverage-summary.json" ]; then
    COVERAGE_PCT=$(jq -r '.line_percent // .metrics.covered_percent // -1' "${RESULT_DIR}/coverage-summary.json")
else
    COVERAGE_PCT=-1
fi

printf '%s\n' "${COVERAGE_PCT}" > "${RESULT_DIR}/coverage-percent.txt"
printf '[coverage] overall line coverage: %s%%\n' "${COVERAGE_PCT}"
