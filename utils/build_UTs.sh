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

# Coverage is measured across UTs AND ITs against the SAME instrumented spscring.o (linked
# into both binaries, run back to back — gcov accumulates counts additively across multiple
# runs of the same .gcno/.gcda pair), so the threaded integration flow counts toward the gate
# exactly as in MPSCring.
# Atomic profile updates keep concurrent gcov counters valid; parse errors are real failures.
COVERAGE_FLAGS=(--coverage -fprofile-update=atomic)

gcc -std=c11 -O0 -g "${COVERAGE_FLAGS[@]}" -DSPSC_RING_TESTING -Iapp -Itests/UTs \
    -c app/spscring.c -o "${BUILD_DIR}/spscring.o"

# Build unit test objects.
UT_CFLAGS=(-std=c11 -O0 -g "${COVERAGE_FLAGS[@]}" -D_GNU_SOURCE -DSPSC_RING_TESTING -Iapp -Itests/UTs)
for src in tests/UTs/*.c; do
  out="${BUILD_DIR}/$(basename "${src%.c}").o"
  gcc "${UT_CFLAGS[@]}" -c "$src" -o "$out"
done

# Build integration test objects (public API only, no test hooks).
IT_CFLAGS=(-std=c11 -O0 -g "${COVERAGE_FLAGS[@]}" -D_GNU_SOURCE -Iapp -Itests/ITs)
for src in tests/ITs/*.c; do
  out="${BUILD_DIR}/it_$(basename "${src%.c}").o"
  gcc "${IT_CFLAGS[@]}" -c "$src" -o "$out"
done

# Link the UT binary (spscring.o + tests/UTs/*.o) and the IT binary (spscring.o +
# tests/ITs/*.o) SEPARATELY, but both against the SAME spscring.o — so both runs' .gcda
# output accumulates onto the one set of counters for app/spscring.c.
UT_OBJECTS=("${BUILD_DIR}/spscring.o")
for src in tests/UTs/*.c; do UT_OBJECTS+=("${BUILD_DIR}/$(basename "${src%.c}").o"); done
gcc "${COVERAGE_FLAGS[@]}" "${UT_OBJECTS[@]}" -o "${BUILD_DIR}/ut" -lcmocka -pthread

IT_OBJECTS=("${BUILD_DIR}/spscring.o")
for src in tests/ITs/*.c; do IT_OBJECTS+=("${BUILD_DIR}/it_$(basename "${src%.c}").o"); done
gcc "${COVERAGE_FLAGS[@]}" "${IT_OBJECTS[@]}" -o "${BUILD_DIR}/it" -lcmocka -pthread

# Run both to generate fresh (additively-merged) .gcda files.
"${BUILD_DIR}/ut"
"${BUILD_DIR}/it"

# generate coverage
if ! command -v gcovr >/dev/null 2>&1; then
    echo "gcovr not found."
    exit 1
fi

gcovr -r "${ROOT_DIR}" \
    --object-directory "${BUILD_DIR}" \
    --exclude 'tests/' \
    --html --html-details \
    -o "${RESULT_DIR}/UTs_coverage.html"
gcovr -r "${ROOT_DIR}" \
    --object-directory "${BUILD_DIR}" \
    --exclude 'tests/' \
    --xml \
    -o "${RESULT_DIR}/UTs_coverage.xml"
gcovr -r "${ROOT_DIR}" \
    --object-directory "${BUILD_DIR}" \
    --exclude 'tests/' \
    --json-summary \
    --fail-under-line 100 \
    --fail-under-branch 100 \
    -o "${RESULT_DIR}/coverage-summary.json"

printf '100%% line and branch coverage gate passed; report ready: %s\n' "${RESULT_DIR}/UTs_coverage.html"
