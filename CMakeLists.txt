cmake_minimum_required(VERSION 3.18)

project(spsc_ring VERSION 1.0.0 LANGUAGES C)

option(SPSCRING_BUILD_STATIC "Build the static libspscring.a archive" ON)
option(SPSCRING_BUILD_SHARED "Build the shared libspscring.so library" ON)
option(SPSCRING_BUILD_TESTS "Build spsc_ring unit/integration tests" OFF)
option(SPSCRING_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
option(SPSCRING_ENABLE_COVERAGE "Enable gcov-style coverage instrumentation" OFF)

add_subdirectory(app)

if(SPSCRING_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
