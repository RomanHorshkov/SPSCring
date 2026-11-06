# Inspection of the memory ordering and the progress of SPSCring 1.0.8

SPSCRING-VC-011, by Davide Conti, on app/spscring.c at 0ad84dc1daf31dde302bee2fa1d1e5386049e5ec (v1.0.8), against ISO/IEC 9899:2011
7.17 (atomics) and the progress conditions of wait-free synchronization. Every line number below is app/spscring.c's.

| # | Check | Where | Holds |
|---|---|---|---|
| 1 | The tail is written by push alone, the head by pop alone (reset aside, which is documented as not thread-safe) | L218, L258, L317-L318 | yes |
| 2 | push reads its own tail relaxed | L201 | yes |
| 3 | push decides "not full" from the head read with acquire, pairing with pop's release of the head | L290 | yes |
| 4 | push writes the slot before it advances the tail with release, so the value is published with the index | L208, L218 | yes |
| 5 | pop reads its own head relaxed | L236 | yes |
| 6 | pop decides "not empty" from the tail read with acquire, pairing with push's release of the tail, before it reads the slot | L275, L246 | yes |
| 7 | pop advances the head with release after the read, so the slot is reused only after it was read | L258 | yes |
| 8 | push and pop contain no loop, no lock, no system call and no allocation: a bounded number of steps whatever the other side does | L188-L261 | yes |
| 9 | size reads the head before the tail and clamps to the capacity: it cannot underflow nor exceed the capacity | L308-L311 | yes |
| 10 | head and tail are on separate cache lines, checked at compile time | L118-L119, L125-L126 | yes |

Corroboration (not proof): the integration suite and the stress under ThreadSanitizer report no race (tsan.log), the stress of
8,000,000 values delivers each once and in order (stress-run.log).

Observed beside the checks, not against them: spsc_ring_is_full() and spsc_ring_is_empty() read the other side's counter with acquire
and their own relaxed, which is the producer's and the consumer's view respectively; called from the other thread they still answer
a valid snapshot (atomic loads, no data race) but the header does not say which thread they belong to (SPSCRING-RID-PDR-003).
