#!/usr/bin/env bash
# shellcheck shell=bash
# spscring_project.sh — SPSCring's declarations for the pinned kyr-build (every other script in utils/ is its wrapper): the library,
# the suites, the debs and what the ABI gate treats as public. Declarations only.
KYR_LIB="spscring"
KYR_LIB_SOURCES=(app/spscring.c)
KYR_LIB_HEADER="app/spscring.h"
KYR_LIB_MAP="utils/spscring.map"
KYR_LIB_CPPFLAGS=(-I"${ROOT_DIR}/app" -DSPSC_REQUIRE_ALWAYS_LOCK_FREE)
KYR_LIB_LDLIBS=()
# The test-only allocation and lock-free seams, in the coverage and sanitizer runs only, never in a shipped library.
KYR_TEST_HOOKS_CPPFLAGS=(-DSPSC_RING_TESTING -I"${ROOT_DIR}/tests/UTs")

KYR_UT_SUITES=(ut)
KYR_SUITE_UT_SOURCES=('tests/UTs/*.c')
KYR_SUITE_UT_CPPFLAGS=(-D_GNU_SOURCE -I"${ROOT_DIR}/tests/UTs")
KYR_SUITE_UT_LDLIBS=(-lcmocka -pthread)
KYR_IT_SUITES=(it)
KYR_SUITE_IT_SOURCES=('tests/ITs/*.c')
KYR_SUITE_IT_CPPFLAGS=(-D_GNU_SOURCE -I"${ROOT_DIR}/tests/ITs")
KYR_SUITE_IT_CPPFLAGS_TSAN=(-DN_ITEMS=200000)
KYR_SUITE_IT_LDLIBS=(-lcmocka -pthread)
# Coverage across the unit AND the integration suite on one instrumented object: the threaded flow counts toward the gate.
KYR_COVERAGE_SUITES=(ut it)
KYR_UT_FAIL_UNDER_LINE=100
KYR_UT_FAIL_UNDER_BRANCH=100
# The large-scale proof against the release archive; a reduced run under the sanitizers.
KYR_STRESS_SUITES=(stress)
KYR_SUITE_STRESS_SOURCES=(tests/stress/stress_mt.c)
KYR_SUITE_STRESS_CPPFLAGS=(-D_GNU_SOURCE)
KYR_SUITE_STRESS_CPPFLAGS_SANITIZE=(-DN_ITEMS=500000)
KYR_SUITE_STRESS_CPPFLAGS_TSAN=(-DN_ITEMS=200000)
KYR_SUITE_STRESS_LDLIBS=(-pthread)
KYR_SANITIZE_SUITES=(ut it stress)
KYR_TSAN_SUITES=(it stress)

# libspscring and libspscring-dev, both replacing the former single package "spscring".
KYR_PKG="libspscring"
KYR_PKG_DESCRIPTION="Single-producer single-consumer lock-free ring buffer library"
KYR_DEB_HEADERS=(app/spscring.h)
KYR_DEB_RUNTIME_FIELDS=("Conflicts: spscring" "Replaces: spscring")
KYR_DEB_DEV_FIELDS=("Conflicts: spscring" "Replaces: spscring")
KYR_DEB_DEV_DESCRIPTION="Development files for libspscring (header, static library, linker symlink)"
KYR_DEB_PC=0

# The public ABI: app/spscring.h; the linker map's node is SPSCRING_<major>.
KYR_ABI_NAME="SPSCring"
KYR_ABI_INCLUDE_DIR="app"
KYR_ABI_UMBRELLA="spscring.h"
KYR_ABI_TYPE_PREFIX="spsc_ring_"
KYR_ABI_FUNC_PREFIX="spsc_ring_"
KYR_ABI_CONST_PREFIX="SPSC_RING_"
KYR_ABI_NODE="SPSCRING"

# The legacy-names gate until kyr-build 3.0.0 is pinned and runs it as its own stage: its check and patterns, copied, and the test.
KYR_REPO_GATES+=(check_legacy_names.sh legacy_names.pat)
KYR_PIPELINE_EXTRA+=("checks|legacy-names|./utils/check_legacy_names.sh" "checks|legacy-names-test|bash tests/legacy_names_test.sh")
