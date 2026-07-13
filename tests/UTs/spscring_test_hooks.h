/* Test-only allocation and atomic-capability seam for deterministic
 * spsc_ring_init failure tests. */
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
/* Each argument is -1 to use the native C11 query, 0 to force non-lock-free,
 * or 1 to force lock-free. Only available in SPSC_RING_TESTING builds. */
void spsc_ring_test_set_lock_free_overrides(int head_is_lock_free, int tail_is_lock_free);

void spsc_ring_test_reset_allocators(void);

#endif /* SPSCRING_TEST_HOOKS_H */
