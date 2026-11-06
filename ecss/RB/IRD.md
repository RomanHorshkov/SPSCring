# Interface requirements document (IRD) toward SPSCring

SPSCRING-DOC-IRD. Written by Oliver Hughes, the customer's representative (KYR, the platform), from kyr_host 1.5.0 (f69df7a7). ECSS
makes the interface requirements the customer's output (ECSS-E-ST-40C Rev.1 5.2.4.3a), part of the requirements baseline it hands the
supplier, who answers them in its ICD ([../TS/ICD.md](../TS/ICD.md#53-interface-design)). Agreed at the SRR.

## 1 Introduction

kyr_host calls four functions of the ring: it creates one per operator, the listener pushes a descriptor, the operator pops until there
is none, the shutdown destroys it. This document says what the platform requires of those calls.

## 2 Applicable and reference documents

The SSS ([SSS.md](SSS.md#5-requirements)); kyr_host 1.5.0: [operator.h](../../customers/kyr_host/app/internal/kyr_host/core/worker/operator/operator.h#L101-L105),
[operator_init()](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L175-L181), [the push](../../customers/kyr_host/app/src/core/worker/worker.c#L273-L278),
[the pop](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L466-L470), [the destroy](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L352).

## 3 Terms

As in the SSS ([SSS.md](SSS.md#3-terms)).

## 4 The interface as the customer uses it

| Call (kyr_host 1.5.0) | Where | What the customer relies on |
|---|---|---|
| `op->ring = spsc_ring_init(ring_capacity)` | [operator.c](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L175-L181) | a ring of that capacity, or NULL, which fails the operator's start |
| `spsc_ring_push(op->ring, client_fd) != 0` | [worker.c](../../customers/kyr_host/app/src/core/worker/worker.c#L273-L278) | 0 when the descriptor is in, anything else when not: the caller answers the client from a reject slot |
| `while(spsc_ring_pop(op->ring, &client_fd) == 0)` | [operator.c](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L466-L470) | 0 and the descriptor, until the ring answers empty |
| `spsc_ring_destroy(&op->ring)` | [operator.c](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L352) | everything released, the pointer set to NULL |

The customer does not use the queries (it keeps its own atomic count of queued descriptors for its balancer), nor reset.

## 5 Interface requirements

<!-- ecss:table items doc=IRD -->
| ID | Title | Statement | Method | Source | Traces |
|---|---|---|---|---|---|
| SPSCRING-IRD-001 | A C interface of create, push, pop and destroy | The supplier shall provide a C11 header declaring an opaque ring type and the calls to create a ring of a given capacity, push an int, pop an int into the caller's variable and destroy the ring, setting the caller's pointer to NULL. | inspection | [customers/kyr_host/app/internal/kyr_host/core/worker/operator/operator.h#L101-L105](../../customers/kyr_host/app/internal/kyr_host/core/worker/operator/operator.h#L101-L105); [customers/kyr_host/app/src/core/worker/operator/operator.c#L176](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L176); [customers/kyr_host/app/src/core/worker/operator/operator.c#L352](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L352) | verified by VC-007, VC-008; source of SRS-013; satisfied by IF-001, IF-002, IF-003, IF-004, IF-006 |
| SPSCRING-IRD-002 | Statuses as return values | Push and pop shall return 0 on success and -1 when the ring is full or empty (or not there), with no other effect on a refusal and no errno to read. | test | [customers/kyr_host/app/src/core/worker/worker.c#L274](../../customers/kyr_host/app/src/core/worker/worker.c#L274); [customers/kyr_host/app/src/core/worker/operator/operator.c#L468](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L468) | verified by VC-001; source of SRS-004, SRS-005, SRS-013; satisfied by IF-003, IF-004 |
| SPSCRING-IRD-003 | One pushing thread, one popping thread, no lock | Push shall be safe from exactly one thread and pop from exactly one other thread at the same time, with no lock on either side; creation and destruction happen while neither uses the ring. | test | [customers/kyr_host/app/src/core/worker/worker.c#L274](../../customers/kyr_host/app/src/core/worker/worker.c#L274); [customers/kyr_host/app/src/core/worker/operator/operator.c#L468](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L468) | verified by VC-003, VC-005; source of SRS-006, SRS-007; satisfied by IF-003, IF-004 |
| SPSCRING-IRD-004 | The value popped is the value pushed | A descriptor popped shall be exactly the one pushed, visible in full to the popping thread: the hand-off shall order the producer's write of the value before the consumer's read of it. | test | [customers/kyr_host/app/src/core/worker/operator/operator.c#L466-L470](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L466-L470) | verified by VC-005, VC-006, VC-011; source of SRS-003, SRS-006, SRS-007; satisfied by IF-003, IF-004 |
| SPSCRING-IRD-005 | Linkage: versioned shared object and archive | The library shall be a shared object with a versioned soname and versioned symbols, exporting exactly its declared functions, and a static archive with the same functions. | test | [customers/kyr_host/deps.txt#L15-L16](../../customers/kyr_host/deps.txt#L15-L16) | verified by VC-007, VC-008; source of SRS-016; satisfied by IF-007 |
<!-- /ecss:table -->

## 6 Open points toward the supplier

- The customer pins libspscring 1.0.7 ([deps.txt](../../customers/kyr_host/deps.txt#L15-L16)); the supplier qualifies 1.0.8. The customer
  moves its pin when the QR shows the two are the same code.
