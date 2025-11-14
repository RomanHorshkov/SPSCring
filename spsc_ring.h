#ifndef SPSC_RING_H
#define SPSC_RING_H

#include <stdint.h>

typedef struct spsc_ring spsc_ring_t;

spsc_ring_t *spsc_ring_init(uint32_t capacity);

int spsc_ring_push(spsc_ring_t *ring, int fd);

int spsc_ring_pop(spsc_ring_t *ring, int *out_fd);

int spsc_ring_is_empty(spsc_ring_t *ring);

int spsc_ring_is_full(spsc_ring_t *ring);

void spsc_ring_destroy(spsc_ring_t **ring);

#endif // SPSC_RING_H
