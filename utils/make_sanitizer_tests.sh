#!/usr/bin/env bash
# Build and run the unit and integration suites under ASan, UBSan, and LSan.
set -euo pipefail

START_DIR="$(pwd -P)"
cleanup() { cd -- "${START_DIR}"; }
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/sanitizers"
cd -- "${ROOT_DIR}"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/gcc_build_profiles.sh"

mkdir -p "${BUILD_DIR}"

# The test-only allocation and lock-free seams exercise init failure cleanup as
# well as normal behavior. They are never part of a production library.
SANITIZE_CPPFLAGS=(
    "${CPPFLAGS_SANITIZE[@]}"
    -DSPSC_REQUIRE_ALWAYS_LOCK_FREE
    -DSPSC_RING_TESTING
    -Iapp
    -Itests/UTs
)
SANITIZE_CFLAGS=("${CFLAGS_SANITIZE[@]}")
SANITIZE_LDFLAGS=("${LDFLAGS_SANITIZE[@]}")

build_binary() {
    local suite_name="$1"
    local source_dir="$2"
    local output_name="$3"
    local test_include="$4"
    local objects=("${BUILD_DIR}/spscring_${suite_name}.o")
    local source output

    gcc "${SANITIZE_CPPFLAGS[@]}" "${SANITIZE_CFLAGS[@]}" -c app/spscring.c -o "${objects[0]}"

    for source in "${source_dir}"/*.c; do
        output="${BUILD_DIR}/${suite_name}_$(basename "${source%.c}").o"
        gcc "${SANITIZE_CPPFLAGS[@]}" "${SANITIZE_CFLAGS[@]}" -I"${test_include}" -c "${source}" -o "${output}"
        objects+=("${output}")
    done

    gcc "${objects[@]}" -o "${BUILD_DIR}/${output_name}" "${SANITIZE_LDFLAGS[@]}" -lcmocka -pthread
}

run_sanitized() {
    env ASAN_OPTIONS="detect_leaks=1:halt_on_error=1" UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1" LSAN_OPTIONS="exitcode=1" "$@"
}

build_binary "ut" "tests/UTs" "ut_sanitized" "tests/UTs"
build_binary "it" "tests/ITs" "it_sanitized" "tests/ITs"

run_sanitized "${BUILD_DIR}/ut_sanitized"
run_sanitized "${BUILD_DIR}/it_sanitized"
