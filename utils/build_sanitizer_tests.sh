#!/usr/bin/env bash
# build_sanitizer_tests.sh — the KYR_SANITIZE_SUITES under ASan, UBSan and LSan (kyr-build lib/test.sh).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/utils/gcc_build_profiles.sh"
source "${KYR_BUILD_DIR}/lib/kyr.sh"
kyr_sanitize
