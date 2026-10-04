#!/usr/bin/env bash
# smoke_test_package.sh — compiles and runs tests/package/smoke.c against the installed package only (KYR_SMOKE_PREFIX, default /usr/local), never the build tree (kyr-build lib/test.sh).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/utils/gcc_build_profiles.sh"
source "${KYR_BUILD_DIR}/lib/kyr.sh"
kyr_smoke_package
