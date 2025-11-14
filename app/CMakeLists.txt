cmake_minimum_required(VERSION 3.18)

if(NOT DEFINED PROJECT_NAME)
    set(SPSCRING_STANDALONE_PROJECT TRUE)
    project(spsc_ring VERSION 1.0.0 LANGUAGES C)
endif()

option(SPSCRING_BUILD_STATIC "Build the static libspscring.a archive" ON)
option(SPSCRING_BUILD_SHARED "Build the shared libspscring.so library" ON)
option(SPSCRING_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
option(SPSCRING_ENABLE_COVERAGE "Enable gcov-style coverage instrumentation" OFF)

set(SPSCRING_HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/include/spsc_ring.h)
set(SPSCRING_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/spsc_ring.c)

add_library(spsc_ring_obj OBJECT ${SPSCRING_SOURCES})
target_include_directories(spsc_ring_obj PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_features(spsc_ring_obj PUBLIC c_std_11)
set(SPSCRING_GNU_CLANG_WARNINGS
    -Wall
    -Wextra
    -Wpedantic
    -Wshadow
    -Wformat=2
    -Wconversion
    -Wnull-dereference
    -Wdouble-promotion
    -Wduplicated-cond
    -Wduplicated-branches
    -Wlogical-op
    -Wfloat-equal
    -Wunsafe-loop-optimizations
)
target_compile_options(
    spsc_ring_obj
    PRIVATE
        $<$<C_COMPILER_ID:GNU,Clang,AppleClang>:${SPSCRING_GNU_CLANG_WARNINGS}>
        $<$<AND:$<NOT:$<BOOL:${SPSCRING_ENABLE_COVERAGE}>>,$<C_COMPILER_ID:GNU,Clang,AppleClang>>:-O2>
        $<$<AND:$<BOOL:${SPSCRING_WARNINGS_AS_ERRORS}>,$<C_COMPILER_ID:GNU,Clang,AppleClang>>:-Werror>
)
if(SPSCRING_ENABLE_COVERAGE AND CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(spsc_ring_obj PRIVATE --coverage -O0 -g)
endif()
set_target_properties(spsc_ring_obj PROPERTIES POSITION_INDEPENDENT_CODE ON)

if(SPSCRING_BUILD_STATIC)
    add_library(spsc_ring_static STATIC $<TARGET_OBJECTS:spsc_ring_obj>)
    target_include_directories(spsc_ring_static PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
    set_target_properties(spsc_ring_static PROPERTIES OUTPUT_NAME spsc_ring)
endif()

if(SPSCRING_BUILD_SHARED)
    add_library(spsc_ring_shared SHARED $<TARGET_OBJECTS:spsc_ring_obj>)
    target_include_directories(spsc_ring_shared PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
    set_target_properties(
        spsc_ring_shared
        PROPERTIES
            OUTPUT_NAME spsc_ring
            SOVERSION 1
            VERSION ${PROJECT_VERSION}
            WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()

if(SPSCRING_ENABLE_COVERAGE AND CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    foreach(lib spsc_ring_static spsc_ring_shared)
        if(TARGET ${lib})
            target_link_options(${lib} PRIVATE --coverage)
        endif()
    endforeach()
endif()

if(SPSCRING_STANDALONE_PROJECT)
    foreach(dir ARCHIVE LIBRARY RUNTIME)
        set(CMAKE_${dir}_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
    endforeach()
endif()
