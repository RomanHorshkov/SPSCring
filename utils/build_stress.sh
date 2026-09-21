#!/usr/bin/env bash
# =============================================================================
# build_stress.sh — build the producer/consumer stress test against the release
# static library. Runs nothing; run_stress.sh executes it and records results.
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
cd -- "${ROOT_DIR}"

source "${SCRIPT_DIR}/gcc_build_profiles.sh"
mkdir -p "${BUILD_DIR}"

# Same release profile the shipped library is built with; the stress test links the
# release static archive so it exercises the exact code that gets packaged.
"${SCRIPT_DIR}/build_libs.sh" release

gcc "${CPPFLAGS_RELEASE[@]}" -DSPSC_REQUIRE_ALWAYS_LOCK_FREE -D_GNU_SOURCE -Iapp \
    "${CFLAGS_RELEASE[@]}" -c tests/stress/stress_mt.c -o "${BUILD_DIR}/stress_mt.o"
gcc "${LDFLAGS_RELEASE[@]}" "${BUILD_DIR}/stress_mt.o" build/release/libspscring.a \
    -o "${BUILD_DIR}/stress_mt" -pthread

printf 'built %s\n' "${BUILD_DIR}/stress_mt"
