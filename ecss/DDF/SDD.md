# Software design document (SDD)

SPSCRING-DOC-SDD. Written by Emily Clarke from [app/spscring.c](../../app/spscring.c#L1-L338) at 0ad84dc1 (1.0.8). After the DRD of
ECSS-E-ST-40C Rev.1 Annex F; the architecture agreed at the PDR, the detail at the CDR. The function reference is generated from the
code ([api/spscring.md](api/spscring.md)); the figures are PlantUML in [../diagrams/](../diagrams/component.puml), each rendered to SVG
beside its source.

## 1 Introduction

The design of the ring: one control block, two sides that never write the same counter, creation that refuses lock-backed atomics,
queries that are snapshots, test seams that never ship.

## 2 Applicable and reference documents

The SRS ([../TS/SRS.md](../TS/SRS.md#5-requirements)), the ICD ([../TS/ICD.md](../TS/ICD.md#53-interface-design)),
[README.md](../../README.md#implementation-choices), ISO/IEC 9899:2011 7.17.

## 3 Terms

As in the SRS ([../TS/SRS.md](../TS/SRS.md#3-terms)).

## 4 Software design overview

### 4.1 Static architecture

![Components](../diagrams/component.svg)

Figure 4-1 ([component.puml](../diagrams/component.puml)). The library is one translation unit; its components are the parts of that
unit each with one job:

<!-- ecss:table items doc=SDD kind=component -->
| ID | Title | Statement | Method | Source | Traces |
|---|---|---|---|---|---|
| SPSCRING-CMP-STATE | The control block | struct spsc_ring: the buffer of int (read-only after creation), the capacity and its mask, then the consumer's head and the producer's tail, each _Atomic uint64_t aligned on its own cache line, the separation proven by a _Static_assert. | - | [app/spscring.c#L100-L126](../../app/spscring.c#L100-L126) | satisfies SRS-002, SRS-010, SRS-011, SRS-015; justified by DEC-001, DEC-002, DEC-004, DEC-006 |
| SPSCRING-CMP-LIFE | Creation and teardown | spsc_ring_init(): the capacity checked, the control block from aligned_alloc at its alignment, the counters initialised, the lock-free probe of both counters, then the buffer from calloc; spsc_ring_destroy() frees both and clears the caller's pointer; spsc_ring_reset() stores 0 in both counters. | - | [app/spscring.c#L128-L186](../../app/spscring.c#L128-L186); [app/spscring.c#L314-L338](../../app/spscring.c#L314-L338) | satisfies SRS-001, SRS-009, SRS-013, SRS-014; justified by DEC-003, DEC-005 |
| SPSCRING-CMP-PRODUCER | The producer side | spsc_ring_push() and spsc_ring_is_full(): the tail read relaxed (the producer owns it), the head read with acquire, the slot written, the tail advanced with release. | - | [app/spscring.c#L188-L221](../../app/spscring.c#L188-L221); [app/spscring.c#L278-L292](../../app/spscring.c#L278-L292) | satisfies SRS-003, SRS-004, SRS-006, SRS-008; justified by DEC-007 |
| SPSCRING-CMP-CONSUMER | The consumer side | spsc_ring_pop() and spsc_ring_is_empty(): the head read relaxed (the consumer owns it), the tail read with acquire, the slot read, the head advanced with release. | - | [app/spscring.c#L223-L276](../../app/spscring.c#L223-L276) | satisfies SRS-003, SRS-005, SRS-007, SRS-008; justified by DEC-007 |
| SPSCRING-CMP-QUERY | The queries | spsc_ring_capacity() returns the fixed size; spsc_ring_size() reads the head then the tail, both with acquire, and clamps the difference to the capacity. | - | [app/spscring.c#L294-L312](../../app/spscring.c#L294-L312) | satisfies SRS-012 |
| SPSCRING-CMP-SEAMS | The test seams (tests only) | Under SPSC_RING_TESTING only: the allocators replaced through tests/UTs/spscring_test_hooks.h and the lock-free verdict of each counter overridden, so that the unit suite reaches every failure path; without the switch the allocators are the C library's macros and nothing is exported. | - | [app/spscring.c#L43-L104](../../app/spscring.c#L43-L104); [tests/UTs/spscring_test_hooks.h#L1-L20](../../tests/UTs/spscring_test_hooks.h#L1-L20) | satisfies SRS-021 |
<!-- /ecss:table -->

### 4.2 Delivery

![Delivery and linkage](../diagrams/deployment.svg)

Figure 4-2 ([deployment.puml](../diagrams/deployment.puml)). The configuration item delivered:

<!-- ecss:table items doc=SDD kind=configuration-item -->
| ID | Title | Statement | Method | Source | Traces |
|---|---|---|---|---|---|
| SPSCRING-CI-DEBS | libspscring 1.0.8 and libspscring-dev 1.0.8 | The release's two Debian packages, built in the build root by kyr-build's lib/deb.sh from 0ad84dc1 and published with the release: libspscring_1.0.8_amd64.deb SHA-256 ca9831e63fc56b2902b262003ff0f108bfb011f142f1bb02d38c4a901538e85d, libspscring-dev_1.0.8_amd64.deb SHA-256 dfe54115b8f9c80c1f5504984aae9d92592b8bd2804d733301cc39a904fa1fd0. The qualification run on the build host (Build-Root: none) built development debs of other bytes; its package smoke test ran on those. | - | [utils/spscring_project.sh#L37-L44](../../utils/spscring_project.sh#L37-L44); [ecss/DJF/runs/0ad84dc1/package.log#L1-L4](../DJF/runs/0ad84dc1/package.log#L1-L4) | satisfies SRS-016, SRS-017, SRS-018, SRS-019, SRS-020, SSS-006 |
<!-- /ecss:table -->

The repository's own figures: [the ABI gate](../../docs/diagrams/abi_exports.puml) and [the tooling](../../docs/diagrams/tooling_sequence.puml).

## 5 Software components design

### 5.1 The control block

`struct spsc_ring` ([app/spscring.c](../../app/spscring.c#L110-L120)): `buf`, `size` and `mask` are written once by the creation and
read by both sides; `head` (written by the consumer) and `tail` (written by the producer) are each `_Alignas(SPSC_CACHELINE)`, so each
side's write invalidates only its own line. The separation is proven at compile time
([app/spscring.c](../../app/spscring.c#L125-L126)); the opaque type keeps it from the tests, which is why the proof lives there.

### 5.2 The ring's states

![The ring's states](../diagrams/ring_states.svg)

Figure 5-1 ([ring_states.puml](../diagrams/ring_states.puml)). With n = tail - head: empty at n = 0, full at n = N. A push on a full ring
and a pop on an empty one change nothing and answer -1. A ring of capacity 1 is legal: it goes straight from empty to full.

### 5.3 The memory ordering

![Push and pop](../diagrams/push_pop_sequence.svg)

Figure 5-2 ([push_pop_sequence.puml](../diagrams/push_pop_sequence.puml)). Each counter has one writer. The writer reads its own
counter relaxed (no other thread writes it); it reads the other side's counter with acquire; it publishes its own with release after
touching the slot ([push](../../app/spscring.c#L188-L221), [pop](../../app/spscring.c#L223-L261)). The pairs are:

- the producer's release of the tail with the consumer's acquire of the tail (in `spsc_ring_is_empty`,
  [app/spscring.c](../../app/spscring.c#L275)): the value written is the value read;
- the consumer's release of the head with the producer's acquire of the head (in `spsc_ring_is_full`,
  [app/spscring.c](../../app/spscring.c#L290-L291)): a slot is read before it is overwritten.

No loop, no lock, no system call: push and pop are wait-free. `spsc_ring_size` reads the head first and the tail second, both with
acquire; since both only grow and the tail is never behind the head, the difference cannot underflow, and it is clamped to the
capacity ([app/spscring.c](../../app/spscring.c#L300-L312)).

### 5.4 Creation and teardown

`spsc_ring_init` ([app/spscring.c](../../app/spscring.c#L148-L186)) checks the capacity (non-zero, a power of two, its buffer within
`size_t`), allocates the control block with `aligned_alloc` at its alignment (plain `malloc` guarantees only `max_align_t`),
initialises both counters, then probes them with `atomic_is_lock_free` and refuses before the buffer is allocated. `spsc_ring_destroy`
frees the buffer and the block and clears the caller's pointer.

### 5.5 The test seams

Under `SPSC_RING_TESTING` only ([app/spscring.c](../../app/spscring.c#L43-L104)), three function pointers replace the allocators and two
overrides replace the lock-free verdicts, so that the unit suite reaches every failure path of creation. Without the switch the
allocators are macros over the C library and nothing more is compiled or exported.

## 6 Decisions

<!-- ecss:table items doc=SDD kind=decision -->
| ID | Title | Statement | Method | Source | Traces |
|---|---|---|---|---|---|
| SPSCRING-DEC-001 | Full counters, not masked indexes | Empty is head == tail, full is tail - head == size, on 64-bit counters that only grow; the mask is applied only to address a slot. | - | [README.md#implementation-choices](../../README.md#implementation-choices); [app/spscring.c#L278-L292](../../app/spscring.c#L278-L292) | - |
| SPSCRING-DEC-002 | 64-bit counters | The two counters are uint64_t whatever the payload's width. | - | [README.md#index-width-wrap-and-uptime](../../README.md#index-width-wrap-and-uptime) | - |
| SPSCRING-DEC-003 | Power-of-two capacity | The capacity must be a power of two so that index & (size - 1) addresses the slot. | - | [app/spscring.c#L148-L154](../../app/spscring.c#L148-L154) | - |
| SPSCRING-DEC-004 | Head and tail on separate cache lines | The control block aligns head and tail on SPSC_CACHELINE and is allocated with aligned_alloc at that alignment. | - | [app/spscring.c#L106-L126](../../app/spscring.c#L106-L126); [app/spscring.c#L156-L162](../../app/spscring.c#L156-L162) | - |
| SPSCRING-DEC-005 | Refuse lock-backed atomics | The library checks the two actual counters with atomic_is_lock_free at creation and refuses the ring; the project's builds also define SPSC_REQUIRE_ALWAYS_LOCK_FREE for a compile-time refusal. | - | [README.md#lock-free-target-support](../../README.md#lock-free-target-support); [app/spscring.c#L25-L41](../../app/spscring.c#L25-L41) | - |
| SPSCRING-DEC-006 | An int payload | The ring stores int, the type of a file descriptor, not void*. | - | [app/spscring.h#L6-L12](../../app/spscring.h#L6-L12) | - |
| SPSCRING-DEC-007 | The least ordering that is enough | Each side reads its own counter relaxed, the other side's with acquire, and publishes its own with release; no sequentially consistent operation and no fence. | - | [app/spscring.c#L11-L16](../../app/spscring.c#L11-L16) | - |
<!-- /ecss:table -->

## 7 Requirements to design

Every software requirement is satisfied by a component or the configuration item (column Traces of 4.1 and 4.2); the components' own
traces to the decisions are the links justified-by.
