# Software requirements specification (SRS)

SPSCRING-DOC-SRS. Written by Luca Romano from the code, the README and the suites of SPSCring 1.0.8 (0ad84dc1), each requirement
derived from the customer's requirements baseline ([../RB/SSS.md](../RB/SSS.md#5-requirements), [../RB/IRD.md](../RB/IRD.md#5-interface-requirements)).
After the DRD of ECSS-E-ST-40C Rev.1 Annex D; agreed at the PDR. The table in section 5 is written from `TS/requirements.csv` by
`ecss/tools/package.py tables`.

## 1 Introduction

This SRS specifies SPSCring, the single-producer single-consumer ring of int values, as software of category C
([../PAF/TAILORING.md](../PAF/TAILORING.md#3-criticality-classification)). It is the first part of the technical specification; the
second is the ICD ([ICD.md](ICD.md#53-interface-design)).

## 2 Applicable and reference documents

- ECSS-E-ST-40C Rev.1, ECSS-Q-ST-80C Rev.2; ISO/IEC 9899:2011 7.17 (the C11 atomics).
- L. Lamport, Specifying Concurrent Program Modules (1983); M. Herlihy, Wait-free synchronization (1991).
- The repository: [README.md](../../README.md#api-contract), [app/spscring.h](../../app/spscring.h#L1-L31), [app/spscring.c](../../app/spscring.c#L1-L16).
- The requirements baseline (RB/) and the ICD.

## 3 Terms

- head: the consumer's counter, the number of values taken; tail: the producer's, the number of values put.
- empty: head == tail; full: tail - head == capacity.
- acquire, release, relaxed: the C11 memory orders of 7.17.3.
- wait-free: every call finishes in a bounded number of its own steps, whatever the other thread does.

## 4 Software overview

### 4.1 Function

SPSCring hands int values from one thread to one other thread through a fixed array, without a lock. The producer owns the tail and the
slots it fills; the consumer owns the head. Each side publishes its own counter with release and reads the other's with acquire, which
is all the synchronisation the hand-off needs.

### 4.2 Environment

Linux, C11, a 64-bit target with lock-free 64-bit atomics (x86-64, aarch64). Tier 1 of the platform: no dependency but the C library
([deps.txt](../../deps.txt#L1-L9)). Built and tested under the pinned kyr-build 3.1.1.

### 4.3 Constraints

Exactly one producer and one consumer per ring (SPSCRING-ASM-001); reset and destroy while neither runs (SPSCRING-ASM-002).

## 5 Requirements

### 5.1 General provisions

Each requirement is an rms item `SPSCRING-SRS-nnn` of kind requirement with its rationale, criteria, method and sources, derived from a
requirement of the RB (the column Traces: "derives from"), satisfied by interfaces and components and verified by the cases of the SVS.
The assumptions are items `SPSCRING-ASM-nnn`.

### 5.2 Functional and non-functional requirements

<!-- ecss:table items doc=SRS kind=requirement -->
| ID | Title | Statement | Method | Source | Traces |
|---|---|---|---|---|---|
| SPSCRING-SRS-001 | Creation of a ring | spsc_ring_init(capacity) shall return a new empty ring when capacity is a non-zero power of two and capacity times sizeof(int) fits in size_t, and NULL otherwise; a failed allocation shall return NULL with nothing left allocated. | test | [app/spscring.h#L41-L51](../../app/spscring.h#L41-L51); [app/spscring.c#L148-L186](../../app/spscring.c#L148-L186) | derives from SSS-003, SSS-005; verified by VC-001, VC-002; satisfied by IF-002, CMP-LIFE; assumed by ASM-002 |
| SPSCRING-SRS-002 | Every slot usable | A ring of capacity N shall accept N pushes from empty and refuse the next one; it is empty when its two counters are equal and full when they differ by N. | test | [app/spscring.c#L278-L292](../../app/spscring.c#L278-L292); [README.md#implementation-choices](../../README.md#implementation-choices) | derives from SSS-003; verified by VC-001; satisfied by IF-005, CMP-STATE |
| SPSCRING-SRS-003 | First in, first out, exactly once | The values popped shall be the values pushed, each exactly once and in the order pushed. | test | [app/spscring.c#L188-L261](../../app/spscring.c#L188-L261) | derives from SSS-001, IRD-004; verified by VC-001, VC-003, VC-006; justified by SRC-LAMPORT; satisfied by IF-003, IF-004, CMP-PRODUCER, CMP-CONSUMER; assumed by ASM-001 |
| SPSCRING-SRS-004 | A full ring refuses a push at once | spsc_ring_push() on a full ring shall return -1 and change nothing; on a NULL ring it shall return -1. | test | [app/spscring.h#L53-L62](../../app/spscring.h#L53-L62); [app/spscring.c#L188-L196](../../app/spscring.c#L188-L196) | derives from SSS-002, IRD-002; verified by VC-001; satisfied by IF-003, CMP-PRODUCER |
| SPSCRING-SRS-005 | An empty ring refuses a pop at once | spsc_ring_pop() on an empty ring shall return -1 and leave the caller's variable untouched; a NULL output pointer shall discard the value popped. | test | [app/spscring.h#L64-L73](../../app/spscring.h#L64-L73); [app/spscring.c#L223-L245](../../app/spscring.c#L223-L245) | derives from SSS-004, IRD-002; verified by VC-001; satisfied by IF-004, CMP-CONSUMER |
| SPSCRING-SRS-006 | The producer publishes with release | spsc_ring_push() shall write the slot before it advances the tail with a release store, and shall read the head with an acquire load before it decides the ring is not full. | inspection | [app/spscring.c#L188-L221](../../app/spscring.c#L188-L221); [app/spscring.c#L278-L292](../../app/spscring.c#L278-L292) | derives from IRD-003, IRD-004; verified by VC-011, VC-005; justified by SRC-C11; satisfied by IF-003, CMP-PRODUCER; assumed by ASM-001 |
| SPSCRING-SRS-007 | The consumer reads after acquire | spsc_ring_pop() shall read the tail with an acquire load before it reads the slot, and shall advance the head with a release store after the read. | inspection | [app/spscring.c#L223-L276](../../app/spscring.c#L223-L276) | derives from IRD-003, IRD-004; verified by VC-011, VC-005; justified by SRC-C11; satisfied by IF-004, CMP-CONSUMER; assumed by ASM-001 |
| SPSCRING-SRS-008 | Push and pop are wait-free | Each call of spsc_ring_push() and spsc_ring_pop() shall finish in a bounded number of its own steps, whatever the other thread does: no loop, no lock, no system call, no allocation. | inspection | [app/spscring.c#L188-L261](../../app/spscring.c#L188-L261) | derives from SSS-002, SSS-004; verified by VC-011; justified by SRC-HERLIHY; satisfied by IF-003, IF-004, CMP-PRODUCER, CMP-CONSUMER; assumed by ASM-001 |
| SPSCRING-SRS-009 | Lock-free counters or no ring | spsc_ring_init() shall return NULL when either 64-bit counter is not lock-free on the target (atomic_is_lock_free); a build defining SPSC_REQUIRE_ALWAYS_LOCK_FREE shall fail to compile on a target whose 64-bit atomics are not always lock-free. | test | [app/spscring.c#L25-L41](../../app/spscring.c#L25-L41); [app/spscring.c#L128-L146](../../app/spscring.c#L128-L146); [app/spscring.c#L160-L171](../../app/spscring.c#L160-L171); [README.md#lock-free-target-support](../../README.md#lock-free-target-support) | derives from SSS-002; verified by VC-002; justified by SRC-C11; satisfied by IF-002, IF-009, CMP-LIFE; assumed by ASM-003 |
| SPSCRING-SRS-010 | Head and tail never share a cache line | The consumer's head and the producer's tail shall sit at least SPSC_CACHELINE (64) bytes apart, checked at compile time. | inspection | [app/spscring.c#L106-L126](../../app/spscring.c#L106-L126) | derives from SSS-001; verified by VC-010, VC-011; satisfied by IF-009, CMP-STATE |
| SPSCRING-SRS-011 | Counters that never wrap in service | The head and tail shall be 64-bit counters that only increase between a creation and a reset; at 10^6 hand-offs a second they wrap after about 584,000 years (2^64 / 10^6 s), at 10^9 after about 584 years. | analysis | [app/spscring.c#L110-L120](../../app/spscring.c#L110-L120); [README.md#index-width-wrap-and-uptime](../../README.md#index-width-wrap-and-uptime) | derives from SSS-005; verified by VC-001, VC-011; satisfied by CMP-STATE; assumed by ASM-003 |
| SPSCRING-SRS-012 | Queries are snapshots | spsc_ring_is_empty(), spsc_ring_is_full() and spsc_ring_size() shall answer a snapshot that may change at once; spsc_ring_size() shall read the head before the tail and clamp to the capacity, so that it never exceeds the capacity and never underflows. | test | [app/spscring.h#L99-L107](../../app/spscring.h#L99-L107); [app/spscring.c#L300-L312](../../app/spscring.c#L300-L312) | derives from SSS-004; verified by VC-003, VC-005; satisfied by IF-005, CMP-QUERY |
| SPSCRING-SRS-013 | Every call tolerates NULL | With a NULL ring, push and pop shall return -1, is_empty 1, is_full 0, capacity and size 0, and reset and destroy do nothing; destroy shall also accept a NULL pointer to the ring pointer, and set the caller's pointer to NULL after freeing. | test | [app/spscring.h#L75-L123](../../app/spscring.h#L75-L123); [app/spscring.c#L321-L338](../../app/spscring.c#L321-L338) | derives from IRD-001, IRD-002; verified by VC-001; justified by SRC-README; satisfied by IF-001, IF-005, IF-006, CMP-LIFE |
| SPSCRING-SRS-014 | Reset only while both sides stand still | spsc_ring_reset() shall empty the ring; it is not safe while either thread uses the ring. | test | [app/spscring.h#L109-L116](../../app/spscring.h#L109-L116); [app/spscring.c#L314-L319](../../app/spscring.c#L314-L319) | derives from SSS-005; verified by VC-001; satisfied by IF-006, CMP-LIFE; assumed by ASM-002 |
| SPSCRING-SRS-015 | Any int, carried as it is | The ring shall store any int value, independent of the width of its counters. | test | [app/spscring.h#L6-L12](../../app/spscring.h#L6-L12) | derives from SSS-001; verified by VC-001, VC-006; satisfied by IF-003, IF-004, CMP-STATE |
| SPSCRING-SRS-016 | The ABI is gated | abi/layout.txt shall describe the public ABI of app/spscring.h; the shared object shall export exactly the nine declared functions as <name>@@SPSCRING_1; a changed line of the layout shall need a new major, a new public name a new minor. | analysis | [abi/layout.txt#L1-L12](../../abi/layout.txt#L1-L12); [utils/spscring.map#L1-L17](../../utils/spscring.map#L1-L17); [README.md#build-profiles--hardening](../../README.md#build-profiles--hardening) | derives from IRD-005; verified by VC-007; justified by SRC-README; satisfied by IF-007, CI-DEBS |
| SPSCRING-SRS-017 | Two packages, reproducible | The library shall be delivered as libspscring (the shared object and its soname link) and libspscring-dev (the header, the static archive, the linker link), the second depending on the first at the same version, built to the same bytes from the same commit. | test | [utils/spscring_project.sh#L37-L44](../../utils/spscring_project.sh#L37-L44); [README.md#release-process](../../README.md#release-process) | derives from SSS-006; verified by VC-008; satisfied by IF-008, CI-DEBS |
| SPSCRING-SRS-018 | A hardened release | The release shared object shall pass kyr-build's hardening check: full RELRO, immediate binding, a non-executable stack, stack canaries, fortified calls, no RPATH, a versioned soname. | test | [README.md#build-profiles--hardening](../../README.md#build-profiles--hardening) | derives from SSS-006; verified by VC-009; satisfied by CI-DEBS |
| SPSCRING-SRS-019 | Nothing linked but the C library | At run time the library shall depend on the C library alone; deps.txt shall name only build and test tools. | inspection | [deps.txt#L1-L9](../../deps.txt#L1-L9) | derives from SSS-006; verified by VC-009; satisfied by IF-007, CI-DEBS |
| SPSCRING-SRS-020 | Test seams never shipped | The allocation and lock-free test seams shall be compiled only with SPSC_RING_TESTING, in the coverage and sanitizer runs, and never in a shipped artifact; the release library shall export no test symbol. | inspection | [app/spscring.c#L43-L104](../../app/spscring.c#L43-L104); [utils/spscring_project.sh#L11-L12](../../utils/spscring_project.sh#L11-L12) | derives from SSS-006; verified by VC-001, VC-007; satisfied by IF-009, CI-DEBS |
| SPSCRING-SRS-021 | Verified under every profile that runs the suites | The unit suite shall pass against the release library, the unit and integration suites together shall cover 100 % of the lines and branches of app/spscring.c, both shall pass under ASan, UBSan and LSan, the integration suite and a reduced stress under ThreadSanitizer, and the full stress on the release archive. | test | [utils/spscring_project.sh#L14-L35](../../utils/spscring_project.sh#L14-L35); [README.md#tests--coverage](../../README.md#tests--coverage) | derives from SSS-007; verified by VC-001, VC-002, VC-003, VC-004, VC-005, VC-006; satisfied by CMP-SEAMS |
<!-- /ecss:table -->

### 5.3 Assumptions

<!-- ecss:table items doc=SRS kind=assumption -->
| ID | Title | Statement | Method | Source | Traces |
|---|---|---|---|---|---|
| SPSCRING-ASM-001 | One producer and one consumer per ring | The caller guarantees, for the whole life of a ring, that exactly one thread pushes and exactly one other thread pops. | - | [app/spscring.h#L18-L24](../../app/spscring.h#L18-L24) | assumption for SRS-003, SRS-006, SRS-007, SRS-008 |
| SPSCRING-ASM-002 | Creation, reset and destruction while the ring is quiet | The caller creates, resets and destroys a ring only while neither the producer nor the consumer uses it. | - | [app/spscring.h#L18-L24](../../app/spscring.h#L18-L24); [customers/kyr_host/app/src/core/worker/operator/operator.c#L352](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L352) | assumption for SRS-001, SRS-014 |
| SPSCRING-ASM-003 | A 64-bit target with lock-free 64-bit atomics | The library runs on a 64-bit target (x86-64, aarch64) whose 64-bit atomics are lock-free. | - | [app/spscring.c#L25-L41](../../app/spscring.c#L25-L41) | assumption for SRS-009, SRS-011 |
<!-- /ecss:table -->

## 6 Validation requirements

Each requirement states its criteria and method; its cases are the items `SPSCRING-VC-nnn` ([../DJF/SVS.md](../DJF/SVS.md#5-validation-cases)),
the release pipeline's stages at the release commit and one inspection.

## 7 Traceability

Up: each requirement derives from the RB (column Traces). Down: the interfaces of the ICD and the components of the SDD that satisfy
it, the cases that verify it. Sources: the literature and the standards each relies on.

<!-- ecss:table sources -->
| ID | Title | What it is | Reference |
|---|---|---|---|
| SPSCRING-SRC-E40 | ECSS-E-ST-40C Rev.1, Space engineering: Software | The engineering standard the package follows: the requirements baseline (5.2), the technical specification (5.4), the design (5.5), the validation (5.6), the delivery and acceptance (5.7), the verification (5.8) and the DRDs of its annexes. Cited, never copied. | ECSS-E-ST-40C Rev.1 |
| SPSCRING-SRC-Q80 | ECSS-Q-ST-80C Rev.2, Space product assurance: Software product assurance | The product assurance standard: the software criticality categories (6.2.2) the tailoring argues from. Cited, never copied. | ECSS-Q-ST-80C Rev.2 |
| SPSCRING-SRC-C11 | ISO/IEC 9899:2011, 7.17 Atomics | The C11 memory model: atomic objects, memory_order_relaxed, memory_order_acquire and memory_order_release, the synchronizes-with relation, atomic_is_lock_free and the ATOMIC_*_LOCK_FREE macros. | ISO/IEC 9899:2011 clause 7.17; [app/spscring.c#L11-L16](../../app/spscring.c#L11-L16) |
| SPSCRING-SRC-LAMPORT | Lamport, Specifying Concurrent Program Modules (1983) | L. Lamport, Specifying Concurrent Program Modules, ACM Transactions on Programming Languages and Systems 5(2), 1983: the bounded single-producer single-consumer queue that needs no lock, each index written by one side only. | ACM TOPLAS 5(2), 1983 |
| SPSCRING-SRC-HERLIHY | Herlihy, Wait-free synchronization (1991) | M. Herlihy, Wait-free synchronization, ACM Transactions on Programming Languages and Systems 13(1), 1991: wait-freedom, every call finishing in a bounded number of its own steps whatever the other threads do. | ACM TOPLAS 13(1), 1991 |
| SPSCRING-SRC-README | The repository's README at 1.0.8 | README.md of SPSCring at 0ad84dc1: the API contract, the implementation choices, the lock-free target support, the index width, the build, the tests, the release process. | [README.md#api-contract](../../README.md#api-contract); [README.md#implementation-choices](../../README.md#implementation-choices) |
| SPSCRING-SRC-HOST | kyr_host 1.5.0, the customer's use | kyr_host at f69df7a7 (v1.5.0), the platform's host: the listener's hand-off to the least loaded operator, the operator's ring, its drain on wake-up, the ring's capacity from KYR_HOST_RING_CAPACITY, the reject slot when no operator can take a connection. | [customers/kyr_host/app/src/core/worker/worker.c#L245-L278](../../customers/kyr_host/app/src/core/worker/worker.c#L245-L278); [customers/kyr_host/app/src/core/worker/operator/operator.c#L457-L470](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L457-L470) |
<!-- /ecss:table -->
