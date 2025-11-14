#!/usr/bin/env bash
set -euo pipefail

# Configure the tree with tests enabled and run all registered CTest suites.
# Optional env vars:
#   BUILD_DIR - build directory (defaults to <repo>/build)
# Extra args are forwarded to ctest (e.g., -R spsc_ring_unit -V)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"

cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" -DSPSCRING_BUILD_TESTS=ON >/dev/null

ctest --test-dir "${BUILD_DIR}" "$@"
