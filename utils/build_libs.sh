#!/usr/bin/env bash
# =============================================================================
# build_libs.sh — build libspscring across the shared GCC profile catalog
#
# author  Roman Horshkov <github.com/RomanHorshkov>
# date    2026
# (c) 2026
# =============================================================================
#
# Usage:
#   ./utils/build_libs.sh [profile ...]    # default: debug audit sanitize release
#
# For each profile the library source is compiled twice — a PIC object for the
# shared library and a plain object for the static archive — into
# build/<profile>/obj/, then:
#
#   build/<profile>/libspscring.so.<VERSION>   (+ .so / .so.<MAJOR> symlinks)
#   build/<profile>/libspscring.a
#
# The shared link uses LDFLAGS_SHARED from the catalog (full RELRO, -z defs,
# -z noexecstack, --as-needed). Profile LDFLAGS are NEVER passed to a shared
# link because they contain -pie, which breaks it; only the non--pie extras
# (sanitizer runtimes, -flto) are carried over.
#
# After a release build the historical flat build/ lib paths are re-created as
# symlinks into build/release/ (older scripts expect them), and
# utils/check_hardening.sh gates the release .so — a hard failure fails the
# build.
# =============================================================================
set -euo pipefail

START_DIR="$(pwd -P)"
cleanup() { cd -- "${START_DIR}"; }
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd -- "${ROOT_DIR}"

die() { printf '%s: %s\n' "${BASH_SOURCE[0]}" "$1" >&2; exit 1; }

PROFILE_FILE="${SCRIPT_DIR}/gcc_build_profiles.sh"
[[ -f "${PROFILE_FILE}" ]] || die "gcc profile catalog not found: ${PROFILE_FILE}"
# shellcheck source=/dev/null
source "${PROFILE_FILE}"

# --- project description ------------------------------------------------------
LIB_BASENAME="spscring"
LIB_SOURCES=(app/spscring.c)
LIB_CPPFLAGS=(-Iapp)
# spscring is C11-atomics + libc only; with -Wl,-z,defs any additional needed
# library would have to be named here explicitly.
LIB_LDLIBS=()

# --- version -------------------------------------------------------------------
[[ -f "${ROOT_DIR}/VERSION" ]] || die "VERSION file not found in ${ROOT_DIR}"
VER="$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")"
MAJOR="${VER%%.*}"
[[ -n "${MAJOR}" && "${MAJOR}" != "${VER}" ]] || die "cannot parse MAJOR from VERSION '${VER}'"

BUILD_DIR="${ROOT_DIR}/build"
AR_TOOL="$(command -v gcc-ar || command -v ar)" || die "no ar tool found"
mkdir -p "${BUILD_DIR}"

if (($# > 0)); then
    PROFILE_NAMES=("$@")
else
    PROFILE_NAMES=(debug audit sanitize release)
fi

# Profile LDFLAGS that may accompany LDFLAGS_SHARED into a shared link:
# everything except -pie (gcc -shared ... -pie links an executable image,
# demands main, and FAILS — see the LDFLAGS_SHARED catalog comment).
filter_shared_extra_ldflags() {
    local flag
    for flag in "$@"; do
        case "${flag}" in
            -pie) ;;
            *) printf '%s\0' "${flag}" ;;
        esac
    done
}

build_profile() {
    local profile="$1"
    local upper="${profile^^}"
    local cpp_var="CPPFLAGS_${upper}" c_var="CFLAGS_${upper}" ld_var="LDFLAGS_${upper}"

    declare -p "${cpp_var}" >/dev/null 2>&1 || die "unknown profile: ${profile}"

    declare -n cppflags_ref="${cpp_var}"
    declare -n cflags_ref="${c_var}"
    declare -n ldflags_ref="${ld_var}"

    local profile_dir="${BUILD_DIR}/${profile}"
    local obj_pic_dir="${profile_dir}/obj/pic"
    local obj_static_dir="${profile_dir}/obj/static"
    local shared_realname="lib${LIB_BASENAME}.so.${VER}"
    local shared_soname="lib${LIB_BASENAME}.so.${MAJOR}"
    local shared_linkname="lib${LIB_BASENAME}.so"
    local static_libname="lib${LIB_BASENAME}.a"
    local shared_path="${profile_dir}/${shared_realname}"
    local static_path="${profile_dir}/${static_libname}"
    local pic_objects=()
    local static_objects=()
    local source_path object_rel pic_object static_object

    mkdir -p "${obj_pic_dir}" "${obj_static_dir}"
    rm -f "${profile_dir}/${static_libname}" \
          "${profile_dir}/${shared_linkname}" \
          "${profile_dir}/${shared_linkname}".*

    printf '\n[%s]\n' "${profile}"

    for source_path in "${LIB_SOURCES[@]}"; do
        object_rel="$(basename "${source_path%.c}").o"
        pic_object="${obj_pic_dir}/${object_rel}"
        static_object="${obj_static_dir}/${object_rel}"

        printf '  compiling PIC object:    %s\n' "${pic_object}"
        gcc "${cppflags_ref[@]}" "${LIB_CPPFLAGS[@]}" "${cflags_ref[@]}" -fPIC \
            -c "${source_path}" -o "${pic_object}"

        printf '  compiling static object: %s\n' "${static_object}"
        gcc "${cppflags_ref[@]}" "${LIB_CPPFLAGS[@]}" "${cflags_ref[@]}" \
            -c "${source_path}" -o "${static_object}"

        pic_objects+=("${pic_object}")
        static_objects+=("${static_object}")
    done

    local extra_ldflags=()
    mapfile -d '' -t extra_ldflags < <(filter_shared_extra_ldflags "${ldflags_ref[@]}")

    printf '  linking shared library:  %s\n' "${shared_path}"
    gcc "${LDFLAGS_SHARED[@]}" "${extra_ldflags[@]}" \
        -Wl,-soname,"${shared_soname}" \
        -o "${shared_path}" \
        "${pic_objects[@]}" \
        ${LIB_LDLIBS[@]+"${LIB_LDLIBS[@]}"}

    printf '  creating static library: %s\n' "${static_path}"
    "${AR_TOOL}" rcs "${static_path}" "${static_objects[@]}"

    ln -sfn "${shared_realname}" "${profile_dir}/${shared_soname}"
    ln -sfn "${shared_realname}" "${profile_dir}/${shared_linkname}"

    if [[ "${profile}" == "release" ]]; then
        # Backwards compatibility: older scripts (make_deb-era, make_UTs_release)
        # expect the flat build/ lib paths. Keep them as symlinks into
        # build/release/.
        ln -sfn "release/${shared_realname}" "${BUILD_DIR}/${shared_realname}"
        ln -sfn "release/${shared_realname}" "${BUILD_DIR}/${shared_soname}"
        ln -sfn "release/${shared_realname}" "${BUILD_DIR}/${shared_linkname}"
        ln -sfn "release/${static_libname}"  "${BUILD_DIR}/${static_libname}"

        printf '  hardening check:         %s\n' "${shared_path}"
        "${ROOT_DIR}/utils/check_hardening.sh" "${shared_path}"
    fi
}

printf 'building lib%s in %s\n' "${LIB_BASENAME}" "${BUILD_DIR}"
printf 'version: %s (MAJOR=%s)\n' "${VER}" "${MAJOR}"

for profile in "${PROFILE_NAMES[@]}"; do
    build_profile "${profile}"
done

printf '\nartifacts:\n'
for profile in "${PROFILE_NAMES[@]}"; do
    printf '  %s\n' "${BUILD_DIR}/${profile}/lib${LIB_BASENAME}.a"
    printf '  %s\n' "${BUILD_DIR}/${profile}/lib${LIB_BASENAME}.so.${VER}"
done
