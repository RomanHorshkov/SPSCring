# Interface control document (ICD)

SPSCRING-DOC-ICD. Written by Luca Romano from [app/spscring.h](../../app/spscring.h#L1-L125), [abi/layout.txt](../../abi/layout.txt#L1-L12)
and [utils/spscring.map](../../utils/spscring.map#L1-L17) at 0ad84dc1 (1.0.8). After the DRD of ECSS-E-ST-40C Rev.1 Annex E; agreed at
the PDR, approved by the customer. The function-by-function reference is generated from the header ([../DDF/api/spscring.md](../DDF/api/spscring.md)).

## 1 Introduction

The second part of the technical specification: the library's interface toward kyr_host and any consumer, answering the customer's
IRD ([../RB/IRD.md](../RB/IRD.md#5-interface-requirements)).

## 2 Applicable and reference documents

The SRS ([SRS.md](SRS.md#5-requirements)); the IRD; [README.md](../../README.md#api-contract) and [README.md](../../README.md#release-process).

## 3 Terms

As in the SRS ([SRS.md](SRS.md#3-terms)).

## 4 Software overview

See the SRS ([SRS.md](SRS.md#4-software-overview)).

## 5 Requirements and design

### 5.1 General provisions

Each interface item is an rms item `SPSCRING-IF-nnn` of kind interface; it satisfies the customer's interface requirements
(`SPSCRING-IRD-nnn`) and the software requirements, and is verified by cases of its own.

### 5.2 Interface requirements

Software to software only: one C header, a shared object and an archive, two Debian packages. Every call that can fail answers -1 (push,
pop) or NULL (init); nothing sets errno. The ABI is gated: `utils/check_abi.sh` compares the header with abi/layout.txt and the exports
with utils/spscring.map.

### 5.3 Interface design

<!-- ecss:table items doc=ICD -->
| ID | Title | Statement | Method | Source | Traces |
|---|---|---|---|---|---|
| SPSCRING-IF-001 | The ring handle | typedef struct spsc_ring spsc_ring_t: an opaque type, held by pointer; its layout is the library's. | inspection | [app/spscring.h#L36-L39](../../app/spscring.h#L36-L39) | satisfies IRD-001, SRS-013; verified by VC-007 |
| SPSCRING-IF-002 | spsc_ring_init() | spsc_ring_t* spsc_ring_init(uint64_t capacity): a new empty ring of capacity slots (a non-zero power of two), or NULL for an invalid capacity, a failed allocation or a target without lock-free 64-bit atomics. Not thread-safe. | test | [app/spscring.h#L41-L51](../../app/spscring.h#L41-L51) | satisfies IRD-001, SRS-001, SRS-009; verified by VC-001, VC-002 |
| SPSCRING-IF-003 | spsc_ring_push() | int spsc_ring_push(spsc_ring_t* ring, int fd): 0 when fd is stored, -1 when the ring is full or NULL; producer thread only; wait-free. | test | [app/spscring.h#L53-L62](../../app/spscring.h#L53-L62) | satisfies IRD-001, IRD-002, IRD-003, IRD-004, SRS-003, SRS-004, SRS-006, SRS-008, SRS-015; verified by VC-001, VC-003 |
| SPSCRING-IF-004 | spsc_ring_pop() | int spsc_ring_pop(spsc_ring_t* ring, int* out_fd): 0 when a value is taken (written to *out_fd unless out_fd is NULL), -1 when the ring is empty or NULL; consumer thread only; wait-free. | test | [app/spscring.h#L64-L73](../../app/spscring.h#L64-L73) | satisfies IRD-001, IRD-002, IRD-003, IRD-004, SRS-003, SRS-005, SRS-007, SRS-008, SRS-015; verified by VC-001, VC-003 |
| SPSCRING-IF-005 | The queries | int spsc_ring_is_empty(spsc_ring_t*), int spsc_ring_is_full(spsc_ring_t*), uint64_t spsc_ring_capacity(const spsc_ring_t*), uint64_t spsc_ring_size(const spsc_ring_t*): snapshots; with NULL 1, 0, 0 and 0. | test | [app/spscring.h#L75-L107](../../app/spscring.h#L75-L107) | satisfies SRS-002, SRS-012, SRS-013; verified by VC-001, VC-003 |
| SPSCRING-IF-006 | spsc_ring_reset() and spsc_ring_destroy() | void spsc_ring_reset(spsc_ring_t* ring): empty the ring, not thread-safe. void spsc_ring_destroy(spsc_ring_t** ring): free the ring and its buffer and set *ring to NULL; NULL and a NULL *ring are no-ops. | test | [app/spscring.h#L109-L123](../../app/spscring.h#L109-L123) | satisfies IRD-001, SRS-013, SRS-014; verified by VC-001 |
| SPSCRING-IF-007 | Library linkage | libspscring.so.1 (soname major 1) exports exactly the nine functions of app/spscring.h as <name>@@SPSCRING_1 (utils/spscring.map); libspscring.a carries the same functions; a consumer includes <spscring.h>. | test | [utils/spscring.map#L1-L17](../../utils/spscring.map#L1-L17); [abi/layout.txt#L1-L12](../../abi/layout.txt#L1-L12) | satisfies IRD-005, SRS-016, SRS-019; verified by VC-007, VC-008 |
| SPSCRING-IF-008 | The packages | libspscring_<version>_<arch>.deb: /usr/local/lib/libspscring.so.<version> and its soname link; libspscring-dev_<version>_<arch>.deb: /usr/local/include/spscring.h, /usr/local/lib/libspscring.a and the libspscring.so link, depending on libspscring (= <version>); both replace the former single package spscring. | test | [README.md#release-process](../../README.md#release-process); [utils/spscring_project.sh#L37-L44](../../utils/spscring_project.sh#L37-L44) | satisfies SSS-006, SRS-017; verified by VC-008 |
| SPSCRING-IF-009 | Build-time switches | SPSC_REQUIRE_ALWAYS_LOCK_FREE (the project's builds define it: a target without always-lock-free 64-bit atomics fails to compile); SPSC_CACHELINE (64 by default: the layout only, never the behaviour); SPSC_RING_TESTING (the test seams, never in a shipped build). | inspection | [app/spscring.c#L25-L41](../../app/spscring.c#L25-L41); [app/spscring.c#L106-L108](../../app/spscring.c#L106-L108); [utils/spscring_project.sh#L9-L12](../../utils/spscring_project.sh#L9-L12) | satisfies SRS-009, SRS-010, SRS-020; verified by VC-010, VC-011 |
<!-- /ecss:table -->

### 5.4 The calls and their threads

| Call | Thread | Blocks | With NULL |
|---|---|---|---|
| `spsc_ring_init` | any, before the ring is shared | never (allocates) | - |
| `spsc_ring_push` | the producer | never (wait-free) | -1 |
| `spsc_ring_pop` | the consumer | never (wait-free) | -1 |
| `spsc_ring_is_full` | the producer's check (a snapshot elsewhere) | never | 0 |
| `spsc_ring_is_empty` | the consumer's check (a snapshot elsewhere) | never | 1 |
| `spsc_ring_size`, `spsc_ring_capacity` | any (snapshot) | never | 0 |
| `spsc_ring_reset`, `spsc_ring_destroy` | any, while neither side runs | never (frees) | no-op |

### 5.5 What the library uses

The C library only: `aligned_alloc`, `calloc`, `free` and the C11 atomics.
