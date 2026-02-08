# SPSCring

![tests](https://img.shields.io/badge/tests-local-blue)
![coverage](https://img.shields.io/badge/coverage-local-blue)
![license](https://img.shields.io/badge/license-MIT-green)

Single Producer Single Consumer (SPSC) ring buffer implemented in C11 with lock-free semantics for exactly one producer and one consumer thread.

Public API documentation is in `app/spscring.h`.

## API contract

The following behaviors are part of the public interface and must remain stable:

- `spsc_ring_push(NULL, ...)` returns `-1`.
- `spsc_ring_pop(NULL, ...)` returns `-1`.
- `spsc_ring_is_empty(NULL)` returns `0`.
- `spsc_ring_is_full(NULL)` returns `0`.
- `spsc_ring_capacity(NULL)` returns `0`.
- `spsc_ring_size(NULL)` returns `0`.
- `spsc_ring_reset(NULL)` is a no-op.
- `spsc_ring_destroy(NULL)` is a no-op.
- Exactly one producer and one consumer are supported.
- `spsc_ring_reset` is not thread-safe and must only be used when threads are stopped or externally synchronized.
- The ring stores `int` values.
- Capacity is fixed after initialization and must be a power of two.
- Empty when `head == tail`, full when `(tail - head) == size`.

## Index width, wrap, and uptime

Wrap means the counter goes back to 0 after hitting its maximum value (for example, `uint8_t` wraps after 255 to 0). Uptime is how long the process runs without restarting.

This ring uses full 64-bit counters for `head` and `tail`, and only masks for indexing. Empty and full checks are based on the full counters:

- Empty when `head == tail`.
- Full when `(tail - head) == size`.

This makes the algorithm safe even if the counters wrap multiple times. Correctness does not depend on uptime, so it stays correct even for extremely long runs (for example, “a million years”) as long as the SPSC usage rules are respected.

Why index width matters:

- `uint32_t` is commonly chosen because it is lock-free on virtually all 32-bit and 64-bit targets and keeps the struct small and cache-friendly. The downside is fast wrap at high throughput.
- `uint64_t` pushes wrap so far out that it is effectively irrelevant, and with the full-counter checks above it is safe even if it does wrap. This repo assumes 64-bit machines where 64-bit atomics are available.
- `uint8_t` is not practical. It wraps after 256 increments and makes masked full/empty checks break almost immediately. It also caps the maximum power-of-two capacity at 128.

Wrap time intuition for a counter of width `N`:

`wrap_time_seconds ≈ 2^N / ops_per_second`

Examples:

- At 1,000,000 ops/s, a `uint32_t` counter wraps in about 71 minutes.
- At 1,000,000 ops/s, a `uint64_t` counter wraps in about 584 years.

Breaking example (why masked checks are unsafe with small counters):

If `uint8_t` indices are used with the old masked empty check `(head & mask) == (tail & mask)`, then after 256 total increments the counters wrap. A buffer can be full while the masked check reports empty because `head` and `tail` map to the same masked value. Therefore the full-counter checks above are required for wrap safety.

Note on data type vs index type:

- The buffer element type is independent of the index width. It is valid to store `int` values while using `uint64_t` indices.

## Build system

Builds are driven by scripts under `utils/`:

- `utils/make_libs.sh` builds the static and shared libraries into `build/`.
- `utils/make_UTs_cov.sh` builds and runs unit tests with coverage output.
- `utils/make_UTs_release.sh` builds and runs unit tests against release libraries.
- `utils/make_ITs.sh` builds and runs integration tests.

## Tests & coverage

Unit tests live under `tests/UTs` and are powered by [cmocka](https://cmocka.org/). Install `cmocka` before running:

```bash
./utils/make_UTs_cov.sh
```

Release unit tests can be run with:

```bash
./utils/make_UTs_release.sh
```

Integration tests live under `tests/ITs` and can be run with:

```bash
./utils/make_ITs.sh
```

Coverage artifacts are written to `tests/results/UTs/`.

## License

MIT, see `LICENSE`.
