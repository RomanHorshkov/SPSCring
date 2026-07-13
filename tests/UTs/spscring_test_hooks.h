/* Test-only allocation seam for deterministic spsc_ring_init failure tests. */
#ifndef SPSCRING_TEST_HOOKS_H
#define SPSCRING_TEST_HOOKS_H

#include <stddef.h>

typedef void* (*spsc_ring_test_aligned_alloc_fn)(size_t alignment, size_t size);
typedef void* (*spsc_ring_test_calloc_fn)(size_t count, size_t size);
typedef void (*spsc_ring_test_free_fn)(void* ptr);

/* All allocator arguments must be non-NULL. Only available in test builds
 * compiled with SPSC_RING_TESTING. */
void spsc_ring_test_set_allocators(spsc_ring_test_aligned_alloc_fn aligned_allocator,
                                   spsc_ring_test_calloc_fn        calloc_allocator,
                                   spsc_ring_test_free_fn          free_allocator);
void spsc_ring_test_reset_allocators(void);

#endif /* SPSCRING_TEST_HOOKS_H */
