#!/usr/bin/env bash
# build_UTs.sh — the unit suites under the coverage profile, run, gcovr report under tests/results/UTs, KYR_UT_FAIL_UNDER_* as the gate (kyr-build lib/test.sh).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/utils/gcc_build_profiles.sh"
source "${KYR_BUILD_DIR}/lib/kyr.sh"
kyr_ut_coverage
