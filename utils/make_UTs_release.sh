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

# Build release libraries first.
"${ROOT_DIR}/utils/make_libs.sh"

# Build unit test objects (release flags).
UT_CFLAGS=(-std=c11 -O2 -DNDEBUG -D_GNU_SOURCE -Iapp -Itests/UTs)
for src in tests/UTs/*.c; do
  out="${BUILD_DIR}/$(basename "${src%.c}").o"
  gcc "${UT_CFLAGS[@]}" -c "$src" -o "$out"
done

# Link the UT binary against the release static library.
gcc "${BUILD_DIR}"/*.o -o "${BUILD_DIR}/ut_release" build/libspscring.a -lcmocka -pthread

# Run tests.
"${BUILD_DIR}/ut_release"
