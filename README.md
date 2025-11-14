# SPSCring

Single Producer Single Consumer (SPSC) ring buffer implemented in C11 with lock-free semantics for exactly one producer and one consumer thread.

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

Unit tests live under `tests/` and are powered by [cmocka](https://cmocka.org/). Make sure `cmocka` (plus `pkg-config` if available) is installed on your system. Once present you can run:

```bash
./utils/build_tests.sh
./utils/run_tests.sh          # or: ctest --test-dir build
```

Coverage generation mirrors the EMlog project. Install `gcovr` (preferred) or `lcov`/`genhtml` and run:

```bash
./utils/gen_coverage.sh
```

Artifacts such as `UT_coverage.html`, `UT_coverage.xml`, and a JSON summary are written to `tests/results/`.
