#include "spsc_ring.h"

#include <stdio.h>

int main() {
    /* Initialize the ring buffer */
    spsc_ring_t *ring = spsc_ring_init(8);

    if (ring == NULL) {
        printf("Failed to initialize ring buffer.\n");
        return -1;
    }

    /* Push */
    for (int i = 0; i < 10; i++)
    {
        spsc_ring_push(ring, i+42);
    }

    if (spsc_ring_is_full(ring)) {
        printf("Ring buffer is full after pushing 10 elements.\n");
    } else {
        printf("Ring buffer is not full after pushing 10 elements.\n");
    }
    

    for (int i = 0; i < 10; i++)
    {
        int value;
        spsc_ring_pop(ring, &value);
        if (value != -1) {
            printf("Popped value: %d\n", value);
        } else {
            printf("Failed to pop value, ring buffer might be empty.\n");
        }
    }

    spsc_ring_push(ring, 52);
    spsc_ring_push(ring, 53);

    spsc_ring_pop(ring, NULL); // Test pop with NULL output
    spsc_ring_pop(ring, NULL); // Test pop with NULL output
    spsc_ring_pop(ring, NULL); // Test pop with NULL output


    if (spsc_ring_is_empty(ring)) {
        printf("Ring buffer is empty after operations.\n");
    } else {
        printf("Ring buffer still has elements.\n");
    }
    
    // Clean up
    spsc_ring_destroy(&ring);
    
    return 0;
}
