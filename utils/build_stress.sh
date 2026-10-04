#!/usr/bin/env bash
# build_stress.sh — every KYR_STRESS_SUITES benchmark in every KYR_STRESS_PROFILES x KYR_STRESS_LINKAGES cell, build/stress/manifest.tsv; builds only (kyr-build lib/test.sh).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/utils/gcc_build_profiles.sh"
source "${KYR_BUILD_DIR}/lib/kyr.sh"
kyr_stress_build
