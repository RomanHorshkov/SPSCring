# Software user manual (SUM)

SPSCRING-DOC-SUM. Written by Emily Clarke for a programmer who links SPSCring 1.0.8. After the DRD of ECSS-E-ST-40C Rev.1 Annex H;
agreed at the CDR. Each call in full: [api/spscring.md](api/spscring.md).

## 1 Introduction

SPSCring hands int values (file descriptors, typically) from exactly one producer thread to exactly one consumer thread, without a lock
and without waiting.

## 2 Applicable and reference documents

The ICD ([../TS/ICD.md](../TS/ICD.md#53-interface-design)); [README.md](../../README.md#api-contract).

## 3 Getting the library

Install `libspscring` and `libspscring-dev` (the platform pins them in its deps.txt), include `<spscring.h>`, link `-lspscring`. From
the source: `./utils/deps.sh sysroot && eval "$(./utils/deps.sh env)" && ./utils/run_pipeline.sh` ([README.md](../../README.md#build-profiles--hardening)).

## 4 Using the ring

### 4.1 Create it once, before the threads share it

```c
spsc_ring_t* ring = spsc_ring_init(32);   /* a power of two; NULL: invalid capacity, no memory, or no lock-free 64-bit atomics */
if(!ring) { /* refuse your component's start */ }
```

### 4.2 The producer

```c
if(spsc_ring_push(ring, fd) != 0) {
    /* full: nothing stored; answer the work elsewhere (kyr_host answers a 503 from a reject slot) */
}
```

Only one thread may push. A push never blocks; it answers at once.

### 4.3 The consumer

```c
int fd;
while(spsc_ring_pop(ring, &fd) == 0) {
    /* serve fd */
}
```

Only one thread (another one) may pop. Pass NULL to discard a value.

### 4.4 Asking without taking

`spsc_ring_is_full` is the producer's check, `spsc_ring_is_empty` the consumer's; `spsc_ring_size` and `spsc_ring_capacity` may be asked
from anywhere. Every answer is a snapshot that may change at once (SPSCRING-SRS-012).

### 4.5 Tear it down

Stop both threads first, then `spsc_ring_destroy(&ring)`: everything freed, `ring` set to NULL. `spsc_ring_reset(ring)` empties a ring,
also only while both threads are stopped.

### 4.6 A complete program

The package's own smoke test, built against the installed packages alone ([tests/package/smoke.c](../../tests/package/smoke.c#L1-L24)).

## 5 Errors and what to do

| Answer | Means | Do |
|---|---|---|
| `spsc_ring_init` NULL | capacity 0 or not a power of two, too large for memory, no memory, or a target whose 64-bit atomics take a lock | check the capacity; a lock-backed target cannot run this ring |
| `spsc_ring_push` -1 | full, or the ring pointer is NULL | the value was not stored: put it elsewhere or refuse it |
| `spsc_ring_pop` -1 | empty, or the ring pointer is NULL | nothing to take: wait for the producer's signal |
| a build error "SPSCring requires always-lock-free..." | `SPSC_REQUIRE_ALWAYS_LOCK_FREE` on a target without them | build for a 64-bit target with lock-free atomics |

## 6 What not to do

- Push from two threads, or pop from two threads: the ring is single-producer, single-consumer (use MPSCring for many producers).
- Reset or destroy while a side runs.
- Read `spsc_ring_is_empty(NULL)` as 0: it is 1 (the README's contract says 0; SPSCRING-CR-001 corrects it).
