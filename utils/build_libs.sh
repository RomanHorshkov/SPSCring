#!/usr/bin/env bash
# build_libs.sh [profile ...] — build/<profile>/lib<name>.{a,so}; default KYR_LIB_PROFILES, else every catalog profile (kyr-build lib/build.sh).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/utils/gcc_build_profiles.sh"
source "${KYR_BUILD_DIR}/lib/kyr.sh"
kyr_build_libs "$@"
