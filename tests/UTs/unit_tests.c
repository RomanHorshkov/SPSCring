#include <setjmp.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include <cmocka.h>
#include "spscring.h"

#ifdef SPSC_RING_TESTING
#    include "spscring_test_hooks.h"
#endif

static spsc_ring_t* create_ring(uint64_t capacity)
{
    spsc_ring_t* ring = spsc_ring_init(capacity);
    assert_non_null(ring);
    assert_true(spsc_ring_is_empty(ring));
    return ring;
}

static void destroy_ring(spsc_ring_t** ring_handle)
{
    spsc_ring_destroy(ring_handle);
    assert_null(*ring_handle);
}

static void test_init_accepts_power_of_two(void** state)
{
    (void)state;
    spsc_ring_t* ring = create_ring(16);
    assert_true(spsc_ring_is_empty(ring));
    destroy_ring(&ring);
}

static void test_init_rejects_invalid_capacity(void** state)
{
    (void)state;
    assert_null(spsc_ring_init(0));
    assert_null(spsc_ring_init(3));
}

#ifdef SPSC_RING_TESTING
static unsigned int free_call_count;
static unsigned int calloc_call_count;

static void* fail_aligned_alloc(size_t alignment, size_t size)
{
    (void)alignment;
    (void)size;
    return NULL;
}

static void* fail_calloc(size_t count, size_t size)
{
    (void)count;
    (void)size;
    return NULL;
}

static void* counting_calloc(size_t count, size_t size)
{
    calloc_call_count++;
    return calloc(count, size);
}

static void counting_free(void* ptr)
{
    free_call_count++;
    free(ptr);
}

static void test_init_handles_control_allocation_failure(void** state)
{
    (void)state;
    spsc_ring_test_set_allocators(fail_aligned_alloc, calloc, free);
    assert_null(spsc_ring_init(16));
}

static void test_init_cleans_up_after_buffer_allocation_failure(void** state)
{
    (void)state;
    spsc_ring_test_set_allocators(aligned_alloc, fail_calloc, counting_free);
    assert_null(spsc_ring_init(16));
    assert_int_equal(1, (int)free_call_count);
}

static void test_init_rejects_non_lock_free_head(void** state)
{
    (void)state;
    spsc_ring_test_set_allocators(aligned_alloc, counting_calloc, counting_free);
    spsc_ring_test_set_lock_free_overrides(0, 1);
    assert_null(spsc_ring_init(16));
    assert_int_equal(0, (int)calloc_call_count);
    assert_int_equal(1, (int)free_call_count);
}

static void test_init_rejects_non_lock_free_tail(void** state)
{
    (void)state;
    spsc_ring_test_set_allocators(aligned_alloc, counting_calloc, counting_free);
    spsc_ring_test_set_lock_free_overrides(1, 0);
    assert_null(spsc_ring_init(16));
    assert_int_equal(0, (int)calloc_call_count);
    assert_int_equal(1, (int)free_call_count);
}

static int reset_allocator_hooks(void** state)
{
    (void)state;
    spsc_ring_test_reset_allocators();
    free_call_count = 0U;
    calloc_call_count = 0U;
    return 0;
}
#endif

static void test_push_pop_fifo_order(void** state)
{
    (void)state;
    spsc_ring_t* ring = create_ring(8);

    for(int value = 0; value < 8; ++value)
    {
        assert_int_equal(0, spsc_ring_push(ring, value));
    }
    assert_false(spsc_ring_is_empty(ring));

    for(int expected = 0; expected < 8; ++expected)
    {
        int value = -1;
        assert_int_equal(0, spsc_ring_pop(ring, &value));
        assert_int_equal(expected, value);
    }
    assert_true(spsc_ring_is_empty(ring));
    destroy_ring(&ring);
}

static void test_detects_full_ring(void** state)
{
    (void)state;
    spsc_ring_t* ring = create_ring(4);

    assert_int_equal(0, spsc_ring_push(ring, 11));
    assert_int_equal(0, spsc_ring_push(ring, 22));
    assert_int_equal(0, spsc_ring_push(ring, 33));
    assert_int_equal(0, spsc_ring_push(ring, 44));
    assert_true(spsc_ring_is_full(ring));
    assert_int_equal(-1, spsc_ring_push(ring, 44));

    destroy_ring(&ring);
}

static void test_pop_from_empty_ring(void** state)
{
    (void)state;
    spsc_ring_t* ring = create_ring(8);

    int value = 0;
    assert_int_equal(-1, spsc_ring_pop(ring, &value));
    assert_true(spsc_ring_is_empty(ring));

    destroy_ring(&ring);
}

static void test_push_returns_error_when_ring_full(void** state)
{
    (void)state;
    spsc_ring_t* ring = create_ring(8);

    for(int i = 0; i < 8; ++i)
    {
        assert_int_equal(0, spsc_ring_push(ring, i));
    }
    assert_true(spsc_ring_is_full(ring));
    assert_int_equal(-1, spsc_ring_push(ring, 42));

    destroy_ring(&ring);
}

static void test_pop_succeeds_when_not_empty(void** state)
{
    (void)state;
    spsc_ring_t* ring = create_ring(8);

    assert_int_equal(0, spsc_ring_push(ring, 77));
    assert_int_equal(0, spsc_ring_push(ring, 77));
    int value = 0;
    assert_int_equal(0, spsc_ring_pop(ring, NULL));
    assert_int_equal(0, spsc_ring_pop(ring, &value));
    assert_int_equal(77, value);

    destroy_ring(&ring);
}

static void test_capacity_and_size(void** state)
{
    (void)state;
    spsc_ring_t* ring = create_ring(8);
    assert_int_equal(8, spsc_ring_capacity(ring));
    assert_int_equal(0, spsc_ring_size(ring));

    assert_int_equal(0, spsc_ring_push(ring, 1));
    assert_int_equal(0, spsc_ring_push(ring, 2));
    assert_int_equal(2, spsc_ring_size(ring));

    int v = -1;
    assert_int_equal(0, spsc_ring_pop(ring, &v));
    assert_int_equal(1, v);
    assert_int_equal(1, spsc_ring_size(ring));

    destroy_ring(&ring);
}

/* Regression for the size() underflow: across a long wrap-around sequence the
 * reported size must stay a sane [0, capacity] and equal the true occupancy —
 * never a huge value from tail-before-head sampling or from t-h wrapping. */
static void test_size_stays_bounded_across_wraparound(void** state)
{
    (void)state;
    spsc_ring_t*   ring      = create_ring(4);
    const uint64_t cap       = spsc_ring_capacity(ring);
    int            occupancy = 0;

    for(int step = 0; step < 1000; ++step)
    {
        /* Push while there's room, pop while there's data — an uneven mix that
         * marches head and tail far past the ring size (exercises wrap). */
        if((step % 3) != 0 && occupancy < (int)cap)
        {
            assert_int_equal(0, spsc_ring_push(ring, step));
            occupancy++;
        }
        else if(occupancy > 0)
        {
            int v = 0;
            assert_int_equal(0, spsc_ring_pop(ring, &v));
            occupancy--;
        }

        uint64_t sz = spsc_ring_size(ring);
        assert_int_equal((uint64_t)occupancy, sz); /* exact in single-thread */
        assert_true(sz <= cap);                    /* the clamp/bound invariant */
    }

    destroy_ring(&ring);
}

static void test_reset_clears_ring(void** state)
{
    (void)state;
    spsc_ring_t* ring = create_ring(8);
    assert_int_equal(0, spsc_ring_push(ring, 10));
    assert_int_equal(0, spsc_ring_push(ring, 20));
    assert_false(spsc_ring_is_empty(ring));
    assert_int_equal(2, spsc_ring_size(ring));

    spsc_ring_reset(ring);
    assert_true(spsc_ring_is_empty(ring));
    assert_int_equal(0, spsc_ring_size(ring));

    int v = -1;
    assert_int_equal(-1, spsc_ring_pop(ring, &v));

    destroy_ring(&ring);
}

static void test_destroy_handles_null_pointer(void** state)
{
    (void)state;
    spsc_ring_destroy(NULL);
}

static void test_destroy_handles_null_ring_instance(void** state)
{
    (void)state;
    spsc_ring_t* ring = NULL;
    spsc_ring_destroy(&ring);
    assert_null(ring);
}

static void test_functions_with_null_ring(void** state)
{
    (void)state;
    assert_null(spsc_ring_init(0));
    assert_null(spsc_ring_init(3));
    assert_null(spsc_ring_init(7));
    assert_null(spsc_ring_init(4611686018427387904));
    assert_int_equal(-1, spsc_ring_push(NULL, 42));
    assert_int_equal(-1, spsc_ring_pop(NULL, NULL));
    assert_int_equal(0, spsc_ring_is_empty(NULL));
    assert_int_equal(0, spsc_ring_is_full(NULL));
    assert_int_equal(0, spsc_ring_capacity(NULL));
    assert_int_equal(0, spsc_ring_size(NULL));
    spsc_ring_reset(NULL);
}

int main(void)
{
    const struct CMUnitTest tests[] = {
        cmocka_unit_test(test_init_accepts_power_of_two),
        cmocka_unit_test(test_init_rejects_invalid_capacity),
#ifdef SPSC_RING_TESTING
        cmocka_unit_test_setup_teardown(test_init_handles_control_allocation_failure, reset_allocator_hooks, reset_allocator_hooks),
        cmocka_unit_test_setup_teardown(test_init_cleans_up_after_buffer_allocation_failure, reset_allocator_hooks, reset_allocator_hooks),
        cmocka_unit_test_setup_teardown(test_init_rejects_non_lock_free_head, reset_allocator_hooks, reset_allocator_hooks),
        cmocka_unit_test_setup_teardown(test_init_rejects_non_lock_free_tail, reset_allocator_hooks, reset_allocator_hooks),
#endif
        cmocka_unit_test(test_push_pop_fifo_order),
        cmocka_unit_test(test_detects_full_ring),
        cmocka_unit_test(test_pop_from_empty_ring),
        cmocka_unit_test(test_push_returns_error_when_ring_full),
        cmocka_unit_test(test_pop_succeeds_when_not_empty),
        cmocka_unit_test(test_capacity_and_size),
        cmocka_unit_test(test_size_stays_bounded_across_wraparound),
        cmocka_unit_test(test_reset_clears_ring),
        cmocka_unit_test(test_destroy_handles_null_pointer),
        cmocka_unit_test(test_destroy_handles_null_ring_instance),
        cmocka_unit_test(test_functions_with_null_ring),
    };

    return cmocka_run_group_tests(tests, NULL, NULL);
}
