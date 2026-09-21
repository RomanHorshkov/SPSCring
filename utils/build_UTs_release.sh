#!/usr/bin/env bash
set -euo pipefail

# SET THE SCRIPT TO GO INTO DESIRED FOLDER AND COME BACK FROM WHERE LAUNCHED.
START_DIR="$(pwd -P)"
cleanup() { cd -- "$START_DIR"; }
trap cleanup EXIT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$ROOT_DIR"

BUILD_DIR="${ROOT_DIR}/build/UTs_release"

mkdir -p "$BUILD_DIR"

# Build release libraries first (flat build/libspscring.a is a symlink into
# build/release/ maintained by build_libs.sh).
"${ROOT_DIR}/utils/build_libs.sh" release

# Build unit test objects (release flags).
# Deliberately NOT -DNDEBUG: unit_tests.c's checks are plain assert() calls, so NDEBUG would
# silently turn every one of them into a no-op — the binary would print "ALL UNIT TESTS
# PASSED" regardless of whether anything actually passed. The LIBRARY under test is still the
# release-profile build (via build_libs.sh above); only the test harness itself must never
# disable its own assertions.
UT_CFLAGS=(-std=c11 -O2 -D_GNU_SOURCE -Iapp -Itests/UTs)
for src in tests/UTs/*.c; do
  out="${BUILD_DIR}/$(basename "${src%.c}").o"
  gcc "${UT_CFLAGS[@]}" -c "$src" -o "$out"
done

# Link the UT binary against the release static library.
gcc "${BUILD_DIR}"/*.o -o "${BUILD_DIR}/ut_release" build/libspscring.a -lcmocka -pthread

# Run tests.
"${BUILD_DIR}/ut_release"
