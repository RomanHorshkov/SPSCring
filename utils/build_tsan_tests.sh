#!/usr/bin/env bash
# Build and run the public integration suite and a reduced stress workload under TSan.
set -euo pipefail

START_DIR="$(pwd -P)"
cleanup() { cd -- "${START_DIR}"; }
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/tsan"
cd -- "${ROOT_DIR}"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/gcc_build_profiles.sh"
mkdir -p "${BUILD_DIR}"

TSAN_CPPFLAGS=(
    "${CPPFLAGS_TSAN[@]}"
    -DSPSC_REQUIRE_ALWAYS_LOCK_FREE
    -D_GNU_SOURCE
    -Iapp
    -DN_ITEMS=200000
)
TSAN_CFLAGS=("${CFLAGS_TSAN[@]}" -fno-pie)
TSAN_LDFLAGS=("${LDFLAGS_TSAN[@]}" -no-pie)

gcc "${TSAN_CPPFLAGS[@]}" "${TSAN_CFLAGS[@]}" \
    -c app/spscring.c -o "${BUILD_DIR}/spscring_it.o"
gcc "${TSAN_CPPFLAGS[@]}" "${TSAN_CFLAGS[@]}" -Itests/ITs \
    -c tests/ITs/integration_tests.c -o "${BUILD_DIR}/integration_tests.o"
gcc "${BUILD_DIR}/spscring_it.o" "${BUILD_DIR}/integration_tests.o" \
    -o "${BUILD_DIR}/it_tsan" "${TSAN_LDFLAGS[@]}" -lcmocka -pthread

gcc "${TSAN_CPPFLAGS[@]}" "${TSAN_CFLAGS[@]}" -DN_ITEMS=200000 \
    app/spscring.c tests/stress/stress_mt.c \
    -o "${BUILD_DIR}/stress_tsan" "${TSAN_LDFLAGS[@]}" -pthread

# ASLR on recent kernels (mmap randomisation with 28+ bits, Linux 6.x defaults) collides with
# TSan's fixed shadow-memory layout and aborts with "FATAL: ThreadSanitizer: unexpected memory
# mapping" before a single test runs — on this laptop and on GitHub's ubuntu runners alike.
# setarch -R disables ASLR for the child process only (personality(ADDR_NO_RANDOMIZE), no
# privileges needed), which is the documented TSan workaround; fall through unchanged where
# setarch is unavailable.
run_tsan() {
    local -a no_aslr=()
    if command -v setarch >/dev/null 2>&1; then
        no_aslr=(setarch "$(uname -m)" -R)
    fi
    timeout --signal=TERM 300 "${no_aslr[@]}" env TSAN_OPTIONS="halt_on_error=1:history_size=7" "$@"
}

run_tsan "${BUILD_DIR}/it_tsan"
run_tsan "${BUILD_DIR}/stress_tsan"
printf 'ThreadSanitizer integration + stress gates passed\n'
