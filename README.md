# SPSCring

Single Producer Single Consumer (SPSC) ring buffer implemented in C11 with lock-free semantics for exactly one producer and one consumer thread.

Public API documentation is in `app/spsc_ring.h`.

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

The project now uses CMake exclusively. All logic lives under `app/` and produces both static (`libspscring.a`) and shared (`libspscring.so`) variants by default. The usual helper scripts are available under `utils/` to keep workflows consistent with the EMlog layout:

- `utils/build.sh` / `utils/build_libs.sh` – configure & build the libraries
- `utils/build_tests.sh` – configure with `SPSCRING_BUILD_TESTS=ON` and build the cmocka test binary
- `utils/run_tests.sh` – run the registered CTest suites
- `utils/gen_coverage.sh` – rebuild with `--coverage`, run the tests, and emit gcovr/lcov reports into `tests/results/`

Manual invocation is also straightforward:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --target spsc_ring_static spsc_ring_shared
```

## Tests & coverage

Unit tests live under `tests/` and are powered by [cmocka](https://cmocka.org/). Install `cmocka` (plus `pkg-config` if available) before running:

```bash
./utils/build_tests.sh
./utils/run_tests.sh          # or: ctest --test-dir build
```

Coverage generation mirrors the EMlog project. Install `gcovr` (preferred) or `lcov`/`genhtml` and run:

```bash
./utils/gen_coverage.sh
```

Artifacts such as `UT_coverage.html`, `UT_coverage.xml`, and a JSON summary are written to `tests/results/`.
