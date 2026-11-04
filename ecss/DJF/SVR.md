# Software verification report (SVR)

SPSCRING-DOC-SVR. Written by Davide Conti from the release pipeline's run at 0ad84dc1daf31dde302bee2fa1d1e5386049e5ec (v1.0.8) on
2026-11-04. After the DRD of ECSS-E-ST-40C Rev.1 Annex M; agreed at the QR. Every figure below is the run's own, its log kept in
[runs/0ad84dc1/](runs/0ad84dc1/pipeline.log) and in SPSCRING's evidence drawer, each result in the rms naming its log by SHA-256.

## 1 Introduction

The verification of SPSCring 1.0.8 against its SRS and ICD, case by case ([SVS.md](SVS.md#5-validation-cases)).

## 2 Applicable and reference documents

The SVS, the SRS ([../TS/SRS.md](../TS/SRS.md#5-requirements)), the ICD, the inspection record
([runs/0ad84dc1/inspection.md](runs/0ad84dc1/inspection.md#inspection-of-the-memory-ordering-and-the-progress-of-spscring-108)).

## 3 The run

| | |
|---|---|
| commit | 0ad84dc1daf31dde302bee2fa1d1e5386049e5ec (tag v1.0.8) |
| how | a clean clone at the tag; `./utils/deps.sh sysroot`, the exports, `./utils/run_pipeline.sh`; `GCC_BUILD_ENABLE_TSAN=1` |
| host | Linux 7.0.0 x86-64, Intel Core i7-8750H, GCC 15.2.0; a host build (Build-Root: none) |
| tools | kyr-build 3.1.1 (sha256 91121e30...), cmocka 2.0.2, gcovr 7.2 |
| verdict | pipeline GREEN: 25 stages ok, 1 skipped ([pipeline.log](runs/0ad84dc1/pipeline.log#L68-L99)) |

## 4 Results

<!-- ecss:table results -->
| Case | Profile | Commit | Status | Summary | Evidence |
|---|---|---|---|---|---|
| SPSCRING-VC-001 | release | 0ad84dc1 | passed | 13 tests passed | `runs/0ad84dc1/unit-tests-release.log` |
| SPSCRING-VC-002 | coverage | 0ad84dc1 | passed | 20 tests passed (17 unit, 3 integration) · lines 100.0 % · branches 100.0 % | `runs/0ad84dc1/coverage-summary.json` |
| SPSCRING-VC-003 | release | 0ad84dc1 | passed | 3 tests passed | `runs/0ad84dc1/integration.log` |
| SPSCRING-VC-004 | sanitize | 0ad84dc1 | passed | 20 tests passed (17 unit, 3 integration) and the stress of 500000 values, no sanitizer report | `runs/0ad84dc1/sanitizers.log` |
| SPSCRING-VC-005 | tsan | 0ad84dc1 | passed | 3 tests passed and the stress of 200000 values, no race reported | `runs/0ad84dc1/tsan.log` |
| SPSCRING-VC-006 | release | 0ad84dc1 | passed | 8000000 values exactly once and in order, 14100157 values/s | `runs/0ad84dc1/stress-run.log` |
| SPSCRING-VC-007 | release | 0ad84dc1 | passed | abi and abi-exports passed: the 9 declared functions, all @@SPSCRING_1 | `runs/0ad84dc1/abi-exports.log` |
| SPSCRING-VC-008 | release | 0ad84dc1 | passed | smoke test passed against the installed packages | `runs/0ad84dc1/package-smoke.log` |
| SPSCRING-VC-009 | release | 0ad84dc1 | passed | check_hardening passed on the release artifacts, 20 ELF(s) within the glibc ceiling | `runs/0ad84dc1/glibc-ceiling.log` |
| SPSCRING-VC-010 | audit | 0ad84dc1 | passed | the audit build (-fanalyzer, -Werror) and the gates legacy-names, pragmas, tables and warnings passed: no warning in 24 logs | `runs/0ad84dc1/warnings.log` |
| SPSCRING-VC-011 | inspection | 0ad84dc1 | passed | inspection held: 10 of 10 checks | `runs/0ad84dc1/inspection.md` |
<!-- /ecss:table -->

Figures of the run:

- unit suite on the release library: 13 tests passed ([unit-tests-release.log](runs/0ad84dc1/unit-tests-release.log#L1-L54));
- coverage of app/spscring.c by the unit (17) and integration (3) suites: lines 89 of 89, branches 44 of 44, functions 16 of 16, 100 %
  each ([coverage-summary.json](runs/0ad84dc1/coverage-summary.json#L1));
- stress on the release archive: 8,000,000 values through a ring of 4096 in 0.567 s, 14,100,157 values a second, each once and in order
  ([stress-run.log](runs/0ad84dc1/stress-run.log#L1-L12));
- under ASan, UBSan and LSan: 17 + 3 tests and the stress of 500,000 values (15,701,152 values a second, instrumented), no report
  ([sanitizers.log](runs/0ad84dc1/sanitizers.log#L1-L62));
- under ThreadSanitizer: 3 tests and 200,000 values, no race ([tsan.log](runs/0ad84dc1/tsan.log#L1-L22));
- ABI: the header matches abi/layout.txt, the shared object exports exactly the 9 declared functions, all `@@SPSCRING_1`
  ([abi.log](runs/0ad84dc1/abi.log#L1), [abi-exports.log](runs/0ad84dc1/abi-exports.log#L1));
- warnings: none in 24 logs ([warnings.log](runs/0ad84dc1/warnings.log#L1)); pragmas, tables and legacy names: none.

## 5 What was not run, and why

- The format stage: clang-format 18 (the major the gate pins) is not installed on the build host ([pipeline.log](runs/0ad84dc1/pipeline.log#L25-L26));
  SPSCRING-RID-QR-001.
- The debs of this run are development debs (Build-Root: none, [package.log](runs/0ad84dc1/package.log#L1)); the released debs were built
  in the build root, their SHA-256 in SPSCRING-CI-DEBS; SPSCRING-RID-QR-003.

## 6 Verification status

Every case passed at 0ad84dc1. Every software requirement and interface of the TS has at least one case, every case its run; the
qualification review moves the software requirements to verified on these runs. The change requests CR-001 to CR-004 change the README
and the header's comments, not the code, and stay open for the next release.

<!-- ecss:table changes -->
| ID | Title | Impacts | Raised by | State | Why |
|---|---|---|---|---|---|
| SPSCRING-CR-001 | README: spsc_ring_is_empty(NULL) returns 1 | SRS-013, IF-005, RID-PDR-001 | Elena Russo | approved | Accepted by the configuration control board for the next release. |
| SPSCRING-CR-002 | README: the wrap time of a 64-bit counter | SRS-011, RID-PDR-002 | Elena Russo | approved | Accepted by the configuration control board for the next release. |
| SPSCRING-CR-003 | spscring.h: the side each check belongs to | IF-005, RID-PDR-003 | Luca Romano | approved | Accepted by the configuration control board for the next release. |
| SPSCRING-CR-004 | spscring.h: @file spscring.h | DOC-API, RID-CDR-003 | Emily Clarke | approved | Accepted by the configuration control board for the next release. |
<!-- /ecss:table -->
