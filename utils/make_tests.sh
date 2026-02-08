#!/usr/bin/env bash
set -euo pipefail

# SET THE SCRIPT TO GO INTO DESIRED FOLDER AND COME BACK FROM WHERE LAUNCHED.
START_DIR="$(pwd -P)"
cleanup() { cd -- "$START_DIR"; }
trap cleanup EXIT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$ROOT_DIR"

BUILD_DIR="${ROOT_DIR}/build/UTs"
RESULT_DIR="${ROOT_DIR}/tests/results/UTs"

mkdir -p "$BUILD_DIR" "$RESULT_DIR"

# Clean previous coverage data (otherwise gcov/gcovr can fail with stamp mismatches).
rm -f "${BUILD_DIR}"/*.gcda "${BUILD_DIR}"/*.gcno "${BUILD_DIR}"/*.gcov 2>/dev/null || true

# Build spscring object with coverage (public tests link against this object).
gcc -std=c11 -O0 -g --coverage -Iapp -c app/spscring.c -o "${BUILD_DIR}/spscring.o"

# Build unit test objects.
UT_CFLAGS=(-std=c11 -O0 -g --coverage -D_GNU_SOURCE -Iapp -Itests/UTs)
for src in tests/UTs/*.c; do
  out="${BUILD_DIR}/$(basename "${src%.c}").o"
  gcc "${UT_CFLAGS[@]}" -c "$src" -o "$out"
done

# Link the public UT binary.
gcc --coverage "${BUILD_DIR}"/*.o -o "${BUILD_DIR}/ut" -lcmocka -pthread

# Run tests to generate fresh .gcda files.
"${BUILD_DIR}/ut"

# generate coverage
if ! command -v gcovr >/dev/null 2>&1; then
    echo "gcovr not found."
    exit 1
fi

gcovr -r "${ROOT_DIR}" \
    --object-directory "${BUILD_DIR}" \
    --exclude 'tests/' \
    --html --html-details \
    -o "${RESULT_DIR}/UTs_public_coverage.html"
gcovr -r "${ROOT_DIR}" \
    --object-directory "${BUILD_DIR}" \
    --exclude 'tests/' \
    --xml \
    -o "${RESULT_DIR}/UTs_public_coverage.xml"
gcovr -r "${ROOT_DIR}" \
    --object-directory "${BUILD_DIR}" \
    --exclude 'tests/' \
    --json-summary \
    -o "${RESULT_DIR}/coverage-summary.json"

printf 'report ready: %s\n' "${RESULT_DIR}/UTs_public_coverage.html"
