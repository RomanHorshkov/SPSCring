/* Project: https://github.com/RomanHorshkov */
/*
 * SPSC ring buffer implementation.
 *
 * Implementation notes:
 * - Single-producer, single-consumer only.
 * - Capacity is a power of two; mask = size - 1.
 * - Full when (tail - head) == size; empty when head == tail.
 * - Masking is used only for indexing.
 * - 64-bit counters provide wrap-safe arithmetic for long-lived processes.
 * - Memory ordering:
 *   Producer: relaxed load tail, store data, release store tail.
 *   Consumer: relaxed load head, read data, release store head.
 *   Visibility uses acquire loads in is_full/is_empty.
 */

#include "spscring.h"

#include <stdatomic.h> /* C11 atomic operations and memory ordering */
#include <stddef.h>    /* size_t, SIZE_MAX */
#include <stdint.h>    /* uint64_t and other fixed-width integer types */
#include <stdlib.h>    /* malloc, calloc, free */

/*
 * Internal structure and invariants.
 * - size is a power of two
 * - mask = size - 1
 * - head/tail are 64-bit counters
 * - full: (tail - head) == size
 * - empty: head == tail
 */
#ifndef SPSC_CACHELINE
#    define SPSC_CACHELINE 64u /* typical L1 line; only affects layout, not correctness */
#endif

struct spsc_ring
{
    int*     buf;  /* Circular buffer array of integers (read-only after init) */
    uint64_t size; /* Ring size, MUST be power of 2 (read-only after init) */
    uint64_t mask; /* mask = size - 1 for fast modulo   (read-only after init) */
    /* Consumer writes head, producer writes tail. Put each on its OWN cache line
     * so one side's update never invalidates the other side's line (false
     * sharing would otherwise bounce the line between cores on every op). */
    _Alignas(SPSC_CACHELINE) _Atomic uint64_t head; /* consumer's read index  */
    _Alignas(SPSC_CACHELINE) _Atomic uint64_t tail; /* producer's write index */
};

/* Compile-time proof that the false-sharing fix holds: head and tail must sit at
 * least one cache line apart (the test suite can't see these offsets — the type
 * is opaque — so we assert it here where the layout is defined). */
_Static_assert(offsetof(struct spsc_ring, tail) - offsetof(struct spsc_ring, head) >= SPSC_CACHELINE,
               "spsc_ring head and tail must be on separate cache lines");

spsc_ring_t* spsc_ring_init(uint64_t capacity)
{
    /* Check input, not 0 and must be power of 2 */
    if((capacity == 0) || ((capacity & (capacity - 1)) != 0)) return NULL;

    if(capacity > (uint64_t)(SIZE_MAX / sizeof(int))) return NULL;

    /* The struct is over-aligned (head/tail on separate cache lines), so it must
     * be allocated with matching alignment — plain malloc/calloc only guarantee
     * max_align_t. aligned_alloc needs size to be a multiple of the alignment,
     * which holds because _Alignas pads sizeof up to that alignment. It does not
     * zero, so every field is set explicitly below. */
    spsc_ring_t* ring = aligned_alloc(_Alignof(spsc_ring_t), sizeof(spsc_ring_t));
    if(!ring) return NULL;
    /*
     * Store the capacity and calculate the bitmask which allows to efficiently wrap indices:
     * Instead of: index % size (expensive division) use: index & mask (fast bitwise AND)
     * This only works when size is a power of 2
     */
    ring->size = capacity;
    ring->mask = capacity - 1;

    /*
     * Allocate the circular buffer array
     * calloc() initializes all elements to 0, which is helpful for debugging
     * malloc() can be used for slightly better performance in production
     */
    ring->buf = calloc(capacity, sizeof(*ring->buf));
    if(!ring->buf)
    {
        free(ring);
        return NULL;
    }

    /*
     * Initialize atomic head and tail pointers to 0
     * atomic_store() ensures these writes are visible to other threads
     * with proper memory ordering (default sequential consistency)
     *
     * Initial state: head = tail = 0 (empty buffer)
     */
    atomic_store(&ring->head, 0);
    atomic_store(&ring->tail, 0);

    /* Return pointer to the ring instance */
    return ring;
}

int spsc_ring_push(spsc_ring_t* ring, int fd)
{
    /* Check input */
    if(ring == NULL) return -1;

    /* Check if ring has capacity */
    if(spsc_ring_is_full(ring)) return -1;

    /*
     * Load current tail position (next write location)
     * Use relaxed ordering because this thread owns the tail pointer
     * and doesn't need synchronization when reading its own position
     */
    uint64_t t = atomic_load_explicit(&ring->tail, memory_order_relaxed);

    /*
     * Store the data at the current tail position
     * Apply mask to wrap the index within buffer bounds
     * This is a regular (non-atomic) store because only producer writes to this slot
     */
    ring->buf[(size_t)(t & ring->mask)] = fd;

    /*
     * Advance the tail pointer atomically with release ordering
     * Release ordering ensures that the buffer write above is visible
     * to the consumer before this tail update becomes visible
     *
     * This creates a happens-before relationship: buffer write → tail update
     * Consumer will see tail update only after buffer write is complete
     */
    atomic_store_explicit(&ring->tail, t + 1, memory_order_release);

    return 0;  // Success
}

int spsc_ring_pop(spsc_ring_t* ring, int* out_fd)
{
    /* Check input */
    if(ring == NULL) return -1;

    /* Check if ring has elements */
    if(spsc_ring_is_empty(ring)) return -1;

    /*
     * Load current head position (next read location)
     * Use relaxed ordering because this thread owns the head pointer
     * and doesn't need synchronization when reading its own position
     */
    uint64_t h = atomic_load_explicit(&ring->head, memory_order_relaxed);

    if(out_fd)
    {
        /*
         * Read the data from current head position
         * Apply mask to wrap the index within buffer bounds
         * This is a regular (non-atomic) load because only consumer reads from this slot
         * Store result in caller-provided output parameter
         */
        *out_fd = ring->buf[(size_t)(h & ring->mask)];
    }

    /*
     * Advance the head pointer atomically with release ordering
     * Release ordering ensures that the buffer read above completes
     * before this head update becomes visible to the producer
     *
     * This creates a happens-before relationship: buffer read → head update
     * Producer will see head update only after buffer read is complete
     * This allows producer to safely reuse this buffer slot
     */
    atomic_store_explicit(&ring->head, h + 1, memory_order_release);

    return 0;
}

int spsc_ring_is_empty(spsc_ring_t* ring)
{
    if(ring == NULL) return 0;
    /*
     * Load current head position (next read location)
     * Use relaxed ordering because this thread owns the head pointer
     * and doesn't need synchronization when reading its own position
     * And compare to current tail position (producer's write position)
     * Use acquire ordering to synchronize with producer's release store
     * This ensures visibility of all buffer writes performed by the producer before advancing tail
     */

    return atomic_load_explicit(&ring->head, memory_order_relaxed) == atomic_load_explicit(&ring->tail, memory_order_acquire);
}

int spsc_ring_is_full(spsc_ring_t* ring)
{
    if(ring == NULL) return 0;
    /*
     * Load current tail position (producer's write position)
     * Use relaxed ordering because this thread owns the tail pointer
     * and doesn't need synchronization when reading its own position
     * Load current head position (consumer's read position)
     * Use acquire ordering to synchronize with consumer's release store
     * This ensures visibility of all buffer reads completed by the consumer before advancing head
     */

    return (atomic_load_explicit(&ring->tail, memory_order_relaxed) - atomic_load_explicit(&ring->head, memory_order_acquire)) ==
           ring->size;
}

uint64_t spsc_ring_capacity(const spsc_ring_t* ring)
{
    if(ring == NULL) return 0;
    return ring->size;
}

uint64_t spsc_ring_size(const spsc_ring_t* ring)
{
    if(ring == NULL) return 0;
    /* APPROXIMATE under concurrency (either side may move between the two loads).
     * Load head BEFORE tail: both counters only increase and tail >= head always,
     * so a head sampled earlier can never exceed a tail sampled later — this
     * removes the underflow the reverse order allowed. Clamp to capacity as a
     * final guard so callers never see a nonsense count. */
    uint64_t h = atomic_load_explicit(&ring->head, memory_order_acquire);
    uint64_t t = atomic_load_explicit(&ring->tail, memory_order_acquire);
    uint64_t n = t - h;
    return (n > ring->size) ? ring->size : n;
}

void spsc_ring_reset(spsc_ring_t* ring)
{
    if(ring == NULL) return;
    atomic_store_explicit(&ring->head, 0, memory_order_relaxed);
    atomic_store_explicit(&ring->tail, 0, memory_order_relaxed);
}

void spsc_ring_destroy(spsc_ring_t** ring)
{
    /*
     * Check for valid pointers before attempting cleanup
     * Handles the case where destroy is called multiple times
     * or with NULL pointers
     */
    if(ring && *ring)
    {
        /*
         * Free the dynamically allocated buffer array
         * releasing the memory that holds the actual ring data
         */
        free((*ring)->buf);
        free(*ring);
        *ring = NULL;
    }
}
