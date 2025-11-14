# Tests rely on the libraries built in the app/ subdirectory. This file assumes
# add_subdirectory(app) has already been processed.

function(spscring_apply_coverage target_name)
    if(NOT SPSCRING_ENABLE_COVERAGE)
        return()
    endif()
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${target_name} PRIVATE --coverage -O0 -g)
        target_link_options(${target_name} PRIVATE --coverage)
    else()
        message(WARNING "Coverage requested but the active compiler does not support --coverage")
    endif()
endfunction()

if(TARGET spsc_ring_shared)
    set(SPSCRING_TEST_LIBRARY spsc_ring_shared)
elseif(TARGET spsc_ring_static)
    set(SPSCRING_TEST_LIBRARY spsc_ring_static)
else()
    message(FATAL_ERROR "No spsc_ring library targets are available for tests. Enable SPSCRING_BUILD_SHARED or SPSCRING_BUILD_STATIC.")
endif()

find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(CMOCKA QUIET cmocka)
endif()

if(CMOCKA_FOUND)
    add_library(cmocka_dep INTERFACE)
    target_include_directories(cmocka_dep INTERFACE ${CMOCKA_INCLUDE_DIRS})
    target_link_libraries(cmocka_dep INTERFACE ${CMOCKA_LIBRARIES})
else()
    find_path(CMOCKA_INCLUDE_DIR cmocka.h)
    find_library(CMOCKA_LIBRARY NAMES cmocka)
    if(NOT (CMOCKA_INCLUDE_DIR AND CMOCKA_LIBRARY))
        message(FATAL_ERROR "cmocka could not be found. Install libcmocka-dev (or equivalent) or set CMOCKA_INCLUDE_DIR / CMOCKA_LIBRARY.")
    endif()
    add_library(cmocka_dep INTERFACE)
    target_include_directories(cmocka_dep INTERFACE ${CMOCKA_INCLUDE_DIR})
    target_link_libraries(cmocka_dep INTERFACE ${CMOCKA_LIBRARY})
endif()
add_library(cmocka::cmocka ALIAS cmocka_dep)

set(SPSCRING_UNIT_TEST_SOURCES
    unit/unit_tests.c
)

add_executable(spsc_ring_unit_tests ${SPSCRING_UNIT_TEST_SOURCES})
target_include_directories(
    spsc_ring_unit_tests
    PRIVATE
        ${CMAKE_SOURCE_DIR}/app/include
        ${CMAKE_CURRENT_SOURCE_DIR}/unit
)
target_link_libraries(spsc_ring_unit_tests PRIVATE ${SPSCRING_TEST_LIBRARY} cmocka::cmocka)
spscring_apply_coverage(spsc_ring_unit_tests)

add_test(NAME spsc_ring_unit COMMAND spsc_ring_unit_tests)
