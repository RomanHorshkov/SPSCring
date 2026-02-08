#!/usr/bin/env bash
set -euo pipefail

# SET THE SCRIPT TO GO INTO DESIRED FOLDER AND COME BACK FROM WHERE LAUNCHED.
START_DIR="$(pwd -P)"
cleanup() { cd -- "$START_DIR"; }
trap cleanup EXIT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$ROOT_DIR"

BUILD_DIR="${ROOT_DIR}/build/ITs"

mkdir -p "$BUILD_DIR"

# Build spscring object (integration tests link against this object).
gcc -std=c11 -O2 -g -Iapp -c app/spscring.c -o "${BUILD_DIR}/spscring.o"

# Build integration test objects.
IT_CFLAGS=(-std=c11 -O2 -g -D_GNU_SOURCE -Iapp -Itests/ITs)
for src in tests/ITs/*.c; do
  out="${BUILD_DIR}/$(basename "${src%.c}").o"
  gcc "${IT_CFLAGS[@]}" -c "$src" -o "$out"
done

# Link the IT binary.
gcc "${BUILD_DIR}"/*.o -o "${BUILD_DIR}/it" -lcmocka -pthread

# Run tests.
"${BUILD_DIR}/it"
