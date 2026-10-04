#!/usr/bin/env bash
# build_deb.sh — build/debs/: every KYR_DEBS deb (default: the library and its -dev), SHA256SUMS, one .buildinfo per deb; the same commit gives the same bytes anywhere (kyr-build lib/deb.sh).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/utils/gcc_build_profiles.sh"
source "${KYR_BUILD_DIR}/lib/kyr.sh"
kyr_debs
