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

#include "spsc_ring.h"

#include <stdatomic.h>   /* C11 atomic operations and memory ordering */
#include <stddef.h>      /* size_t, SIZE_MAX */
#include <stdlib.h>      /* malloc, calloc, free */
#include <stdint.h>      /* uint64_t and other fixed-width integer types */

/*
 * Internal structure and invariants.
 * - size is a power of two
 * - mask = size - 1
 * - head/tail are 64-bit counters
 * - full: (tail - head) == size
 * - empty: head == tail
 */
struct spsc_ring
{
    int        *buf;            /* Circular buffer array of integers */
    uint64_t    size;           /* Ring size, MUST be power of 2 */
    uint64_t    mask;           /* mask = size - 1 for fast modulo */
    _Atomic uint64_t head;      /* Consumer's read index (atomically updated) */
    _Atomic uint64_t tail;      /* Producer's write index (atomically updated) */
};

/* Initialization. */
spsc_ring_t *spsc_ring_init(uint64_t capacity)
{
    /* Check input, not 0 and must be power of 2 */
    if((capacity == 0) || ((capacity & (capacity - 1)) != 0)) return NULL;

    if (capacity > (uint64_t)(SIZE_MAX / sizeof(int))) return NULL;

    spsc_ring_t *ring = calloc(1, sizeof(spsc_ring_t));
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
    ring->buf  = calloc(capacity, sizeof(*ring->buf));
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

/* Producer-side push. */
int spsc_ring_push(spsc_ring_t *ring, int fd)
{
    /*
     * Check if buffer is full
     * Buffer is full when (tail - head) == size
     * Masking is used only for indexing, not for full/empty checks
     */
    if (ring == NULL)
    {
        return -1;  // Invalid ring buffer pointer
    }
    
    else if (spsc_ring_is_full(ring))
    {
        return -1;  // Buffer is full, cannot push
    }

    else
    {
        /*
        * Load current tail position (next write location)
        * Use relaxed ordering because this thread owns the tail pointer
        * and doesn't need synchronization when reading its own position
        */
        uint64_t t = atomic_load_explicit(&ring->tail, memory_order_relaxed);
        
        /*
        * Load current head position (consumer's read position)
        * Use acquire ordering to synchronize with consumer's release store
        */
        // uint64_t h = atomic_load_explicit(&ring->head, memory_order_acquire);
    
    
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
    }
    
    return 0;  // Success
}

/* Consumer-side pop. */
int spsc_ring_pop(spsc_ring_t *ring, int *out_fd)
{
    if (ring == NULL)
    {
        return -1;  // Invalid ring buffer pointer
    }
    /*
     * Load current head position (next read location)
     * Use relaxed ordering because this thread owns the head pointer
     * and doesn't need synchronization when reading its own position
     */
    uint64_t h = atomic_load_explicit(&ring->head, memory_order_relaxed);
    
    /*
     * Load current tail position (producer's write position)
     * Use acquire ordering to synchronize with producer's release store
     * This ensures visibility of all buffer writes performed by the producer before advancing tail
     */
    // uint64_t t = atomic_load_explicit(&ring->tail, memory_order_acquire);
    
    /*
     * Check if buffer is empty
     * Buffer is empty when head equals tail
     * This means consumer has caught up to producer
     */
    if (spsc_ring_is_empty(ring))
    {
        return -1;  // Buffer is empty, cannot pop
    }
    
    if (out_fd)
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
    
    return 0;  // Success
}

int spsc_ring_is_empty(spsc_ring_t *ring)
{
    if (ring == NULL)
    {
        return 1;
    }
    /*
     * Load current head position (next read location)
     * Use relaxed ordering because this thread owns the head pointer
     * and doesn't need synchronization when reading its own position
     */
    uint64_t h = atomic_load_explicit(&ring->head, memory_order_relaxed);
    
    /*
     * Load current tail position (producer's write position)
     * Use acquire ordering to synchronize with producer's release store
     * This ensures visibility of all buffer writes performed by the producer before advancing tail
     */
    uint64_t t = atomic_load_explicit(&ring->tail, memory_order_acquire);

    return h == t;
}

int spsc_ring_is_full(spsc_ring_t *ring)
{
    if (ring == NULL)
    {
        return 0;
    }
    /*
     * Load current tail position (producer's write position)
     * Use relaxed ordering because this thread owns the tail pointer
     * and doesn't need synchronization when reading its own position
     */
    uint64_t t = atomic_load_explicit(&ring->tail, memory_order_relaxed);
    
    /*
     * Load current head position (consumer's read position)
     * Use acquire ordering to synchronize with consumer's release store
     * This ensures visibility of all buffer reads completed by the consumer before advancing head
     */
    uint64_t h = atomic_load_explicit(&ring->head, memory_order_acquire);

    return (t - h) == ring->size;
}



/* Destruction. */
void spsc_ring_destroy(spsc_ring_t **ring)
{
    /*
     * Check for valid pointers before attempting cleanup
     * Handles the case where destroy is called multiple times
     * or with NULL pointers
     */
    if (ring && *ring)
    {
        /*
         * Free the dynamically allocated buffer array
         * This releases the memory that holds the actual ring data
         */
        free((*ring)->buf);
        free(*ring);
        *ring = NULL;
    }
}
