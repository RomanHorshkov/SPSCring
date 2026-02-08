/* Project: https://github.com/RomanHorshkov */
/**
 * @file spsc_ring.h
 * @brief Single-producer single-consumer (SPSC) ring buffer API.
 *
 * Constraints:
 * - Exactly one producer thread and one consumer thread.
 * - Capacity must be a power of two.
 * - Elements stored are `int` values.
 * - Indices are 64-bit and wrap-safe when used through this API.
 * - 64-bit atomic operations are expected to be available on the target.
 *
 * Correctness:
 * - Empty when `head == tail`.
 * - Full when `(tail - head) == size`.
 * - Indexing uses `index & (size - 1)` only for addressing.
 *
 * Threading:
 * - `spsc_ring_init` and `spsc_ring_destroy` are not thread-safe.
 * - `spsc_ring_push` is producer-only.
 * - `spsc_ring_pop` is consumer-only.
 */
#ifndef SPSC_RING_H
#define SPSC_RING_H

#include <stdint.h>

/**
 * @brief Opaque ring buffer handle.
 */
typedef struct spsc_ring spsc_ring_t;

/**
 * @brief Create and initialize a ring buffer.
 *
 * @param capacity Number of elements the ring can hold. Must be a power of two.
 * @return Pointer to a new ring on success, or NULL on invalid capacity or allocation failure.
 *
 * @note `capacity` must fit into platform allocation limits
 *       (i.e., `capacity * sizeof(int)` must fit in `size_t`).
 */
spsc_ring_t *spsc_ring_init(uint64_t capacity);

/**
 * @brief Push an element into the ring (producer-side).
 *
 * @param ring Ring buffer instance.
 * @param fd   Value to store.
 * @return 0 on success, -1 if the ring is full or the ring pointer is NULL.
 *
 * @note Must be called only by the single producer thread.
 */
int spsc_ring_push(spsc_ring_t *ring, int fd);

/**
 * @brief Pop an element from the ring (consumer-side).
 *
 * @param ring   Ring buffer instance.
 * @param out_fd Output location for the value. May be NULL to discard.
 * @return 0 on success, -1 if the ring is empty or the ring pointer is NULL.
 *
 * @note Must be called only by the single consumer thread.
 */
int spsc_ring_pop(spsc_ring_t *ring, int *out_fd);

/**
 * @brief Check whether the ring is empty.
 *
 * @param ring Ring buffer instance.
 * @return 1 if empty, 0 otherwise. Returns 1 if `ring` is NULL.
 */
int spsc_ring_is_empty(spsc_ring_t *ring);

/**
 * @brief Check whether the ring is full.
 *
 * @param ring Ring buffer instance.
 * @return 1 if full, 0 otherwise. Returns 0 if `ring` is NULL.
 */
int spsc_ring_is_full(spsc_ring_t *ring);

/**
 * @brief Destroy a ring buffer and set the caller's pointer to NULL.
 *
 * @param ring Pointer to the ring pointer. Safe to pass NULL.
 */
void spsc_ring_destroy(spsc_ring_t **ring);

#endif /* SPSC_RING_H */
