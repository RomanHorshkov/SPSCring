# Software validation specification w.r.t. the TS (SVS)

SPSCRING-DOC-SVS. Written by Davide Conti. After the DRD of ECSS-E-ST-40C Rev.1 Annex L; agreed at the CDR. The cases are the rms items
`SPSCRING-VC-nnn` (`DJF/verification_cases.csv`); their table is written by `ecss/tools/package.py tables`.

## 1 Introduction

How SPSCring 1.0.8 is shown to meet its technical specification: the suites and gates of its release pipeline, grouped by what they
prove, and one inspection for what a test cannot prove (the memory ordering, the progress).

## 2 Applicable and reference documents

The SRS ([../TS/SRS.md](../TS/SRS.md#5-requirements)), the ICD ([../TS/ICD.md](../TS/ICD.md#53-interface-design)),
[utils/spscring_project.sh](../../utils/spscring_project.sh#L14-L35) (the suites as the pipeline declares them),
[README.md](../../README.md#tests--coverage).

## 3 Terms

- profile: a kyr-build build profile (release, coverage, sanitize, tsan, audit); a run is recorded as `<profile>@<commit>`.
- stage: a step of `utils/run_pipeline.sh`, its log under `build/pipeline/` (kept as evidence in `DJF/runs/<commit>/`).

## 4 Validation approach

Every case runs in the pipeline at the release commit, on the build host, the way the repository builds it
(`./utils/deps.sh sysroot && eval "$(./utils/deps.sh env)" && ./utils/run_pipeline.sh`, with `GCC_BUILD_ENABLE_TSAN=1` for the TSan
stage at 1.0.8). A case passes when its stage passes; the inspection passes when every check of its list holds.

## 5 Validation cases

<!-- ecss:table cases -->
| ID | Title | Method | What runs | Criteria | Verifies |
|---|---|---|---|---|---|
| SPSCRING-VC-001 | Unit suite against the release library | test | tests/UTs/unit_tests.c built against build/release/libspscring.a without the seams (13 tests): creation, capacity, FIFO order, full and empty, the refusals, the size across a wrap, reset, destroy, NULL everywhere. Pipeline stage unit-tests-release. | Every test passes. | SSS-002, SSS-003, SSS-004, IRD-002, SRS-001, SRS-002, SRS-003, SRS-004, SRS-005, SRS-011, SRS-013, SRS-014, SRS-015, SRS-020, SRS-021, IF-002, IF-003, IF-004, IF-005, IF-006 |
| SPSCRING-VC-002 | Unit and integration suites under coverage, with the seams | test | tests/UTs/unit_tests.c (17 tests, the allocation and lock-free seams included) and tests/ITs/integration_tests.c (3 tests) on one instrumented object; gcovr gates lines and branches of app/spscring.c at 100 %. Pipeline stage unit-tests. | Every test passes; lines and branches 100 %. | SSS-003, SSS-005, SSS-007, SRS-001, SRS-009, SRS-021, IF-002 |
| SPSCRING-VC-003 | Integration suite on the release archive | test | tests/ITs/integration_tests.c against the release archive (3 tests): a simple flow, one producer and one consumer thread handing values over, an observer thread sampling the size while both run. Pipeline stage integration. | Every test passes. | SSS-001, SSS-004, IRD-003, SRS-003, SRS-012, SRS-021, IF-003, IF-004, IF-005 |
| SPSCRING-VC-004 | AddressSanitizer, UBSan and LeakSanitizer | test | The unit suite (17), the integration suite (3) and a reduced stress (500,000 values) under ASan, UBSan and LSan. Pipeline stage sanitizers. | Every test passes; no sanitizer report. | SSS-007, SRS-021 |
| SPSCRING-VC-005 | ThreadSanitizer | test | The integration suite (3) and a reduced stress (200,000 values) under ThreadSanitizer, run under setarch -R, never mixed with ASan. Pipeline stage tsan (GCC_BUILD_ENABLE_TSAN=1). | Every test passes; no race reported. | SSS-001, SSS-007, IRD-003, IRD-004, SRS-006, SRS-007, SRS-012, SRS-021 |
| SPSCRING-VC-006 | Stress: 8,000,000 hand-offs, exactly once, in order | test | tests/stress/stress_mt.c on the release archive: one producer pushes 1..8,000,000 against one consumer through a ring of 4096; a per-value bitmap aborts on a duplicate or an out-of-order value. Pipeline stage stress-run. | STRESS TEST PASSED; every value seen once, in order. | SSS-001, SSS-007, IRD-004, SRS-003, SRS-015, SRS-021 |
| SPSCRING-VC-007 | ABI layout and exports | analysis | utils/check_abi.sh: app/spscring.h against abi/layout.txt, and the release shared object's exports against utils/spscring.map (exactly nine functions, version node SPSCRING_1). Pipeline stages abi and abi-exports. | Both stages pass. | SSS-006, IRD-001, IRD-005, SRS-016, SRS-020, IF-001, IF-007 |
| SPSCRING-VC-008 | The installed packages | test | utils/smoke_test_package.sh: the debs built, installed into a scratch root, tests/package/smoke.c compiled against the installed header and library alone and run. Pipeline stages package and package-smoke. | The smoke program round-trips a value. | SSS-006, IRD-001, IRD-005, SRS-017, IF-007, IF-008 |
| SPSCRING-VC-009 | Hardening and the glibc ceiling | analysis | kyr-build's check_hardening on the release artifacts (RELRO, immediate binding, non-executable stack, canaries, fortify, no RPATH, versioned soname, position-independent archive) and the glibc-ceiling stage. Pipeline stages package and glibc-ceiling. | Every hard check passes. | SSS-006, SRS-018, SRS-019 |
| SPSCRING-VC-010 | Static analysis and the warning gates | analysis | The audit profile's build (the whole warning set, -Werror and GCC's -fanalyzer) and kyr-build's gates legacy-names, pragmas, tables and warnings. Pipeline stages build:audit, legacy-names, pragmas, tables, warnings. | Every stage passes. | SRS-010, IF-009 |
| SPSCRING-VC-011 | Inspection of the memory ordering and the progress | inspection | A line-by-line inspection of push, pop, is_full, is_empty and size against ISO/IEC 9899:2011 7.17: each counter written by one side only, read relaxed by its owner and with acquire by the other side, published with release; push and pop straight-line code with no loop, lock or system call (SDD 5.3). | Every check of the inspection's list holds; the threaded suites under ThreadSanitizer corroborate it. | SSS-002, SSS-005, IRD-004, SRS-006, SRS-007, SRS-008, SRS-010, SRS-011, IF-009 |
<!-- /ecss:table -->

## 6 Validation environment

Linux on x86-64, GCC with C11, cmocka 2.0, gcovr 7.2, the pinned kyr-build 3.1.1 (from deps.txt, by SHA-256).
