#include <assert.h>
#include <spscring.h>
#include <stdio.h>

int main(void)
{
    spsc_ring_t* ring = spsc_ring_init(8);
    assert(ring != NULL);
    for(int i = 1; i <= 8; ++i)
    {
        assert(spsc_ring_push(ring, i) == 0);
    }
    for(int i = 1; i <= 8; ++i)
    {
        int out = -1;
        assert(spsc_ring_pop(ring, &out) == 0);
        assert(out == i);
    }
    assert(spsc_ring_is_empty(ring));
    spsc_ring_destroy(&ring);
    assert(ring == NULL);
    printf("smoke test: installed package round-trips correctly\n");
    return 0;
}
