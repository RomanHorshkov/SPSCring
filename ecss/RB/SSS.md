# Software system specification (SSS): what the platform requires of the ring

SPSCRING-DOC-SSS. Written by Oliver Hughes, the customer's representative (KYR, the platform), from the customer's own code: kyr_host
1.5.0 (f69df7a7), the host every box's server runs on. Part of the requirements baseline the platform gives the supplier
(ECSS-E-ST-40C Rev.1 5.2), agreed at the SRR. The interface the customer requires is in the IRD ([IRD.md](IRD.md#5-interface-requirements)),
the work in the statement of work ([SOW.md](SOW.md#2-work-to-be-performed)).

## 1 Introduction

The box accepts every connection on one listener thread and hands each accepted socket to one of its operator threads, the least
loaded, which serves it from then on. Between the two sits one ring per operator: the listener is its only producer, the operator its
only consumer. This document states what the platform needs of that ring, in the platform's words; the supplier answers it in its
technical specification ([../TS/SRS.md](../TS/SRS.md#5-requirements)).

## 2 Applicable and reference documents

- ECSS-E-ST-40C Rev.1, ECSS-Q-ST-80C Rev.2: cited, never copied.
- kyr_host 1.5.0: [the hand-off](../../customers/kyr_host/app/src/core/worker/worker.c#L245-L278), [the drain](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L457-L470),
  [the reject slot](../../customers/kyr_host/app/src/core/listener/listener.c#L698-L704), [the capacity key](../../customers/kyr_host/app/internal/kyr_host/core/host_env.def#L14),
  [the pins](../../customers/kyr_host/deps.txt#L15-L16).
- The statement of work ([SOW.md](SOW.md#1-scope)) and the IRD ([IRD.md](IRD.md#1-introduction)).

## 3 Terms

- listener: kyr_host's thread that accepts connections; the ring's producer.
- operator: one of kyr_host's threads serving connections; each ring's consumer.
- descriptor: the file descriptor of an accepted socket, an int.
- hand-off: the listener putting a descriptor into an operator's ring; take: the operator removing one.

## 4 General description

kyr_host's dispatcher picks the least loaded operator and pushes the descriptor into its ring; a refusal (no operator, or its ring
full) is answered by a reject slot with the canned 503 and a Retry-After, never by a close. The operator, woken by the listener, drains
its ring until it answers none, and adds each client to its reactor. The ring is made by the operator's start, sized by
KYR_HOST_RING_CAPACITY (a power of two, 8 to 1024, 32 by default) and released by its shutdown. A box serves for months between restarts.

What a defect of the ring does on the box: a lost descriptor is a client left without an answer until it times out and a descriptor
leaked; a duplicated one is one socket served twice, or, once the first service closed it and the number was reused, another client's
socket served with the wrong state. None of it corrupts the store, which the write queue guards; all of it is the box's front door
(the basis of the category, [../PAF/TAILORING.md](../PAF/TAILORING.md#3-criticality-classification)).

## 5 Requirements

The customer's requirements on the software; each is an rms item of SPSCRING written by Oliver Hughes, derived by the supplier into the
SRS (the column Traces) and verified by the supplier's cases.

<!-- ecss:table items doc=SSS -->
| ID | Title | Statement | Method | Source | Traces |
|---|---|---|---|---|---|
| SPSCRING-SSS-001 | Each accepted connection reaches one operator, once | The software shall carry the file descriptor of each connection the platform's listener accepts to exactly one operator thread, each descriptor delivered once and in the order the listener handed it over. | test | [customers/kyr_host/app/src/core/worker/worker.c#L245-L278](../../customers/kyr_host/app/src/core/worker/worker.c#L245-L278); [customers/kyr_host/app/src/core/worker/operator/operator.c#L457-L470](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L457-L470) | verified by VC-003, VC-005, VC-006; justified by SRC-HOST; source of SRS-003, SRS-010, SRS-015 |
| SPSCRING-SSS-002 | The listener never waits on an operator | Handing a descriptor over shall never block, sleep, spin or take a lock: when the operator cannot take it the hand-off shall refuse at once, so that the listener answers the client from a reject slot and goes on accepting. | test | [customers/kyr_host/app/src/core/worker/worker.c#L273-L278](../../customers/kyr_host/app/src/core/worker/worker.c#L273-L278); [customers/kyr_host/app/src/core/listener/listener.c#L698-L704](../../customers/kyr_host/app/src/core/listener/listener.c#L698-L704) | verified by VC-001, VC-011; justified by SRC-HOST; source of SRS-004, SRS-008, SRS-009 |
| SPSCRING-SSS-003 | A bounded ring, sized once | Each operator's ring shall hold a number of descriptors fixed when the operator starts, any power of two from 8 to 1024 (KYR_HOST_RING_CAPACITY, 32 by default), every slot of it usable. | test | [customers/kyr_host/app/internal/kyr_host/core/host_env.def#L14](../../customers/kyr_host/app/internal/kyr_host/core/host_env.def#L14); [customers/kyr_host/app/src/core/worker/worker.c#L556-L571](../../customers/kyr_host/app/src/core/worker/worker.c#L556-L571) | verified by VC-001, VC-002; source of SRS-001, SRS-002 |
| SPSCRING-SSS-004 | The operator drains without waiting | On its wake-up the operator shall take every descriptor handed over before it, one at a time, each take answering at once whether there was one, until none is left. | test | [customers/kyr_host/app/src/core/worker/operator/operator.c#L457-L470](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L457-L470) | verified by VC-001, VC-003; justified by SRC-HOST; source of SRS-005, SRS-008, SRS-012 |
| SPSCRING-SSS-005 | One ring per operator for the process's life | A ring shall be created by its operator's start, refuse the start when it cannot be made, serve the operator for the whole life of the process (months of uptime at the connection rate of a box) and be released by its teardown. | analysis | [customers/kyr_host/app/src/core/worker/operator/operator.c#L175-L181](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L175-L181); [customers/kyr_host/app/src/core/worker/operator/operator.c#L352](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L352) | verified by VC-002, VC-011; source of SRS-001, SRS-011, SRS-014 |
| SPSCRING-SSS-006 | Delivered as the platform pins its libraries | The software shall be delivered as the Debian packages libspscring and libspscring-dev, tier 1 of the platform (no platform dependency of its own), built reproducibly and pinned by the platform by version and SHA-256 in deps.txt. | test | [customers/kyr_host/deps.txt#L15-L16](../../customers/kyr_host/deps.txt#L15-L16); [customers/kyr_server/deps.txt#L25-L26](../../customers/kyr_server/deps.txt#L25-L26); [customers/kyr/deps.txt#L22](../../customers/kyr/deps.txt#L22) | verified by VC-007, VC-008, VC-009; source of SRS-017, SRS-018, SRS-019, SRS-020; satisfied by IF-008, CI-DEBS |
| SPSCRING-SSS-007 | Qualified under the platform's build profiles | Each release the platform pins shall be built and tested under the platform's kyr-build profiles (release, sanitizers, thread sanitizer, coverage), its pipeline green at the release commit. | test | [customers/kyr_host/deps.txt#L15-L16](../../customers/kyr_host/deps.txt#L15-L16) | verified by VC-002, VC-004, VC-005, VC-006; source of SRS-021 |
| SPSCRING-SRC-HOST | kyr_host 1.5.0, the customer's use | kyr_host at f69df7a7 (v1.5.0), the platform's host: the listener's hand-off to the least loaded operator, the operator's ring, its drain on wake-up, the ring's capacity from KYR_HOST_RING_CAPACITY, the reject slot when no operator can take a connection. | - | [customers/kyr_host/app/src/core/worker/worker.c#L245-L278](../../customers/kyr_host/app/src/core/worker/worker.c#L245-L278); [customers/kyr_host/app/src/core/worker/operator/operator.c#L457-L470](../../customers/kyr_host/app/src/core/worker/operator/operator.c#L457-L470) | - |
<!-- /ecss:table -->

## 6 From the requirements baseline down

How each customer requirement is answered: the software requirements derived from it, the interfaces and components that satisfy them,
and the cases that verify them.

<!-- ecss:table trace -->
| Customer requirement | Software requirements | Interfaces and components | Cases |
|---|---|---|---|
| SSS-001 Each accepted connection reaches one operator, once | SRS-003, SRS-010, SRS-015 | CMP-CONSUMER, CMP-PRODUCER, CMP-STATE, IF-003, IF-004, IF-009 | VC-001, VC-003, VC-005, VC-006, VC-010, VC-011 |
| SSS-002 The listener never waits on an operator | SRS-004, SRS-008, SRS-009 | CMP-CONSUMER, CMP-LIFE, CMP-PRODUCER, IF-002, IF-003, IF-004, IF-009 | VC-001, VC-002, VC-011 |
| SSS-003 A bounded ring, sized once | SRS-001, SRS-002 | CMP-LIFE, CMP-STATE, IF-002, IF-005 | VC-001, VC-002 |
| SSS-004 The operator drains without waiting | SRS-005, SRS-008, SRS-012 | CMP-CONSUMER, CMP-PRODUCER, CMP-QUERY, IF-003, IF-004, IF-005 | VC-001, VC-003, VC-005, VC-011 |
| SSS-005 One ring per operator for the process's life | SRS-001, SRS-011, SRS-014 | CMP-LIFE, CMP-STATE, IF-002, IF-006 | VC-001, VC-002, VC-011 |
| SSS-006 Delivered as the platform pins its libraries | SRS-017, SRS-018, SRS-019, SRS-020 | CI-DEBS, IF-007, IF-008, IF-009 | VC-001, VC-007, VC-008, VC-009 |
| SSS-007 Qualified under the platform's build profiles | SRS-021 | CMP-SEAMS | VC-001, VC-002, VC-003, VC-004, VC-005, VC-006 |
| IRD-001 A C interface of create, push, pop and destroy | SRS-013 | CMP-LIFE, IF-001, IF-002, IF-003, IF-004, IF-005, IF-006 | VC-001, VC-007, VC-008 |
| IRD-002 Statuses as return values | SRS-004, SRS-005, SRS-013 | CMP-CONSUMER, CMP-LIFE, CMP-PRODUCER, IF-001, IF-003, IF-004, IF-005, IF-006 | VC-001 |
| IRD-003 One pushing thread, one popping thread, no lock | SRS-006, SRS-007 | CMP-CONSUMER, CMP-PRODUCER, IF-003, IF-004 | VC-003, VC-005, VC-011 |
| IRD-004 The value popped is the value pushed | SRS-003, SRS-006, SRS-007 | CMP-CONSUMER, CMP-PRODUCER, IF-003, IF-004 | VC-001, VC-003, VC-005, VC-006, VC-011 |
| IRD-005 Linkage: versioned shared object and archive | SRS-016 | CI-DEBS, IF-007 | VC-007, VC-008 |
<!-- /ecss:table -->

## 7 Verification

Each requirement is verified through the supplier's cases (the SVS); the customer accepts the release at the QR on the recorded runs
of the release pipeline at the release commit.
