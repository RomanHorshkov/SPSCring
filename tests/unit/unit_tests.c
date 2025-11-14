#include <stdarg.h>
#include <stddef.h>
#include <setjmp.h>
#include <stdint.h>
#include <cmocka.h>

#include "spsc_ring.h"

static spsc_ring_t *create_ring(uint32_t capacity)
{
    spsc_ring_t *ring = spsc_ring_init(capacity);
    assert_non_null(ring);
    assert_true(spsc_ring_is_empty(ring));
    return ring;
}

static void destroy_ring(spsc_ring_t **ring_handle)
{
    spsc_ring_destroy(ring_handle);
    assert_null(*ring_handle);
}

static void test_init_accepts_power_of_two(void **state)
{
    (void)state;
    spsc_ring_t *ring = create_ring(16);
    assert_true(spsc_ring_is_empty(ring));
    destroy_ring(&ring);
}

static void test_init_rejects_invalid_capacity(void **state)
{
    (void)state;
    assert_null(spsc_ring_init(0));
    assert_null(spsc_ring_init(3));
}

static void test_push_pop_fifo_order(void **state)
{
    (void)state;
    spsc_ring_t *ring = create_ring(8);

    for(int value = 0; value < 5; ++value)
    {
        assert_int_equal(0, spsc_ring_push(ring, value));
    }
    assert_false(spsc_ring_is_empty(ring));

    for(int expected = 0; expected < 5; ++expected)
    {
        int value = -1;
        assert_int_equal(0, spsc_ring_pop(ring, &value));
        assert_int_equal(expected, value);
    }
    assert_true(spsc_ring_is_empty(ring));
    destroy_ring(&ring);
}

static void test_detects_full_ring(void **state)
{
    (void)state;
    spsc_ring_t *ring = create_ring(4);

    assert_int_equal(0, spsc_ring_push(ring, 11));
    assert_int_equal(0, spsc_ring_push(ring, 22));
    assert_int_equal(0, spsc_ring_push(ring, 33));
    assert_true(spsc_ring_is_full(ring));
    assert_int_equal(-1, spsc_ring_push(ring, 44));

    destroy_ring(&ring);
}

static void test_pop_from_empty_ring(void **state)
{
    (void)state;
    spsc_ring_t *ring = create_ring(8);

    int value = 0;
    assert_int_equal(-1, spsc_ring_pop(ring, &value));
    assert_true(spsc_ring_is_empty(ring));

    destroy_ring(&ring);
}

static void test_push_returns_error_when_ring_full(void **state)
{
    (void)state;
    spsc_ring_t *ring = create_ring(8);

    for(int i = 0; i < 7; ++i)
    {
        assert_int_equal(0, spsc_ring_push(ring, i));
    }
    assert_true(spsc_ring_is_full(ring));
    assert_int_equal(-1, spsc_ring_push(ring, 42));

    destroy_ring(&ring);
}

static void test_pop_succeeds_when_not_empty(void **state)
{
    (void)state;
    spsc_ring_t *ring = create_ring(8);

    assert_int_equal(0, spsc_ring_push(ring, 77));
    int value = 0;
    assert_int_equal(0, spsc_ring_pop(ring, &value));
    assert_int_equal(77, value);

    destroy_ring(&ring);
}

static void test_destroy_handles_null_pointer(void **state)
{
    (void)state;
    spsc_ring_destroy(NULL);
}

static void test_destroy_handles_null_ring_instance(void **state)
{
    (void)state;
    spsc_ring_t *ring = NULL;
    spsc_ring_destroy(&ring);
    assert_null(ring);
}

int main(void)
{
    const struct CMUnitTest tests[] = {
        cmocka_unit_test(test_init_accepts_power_of_two),
        cmocka_unit_test(test_init_rejects_invalid_capacity),
        cmocka_unit_test(test_push_pop_fifo_order),
        cmocka_unit_test(test_detects_full_ring),
        cmocka_unit_test(test_pop_from_empty_ring),
        cmocka_unit_test(test_push_returns_error_when_ring_full),
        cmocka_unit_test(test_pop_succeeds_when_not_empty),
        cmocka_unit_test(test_destroy_handles_null_pointer),
        cmocka_unit_test(test_destroy_handles_null_ring_instance),
    };

    return cmocka_run_group_tests(tests, NULL, NULL);
}
