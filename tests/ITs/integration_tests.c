/* Project: https://github.com/RomanHorshkov */
#include <pthread.h>
#include <sched.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>

#include <cmocka.h>
#include "spscring.h"

static void test_simple_flow(void** state)
{
    (void)state;
    spsc_ring_t* ring = spsc_ring_init(8);
    assert_non_null(ring);

    for(int i = 0; i < 5; ++i)
    {
        assert_int_equal(0, spsc_ring_push(ring, i));
    }

    for(int i = 0; i < 5; ++i)
    {
        int v = -1;
        assert_int_equal(0, spsc_ring_pop(ring, &v));
        assert_int_equal(i, v);
    }

    assert_true(spsc_ring_is_empty(ring));
    spsc_ring_destroy(&ring);
    assert_null(ring);
}

typedef struct
{
    spsc_ring_t* ring;
    int          count;
    _Atomic int  error;
    _Atomic int  bad_expected;
    _Atomic int  bad_actual;
    /* size()-observer test */
    _Atomic int      producers_done;
    _Atomic uint64_t worst_size;         /* max size() an observer ever saw */
} spsc_it_ctx_t;

static void* producer_thread(void* arg); /* defined below */
static void* consumer_thread(void* arg); /* defined below */

/* Observer that hammers spsc_ring_size() while the producer/consumer run. Before
 * the head-before-tail fix, an unlucky sample could read tail then a further-
 * advanced head and underflow to ~2^64; here we record the largest value seen so
 * the test can assert it stayed within capacity. */
static void* size_observer_thread(void* arg)
{
    spsc_it_ctx_t* ctx   = (spsc_it_ctx_t*)arg;
    uint64_t       worst = 0;
    while(atomic_load(&ctx->producers_done) == 0)
    {
        uint64_t s = spsc_ring_size(ctx->ring);
        if(s > worst) worst = s;
    }
    /* a few trailing samples as the ring drains */
    for(int i = 0; i < 1000; ++i)
    {
        uint64_t s = spsc_ring_size(ctx->ring);
        if(s > worst) worst = s;
    }
    atomic_store(&ctx->worst_size, worst);
    return NULL;
}

static void test_size_never_underflows_concurrently(void** state)
{
    (void)state;
    const int    count = 200000;
    spsc_ring_t* ring  = spsc_ring_init(1024);
    assert_non_null(ring);

    spsc_it_ctx_t ctx = {.ring = ring, .count = count};

    pthread_t prod, cons, obs;
    assert_int_equal(0, pthread_create(&obs, NULL, size_observer_thread, &ctx));
    assert_int_equal(0, pthread_create(&prod, NULL, producer_thread, &ctx));
    assert_int_equal(0, pthread_create(&cons, NULL, consumer_thread, &ctx));

    assert_int_equal(0, pthread_join(prod, NULL));
    assert_int_equal(0, pthread_join(cons, NULL));
    atomic_store(&ctx.producers_done, 1);
    assert_int_equal(0, pthread_join(obs, NULL));

    /* The whole point: size() never reported a value beyond the ring capacity
     * (an underflow would have shown up as an astronomically large sample). */
    assert_true(atomic_load(&ctx.worst_size) <= spsc_ring_capacity(ring));

    assert_true(spsc_ring_is_empty(ring));
    spsc_ring_destroy(&ring);
}

static void* producer_thread(void* arg)
{
    spsc_it_ctx_t* ctx = (spsc_it_ctx_t*)arg;
    for(int i = 0; i < ctx->count; ++i)
    {
        while(spsc_ring_push(ctx->ring, i) != 0)
        {
            sched_yield();
        }
    }
    return NULL;
}

static void* consumer_thread(void* arg)
{
    spsc_it_ctx_t* ctx = (spsc_it_ctx_t*)arg;
    for(int i = 0; i < ctx->count; ++i)
    {
        int v = -1;
        while(spsc_ring_pop(ctx->ring, &v) != 0)
        {
            sched_yield();
        }
        if(v != i)
        {
            if(atomic_exchange(&ctx->error, 1) == 0)
            {
                atomic_store(&ctx->bad_expected, i);
                atomic_store(&ctx->bad_actual, v);
            }
        }
    }
    return NULL;
}

static void test_threaded_flow(void** state)
{
    (void)state;
    const int    count = 200000;
    spsc_ring_t* ring  = spsc_ring_init(1024);
    assert_non_null(ring);

    spsc_it_ctx_t ctx = {
        .ring         = ring,
        .count        = count,
        .error        = 0,
        .bad_expected = -1,
        .bad_actual   = -1,
    };

    pthread_t prod;
    pthread_t cons;
    assert_int_equal(0, pthread_create(&prod, NULL, producer_thread, &ctx));
    assert_int_equal(0, pthread_create(&cons, NULL, consumer_thread, &ctx));

    assert_int_equal(0, pthread_join(prod, NULL));
    assert_int_equal(0, pthread_join(cons, NULL));

    if(atomic_load(&ctx.error) != 0)
    {
        int expected = atomic_load(&ctx.bad_expected);
        int actual   = atomic_load(&ctx.bad_actual);
        fail_msg("threaded flow mismatch: expected %d, got %d", expected, actual);
    }

    assert_true(spsc_ring_is_empty(ring));
    spsc_ring_destroy(&ring);
    assert_null(ring);
}

int main(void)
{
    const struct CMUnitTest tests[] = {
        cmocka_unit_test(test_simple_flow),
        cmocka_unit_test(test_threaded_flow),
        cmocka_unit_test(test_size_never_underflows_concurrently),
    };

    return cmocka_run_group_tests(tests, NULL, NULL);
}
