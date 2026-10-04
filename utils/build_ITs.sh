#!/usr/bin/env bash
# build_ITs.sh — the integration suites in every KYR_IT_PROFILES x KYR_IT_LINKAGES cell, then the coverage run with KYR_IT_COVERAGE=1 (kyr-build lib/test.sh).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/utils/gcc_build_profiles.sh"
source "${KYR_BUILD_DIR}/lib/kyr.sh"
kyr_its
