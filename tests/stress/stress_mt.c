/* Project: https://github.com/RomanHorshkov */
/**
 * @file stress_mt.c
 * @brief Producer/consumer stress test — the actual point of "SPSC."
 *
 * One producer thread pushes N_ITEMS distinct values while one consumer thread drains as
 * fast as it can; exactly the two roles the ring is specified for, running flat out against
 * each other for millions of hand-offs. Correctness is proven by a consumer-owned bitmap
 * indexed by sequence: every consumed item's bit is tested-and-set, so a duplicate delivery
 * is caught the instant it happens, an out-of-range item is rejected directly, and reaching
 * N_ITEMS without ever hitting a duplicate proves every distinct value was delivered exactly
 * once and in order — a count/sum check alone cannot rule out a lost item and a duplicated
 * one cancelling each other out. Mirrors MPSCring's tests/stress/stress_mt.c.
 *
 * Run this under ASan/UBSan/LSan and, separately, ThreadSanitizer — that is the dynamic
 * analysis bar for concurrent code, not just "the counts matched once."
 */
#include <assert.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "spscring.h"

#ifndef RING_CAPACITY
#    define RING_CAPACITY 4096u
#endif
#ifndef N_ITEMS
#    define N_ITEMS 8000000u /* override with -DN_ITEMS=<n> for a faster sanitizer/TSan pass */
#endif
#if N_ITEMS >= 0x7FFFFFFFu
#    error "N_ITEMS must fit in a positive int (the ring carries int values)"
#endif

static spsc_ring_t*     g_ring;
static _Atomic uint64_t g_produced_sum;

/* One bit per sequence number, owned solely by the consumer thread (no atomics needed on the
 * bitmap itself — the same single-writer reasoning the ring's own consumer side relies on). */
static uint8_t g_seen[(N_ITEMS + 7u) / 8u];

static uint64_t _now_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * UINT64_C(1000000000) + (uint64_t)ts.tv_nsec;
}

/* @return 1 if the bit was ALREADY set (duplicate), 0 if this is the first time. */
static int _bit_test_and_set(uint64_t index)
{
    const uint64_t byte     = index / 8u;
    const uint8_t  mask     = (uint8_t)(1u << (index % 8u));
    const int      was_set  = (g_seen[byte] & mask) != 0;
    g_seen[byte]           |= mask;
    return was_set;
}

static void* producer_main(void* arg)
{
    (void)arg;
    for(uint32_t i = 0; i < N_ITEMS; ++i)
    {
        const int item = (int)(i + 1u); /* never 0: a zero would be a slot that was never written */
        atomic_fetch_add_explicit(&g_produced_sum, (uint64_t)item, memory_order_relaxed);
        while(spsc_ring_push(g_ring, item) != 0)
        {
            /* ring momentarily full: this is a stress test by design, spin-wait */
        }
    }
    return NULL;
}

int main(void)
{
    g_ring = spsc_ring_init(RING_CAPACITY);
    if(!g_ring)
    {
        fprintf(stderr, "spsc_ring_init failed\n");
        return 1;
    }

    pthread_t      producer;
    const uint64_t t0 = _now_ns();
    if(pthread_create(&producer, NULL, producer_main, NULL) != 0)
    {
        fprintf(stderr, "pthread_create failed\n");
        return 1;
    }

    uint64_t consumed_count = 0;
    uint64_t consumed_sum   = 0;
    uint32_t expected_next  = 1u;
    while(consumed_count < N_ITEMS)
    {
        int item;
        if(spsc_ring_pop(g_ring, &item) != 0)
        {
            continue;
        }
        if(item <= 0 || (uint32_t)item > N_ITEMS)
        {
            fprintf(stderr, "CORRUPTION: out-of-range item %d\n", item);
            return 1;
        }
        const uint32_t seq = (uint32_t)item - 1u;
        if(_bit_test_and_set(seq))
        {
            fprintf(stderr, "CORRUPTION: duplicate delivery (seq=%u)\n", seq);
            return 1;
        }
        if((uint32_t)item != expected_next)
        {
            fprintf(stderr, "CORRUPTION: out of order (got %d, expected %u)\n", item, expected_next);
            return 1;
        }
        ++expected_next;
        consumed_sum += (uint64_t)item;
        ++consumed_count;
    }
    const uint64_t t1 = _now_ns();
    pthread_join(producer, NULL);

    const uint64_t produced_sum = atomic_load_explicit(&g_produced_sum, memory_order_relaxed);
    const double   elapsed_s    = (double)(t1 - t0) / 1e9;
    const double   ops_per_s    = (double)consumed_count / elapsed_s;

    printf("SPSCring stress: 1 producer x %u items, ring capacity %u\n", N_ITEMS, RING_CAPACITY);
    printf("  consumed_count=%lu (expected %u)\n", consumed_count, N_ITEMS);
    printf("  produced_sum=%lu consumed_sum=%lu (match: %s)\n", produced_sum, consumed_sum,
           (produced_sum == consumed_sum) ? "yes" : "NO — CORRUPTION/LOSS/DUPLICATION");
    printf("  elapsed=%.3fs  throughput=%.0f ops/s\n", elapsed_s, ops_per_s);

    assert(consumed_count == N_ITEMS);
    assert(produced_sum == consumed_sum);
    assert(spsc_ring_is_empty(g_ring));

    spsc_ring_destroy(&g_ring);
    printf("\nSTRESS TEST PASSED (exactly-once, in-order, proven via per-item bitmap)\n");
    return 0;
}
