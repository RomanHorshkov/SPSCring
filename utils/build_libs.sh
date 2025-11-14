#!/usr/bin/env bash
set -euo pipefail

# Build the static and shared spsc_ring libraries via CMake.
# Optional env vars:
#   BUILD_DIR  - build directory (defaults to <repo>/build)
#   BUILD_TYPE - CMake build type (Debug, Release, etc.), default Debug

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"
BUILD_TYPE="${BUILD_TYPE:-Debug}"

cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DSPSCRING_BUILD_TESTS=OFF

cmake --build "${BUILD_DIR}" --target spsc_ring_static spsc_ring_shared "$@"
