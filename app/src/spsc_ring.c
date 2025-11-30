/*
 * SPSC Ring Buffer Implementation
 * ===============================
 * 
 * This is a Single Producer Single Consumer (SPSC) lock-free ring buffer
 * implementation using atomic operations for thread-safe communication
 * between exactly one producer thread and one consumer thread.
 * 
 * Key Features:
 * - Lock-free design using C11 atomic operations
 * - Memory ordering guarantees for correct synchronization
 * - Power-of-two capacity for efficient modulo operations using bitwise AND
 * - Distinguishes between full and empty states without sacrificing a slot
 * 
 * Thread Safety:
 * - Safe for ONE producer thread and ONE consumer thread
 * - NOT safe for multiple producers or multiple consumers
 * - Uses acquire-release memory ordering for proper synchronization
 */

#include "spsc_ring.h"

#include <stdatomic.h>   /* C11 atomic operations and memory ordering */
#include <stdlib.h>      /* malloc, calloc, free */
#include <stdint.h>      /* uint32_t and other fixed-width integer types */

/*
 * SPSC Ring Buffer Structure
 * ==========================
 * 
 * The ring buffer uses a circular array with head and tail pointers.
 * The key insight is that we can distinguish between full and empty
 * states by checking if (tail + 1) == head (full) vs tail == head (empty).
 * 
 * Memory Layout:
 * - buf: Dynamically allocated array storing the actual data
 * - size: Total capacity (must be power of 2 for efficient masking)
 * - mask: Bitmask for wrapping indices (size - 1)
 * - head: Consumer's read position (atomic for thread safety)
 * - tail: Producer's write position (atomic for thread safety)
 * 
 * Invariants:
 * - size is always a power of 2
 * - mask = size - 1
 * - head and tail can wrap around using modulo arithmetic
 * - Buffer is empty when: head == tail
 * - Buffer is full when: (tail + 1) & mask == head & mask
 */
struct spsc_ring{
    int       *buf;            /* Circular buffer array of integers */
    uint32_t   size, mask;     /* Size must be power of two; mask = size−1 for fast modulo */
    _Atomic uint32_t head;     /* Consumer's read index (atomically updated) */
    _Atomic uint32_t tail;     /* Producer's write index (atomically updated) */
};

/*
 * Ring Buffer Initialization Function
 * ====================================
 * 
 * Initializes the global ring buffer with the specified capacity.
 * 
 * CRITICAL REQUIREMENT: The capacity MUST be a power of 2!
 * This is essential for the efficient masking operation (capacity - 1)
 * that allows us to wrap indices using bitwise AND instead of expensive modulo.
 * 
 * Parameters:
 * - capacity: The maximum number of elements the ring can hold
 *            MUST be a power of 2 (e.g., 2, 4, 8, 16, 32, 64, 128, ...)
 * 
 * Returns:
 * - Pointer to the initialized ring buffer
 * - Returns address of global 'g_ring' instance
 * 
 * Memory Initialization:
 * - Allocates buffer memory using calloc() (zeros the memory)
 * - Sets head and tail to 0 using atomic_store for thread safety
 * - Calculates mask for efficient index wrapping
 * 
 * Example Usage:
 *   spsc_ring_t *my_ring = spsc_ring_init(16);  // 16-element buffer
 * 
 * Thread Safety:
 * - This function should be called BEFORE any producer/consumer threads start
 * - Not thread-safe during initialization - call from main thread only
 */
spsc_ring_t *spsc_ring_init(uint32_t capacity)
{

    if ((capacity == 0) || ((capacity & (capacity - 1)) != 0))  // Check if capacity is a power of 2
    {
        return NULL;  // Invalid capacity, return NULL
    }
    else
    {
        spsc_ring_t *ring = calloc(1, sizeof(*ring));
        if(!ring) return NULL;
        /* 
         * Store the capacity and calculate the bitmask
         * The mask allows us to efficiently wrap indices:
         * Instead of: index % size (expensive division)
         * We use: index & mask (fast bitwise AND)
         * This only works when size is a power of 2!
         */
        ring->size = capacity;
        ring->mask = capacity - 1;
        
        /*
         * Allocate the circular buffer array
         * calloc() initializes all elements to 0, which is helpful for debugging
         * In production, you might use malloc() for slightly better performance
         */
        ring->buf  = calloc(capacity, sizeof(int));
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
}

/*
 * Ring Buffer Push Operation (Producer Function)
 * ==============================================
 * 
 * Adds a new element to the ring buffer. This function should ONLY be
 * called by the PRODUCER thread in an SPSC setup.
 * 
 * Algorithm Overview:
 * 1. Load current tail (producer's position) with relaxed ordering
 * 2. Load current head (consumer's position) with acquire ordering
 * 3. Check if buffer is full: (tail + 1) would equal head after wrapping
 * 4. If not full: store data at tail position and advance tail atomically
 * 
 * Parameters:
 * - ring: Pointer to the ring buffer structure
 * - fd: Integer value to push into the buffer (originally designed for file descriptors)
 * 
 * Returns:
 * - 0: Success - element was pushed
 * - -1: Failure - buffer is full
 * 
 * Memory Ordering Explanation:
 * - tail load (relaxed): We own tail, no synchronization needed for reading it
 * - head load (acquire): Synchronizes with consumer's head release, ensures we see
 *   all memory writes made by consumer before it updated head
 * - tail store (release): Makes our buffer write visible to consumer before
 *   updating tail pointer
 * 
 * Full Buffer Detection:
 * We check if (tail + 1) & mask == head & mask to detect fullness.
 * This means we sacrifice one slot to distinguish full from empty:
 * - Empty: head == tail
 * - Full: (tail + 1) == head (after wrapping)
 * 
 * Thread Safety:
 * - Safe for single producer thread
 * - Coordinates with single consumer through atomic head/tail
 */
int spsc_ring_push(spsc_ring_t *ring, int fd)
{
    /*
     * Check if buffer is full
     * Buffer is full when (tail + 1) would equal head after index wrapping
     * We use bitwise AND with mask for efficient modulo operation
     * 
     * Why this works:
     * - Empty condition: head == tail  
     * - Full condition: (tail + 1) == head (modulo buffer size)
     * - This sacrifices 1 buffer slot to distinguish these states
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
        * Load current tail position (where we'll write next)
        * Use relaxed ordering because this thread owns the tail pointer
        * and doesn't need synchronization when reading its own position
        */
        uint32_t t = atomic_load_explicit(&ring->tail, memory_order_relaxed);
        
        /*
        * Load current head position (consumer's read position)
        * Use acquire ordering to synchronize with consumer's release store
        */
        // uint32_t h = atomic_load_explicit(&ring->head, memory_order_acquire);
    
    
        /*
        * Store the data at the current tail position
        * Apply mask to wrap the index within buffer bounds
        * This is a regular (non-atomic) store because only producer writes to this slot
        */
        ring->buf[t & ring->mask] = fd;
    
        /*
         * Advance the tail pointer atomically with release ordering
         * Release ordering ensures that our buffer write above is visible
         * to the consumer before this tail update becomes visible
         * 
         * This creates a happens-before relationship: buffer write → tail update
         * Consumer will see tail update only after buffer write is complete
         */
        atomic_store_explicit(&ring->tail, t + 1, memory_order_release);
    }
    
    return 0;  // Success
}

/*
 * Ring Buffer Pop Operation (Consumer Function)
 * =============================================
 * 
 * Removes and returns an element from the ring buffer. This function should
 * ONLY be called by the CONSUMER thread in an SPSC setup.
 * 
 * Algorithm Overview:
 * 1. Load current head (consumer's position) with relaxed ordering
 * 2. Load current tail (producer's position) with acquire ordering  
 * 3. Check if buffer is empty: head equals tail
 * 4. If not empty: read data at head position and advance head atomically
 * 
 * Parameters:
 * - ring: Pointer to the ring buffer structure
 * - out_fd: Pointer to integer where popped value will be stored
 * 
 * Returns:
 * - 0: Success - element was popped and stored in *out_fd
 * - -1: Failure - buffer is empty, *out_fd unchanged
 * 
 * Memory Ordering Explanation:
 * - head load (relaxed): We own head, no synchronization needed for reading it
 * - tail load (acquire): Synchronizes with producer's tail release, ensures we see
 *   all memory writes made by producer before it updated tail
 * - head store (release): Makes our buffer read completion visible to producer
 *   before updating head pointer
 * 
 * Empty Buffer Detection:
 * We check if head & mask == tail & mask to detect emptiness.
 * When head equals tail (after wrapping), the buffer is empty.
 * 
 * Thread Safety:
 * - Safe for single consumer thread  
 * - Coordinates with single producer through atomic head/tail
 * - Output parameter is not protected - caller must ensure exclusive access
 */
int spsc_ring_pop(spsc_ring_t *ring, int *out_fd)
{
    /*
     * Load current head position (where we'll read next)
     * Use relaxed ordering because this thread owns the head pointer
     * and doesn't need synchronization when reading its own position
     */
    uint32_t h = atomic_load_explicit(&ring->head, memory_order_relaxed);
    
    /*
     * Load current tail position (producer's write position)
     * Use acquire ordering to synchronize with producer's release store
     * This ensures we see all buffer writes the producer did before advancing tail
     */
    // uint32_t t = atomic_load_explicit(&ring->tail, memory_order_acquire);
    
    /*
     * Check if buffer is empty
     * Buffer is empty when head equals tail (after index wrapping)
     * We use bitwise AND with mask for efficient modulo operation
     * 
     * Empty condition: head == tail
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
        *out_fd = ring->buf[h & ring->mask];
    }
    
    /*
     * Advance the head pointer atomically with release ordering
     * Release ordering ensures that our buffer read above completes
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
    /*
     * Load current head position (where we'll read next)
     * Use relaxed ordering because this thread owns the head pointer
     * and doesn't need synchronization when reading its own position
     */
    uint32_t h = atomic_load_explicit(&ring->head, memory_order_relaxed);
    
    /*
     * Load current tail position (producer's write position)
     * Use acquire ordering to synchronize with producer's release store
     * This ensures we see all buffer writes the producer did before advancing tail
     */
    uint32_t t = atomic_load_explicit(&ring->tail, memory_order_acquire);

    return (h & ring->mask) == (t & ring->mask);
}

int spsc_ring_is_full(spsc_ring_t *ring)
{
    /*
     * Load current head position (where we'll read next)
     * Use relaxed ordering because this thread owns the head pointer
     * and doesn't need synchronization when reading its own position
     */
    uint32_t h = atomic_load_explicit(&ring->head, memory_order_relaxed);
    
    /*
     * Load current tail position (producer's write position)
     * Use acquire ordering to synchronize with producer's release store
     * This ensures we see all buffer writes the producer did before advancing tail
     */
    uint32_t t = atomic_load_explicit(&ring->tail, memory_order_acquire);

    return ((t + 1) & ring->mask) == (h & ring->mask);
}



/*
 * Ring Buffer Cleanup Function
 * ============================
 * 
 * Safely destroys the ring buffer and frees allocated memory.
 * Uses double pointer pattern to set caller's pointer to NULL,
 * preventing use-after-free bugs.
 * 
 * Parameters:
 * - ring: Pointer to pointer to ring buffer structure
 *         After destruction, *ring will be set to NULL
 * 
 * Memory Safety:
 * - Frees the dynamically allocated buffer array
 * - Sets the caller's pointer to NULL to prevent accidental reuse
 * - Handles NULL pointers gracefully
 * 
 * Thread Safety:
 * - This function is NOT thread-safe
 * - Should only be called after all producer/consumer threads have stopped
 * - Typically called from main thread during program shutdown
 * 
 * Important Notes:
 * - This implementation uses a global ring instance, so the pointer
 *   nullification is somewhat symbolic since we can't free the global struct
 * - In a dynamic allocation design, this would also free the ring structure itself
 */
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
