#!/usr/bin/env bash
# =============================================================================
# build_deb.sh — package the release-profile libspscring artifacts into debs
#
# author  Roman Horshkov <github.com/RomanHorshkov>
# date    2026
# (c) 2026
# =============================================================================
#
# Produces the standard Debian library split:
#
#   libspscring_<ver>_<arch>.deb      runtime: libspscring.so.<ver> + soname symlink
#   libspscring-dev_<ver>_<arch>.deb  development: spscring.h, libspscring.a,
#                                     libspscring.so linker symlink; depends on
#                                     the exact-version runtime package
#
# plus a SHA256SUMS manifest covering both, in build/debs/.
#
# Both packages conflict with and replace the former single package "spscring",
# so upgrading a machine that still has it installed is one apt install.
# =============================================================================
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LIB="spscring"
PKG_RUNTIME="libspscring"
PKG_DEV="libspscring-dev"
PKG_OLD="spscring"
DESCRIPTION="Single-producer single-consumer lock-free ring buffer library"
STRIP="${STRIP:-strip}"

die() { printf '%s: %s\n' "${BASH_SOURCE[0]}" "$1" >&2; exit 1; }

cd "$ROOT_DIR"

# Read + validate version (packaged versions must be strict semver).
VER="$(tr -d '[:space:]' < VERSION)"
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION '${VER}' does not match ^[0-9]+\\.[0-9]+\\.[0-9]+\$"

# Build the release library artifacts (also refreshes the flat build/ symlinks
# and runs the hardening gate on the freshly linked .so).
./utils/build_libs.sh release

ARCH="$(dpkg --print-architecture)"

# Split version safely (keep IFS local)
IFS='.' read -r MAJOR MINOR PATCH <<< "$VER"

# Ship the DEP-5 copyright file (first-party terms + every third-party notice)
# at /usr/share/doc/<pkg>/copyright (Debian Policy 12.5). A missing file is a
# build error: a binary must never leave without its notices.
COPYRIGHT_SRC="${ROOT_DIR}/debian/copyright"
[[ -f "${COPYRIGHT_SRC}" ]] || die "missing ${COPYRIGHT_SRC} — third-party notices must ship in the deb"

OUT_DIR="${OUT_DIR:-${ROOT_DIR}/build/debs}"
# Start clean: stale debs (including ones from before a package rename) must
# never linger into the SHA256SUMS manifest or a report.
rm -rf "$OUT_DIR"
install -d -m 0755 "$OUT_DIR"

# stage_dirs <stage> <subdir>... : explicit 0755 so the shipped paths never
# depend on the calling shell's umask.
stage_dirs() {
    local stage="$1"; shift
    rm -rf "$stage"
    install -d -m 0755 "$stage" "$stage/DEBIAN" "$stage/usr" "$stage/usr/local" \
        "$stage/usr/share" "$stage/usr/share/doc"
    local d
    for d in "$@"; do install -d -m 0755 "$stage/usr/local/$d"; done
}

# ldconfig hooks so the runtime linker sees the library immediately
write_ldconfig_hooks() {
    local stage="$1" hook
    for hook in postinst postrm; do
        printf '#!/bin/sh\nset -e\nldconfig\nexit 0\n' > "$stage/DEBIAN/$hook"
        chmod 0755 "$stage/DEBIAN/$hook"
    done
}

# --- runtime package -----------------------------------------------------------
STAGE_RT="${ROOT_DIR}/build/pkgroot/${PKG_RUNTIME}"
stage_dirs "$STAGE_RT" lib
LIB_RT="$STAGE_RT/usr/local/lib"

install -m 0755 "build/release/lib${LIB}.so.$VER" "$LIB_RT/lib${LIB}.so.$VER"
"$STRIP" --strip-unneeded "$LIB_RT/lib${LIB}.so.$VER"
ln -sf "lib${LIB}.so.$VER" "$LIB_RT/lib${LIB}.so.$MAJOR"

# Gate the staged, stripped shared library: the exact deb payload must carry
# the hardening the release profile promises. A hard failure aborts the build.
"${ROOT_DIR}/utils/check_hardening.sh" "$LIB_RT/lib${LIB}.so.$VER"

cat > "$STAGE_RT/DEBIAN/control" <<EOF
Package: $PKG_RUNTIME
Version: $VER
Section: libs
Priority: optional
Architecture: $ARCH
Conflicts: $PKG_OLD
Replaces: $PKG_OLD
Maintainer: Roman Horshkov <https://github.com/RomanHorshkov>
Description: $DESCRIPTION
EOF
write_ldconfig_hooks "$STAGE_RT"

install -d -m 0755 "${STAGE_RT}/usr/share/doc/${PKG_RUNTIME}"
install -m 0644 "${COPYRIGHT_SRC}" "${STAGE_RT}/usr/share/doc/${PKG_RUNTIME}/copyright"
DEB_RT="${PKG_RUNTIME}_${VER}_${ARCH}.deb"
fakeroot dpkg-deb --build "$STAGE_RT" "$OUT_DIR/$DEB_RT"

# --- development package --------------------------------------------------------
STAGE_DEV="${ROOT_DIR}/build/pkgroot/${PKG_DEV}"
stage_dirs "$STAGE_DEV" lib include
LIB_DEV="$STAGE_DEV/usr/local/lib"

install -m 0644 "app/${LIB}.h" "$STAGE_DEV/usr/local/include/${LIB}.h"
install -m 0644 "build/release/lib${LIB}.a" "$LIB_DEV/lib${LIB}.a"
ln -sf "lib${LIB}.so.$VER" "$LIB_DEV/lib${LIB}.so"

cat > "$STAGE_DEV/DEBIAN/control" <<EOF
Package: $PKG_DEV
Version: $VER
Section: libdevel
Priority: optional
Architecture: $ARCH
Depends: $PKG_RUNTIME (= $VER)
Conflicts: $PKG_OLD
Replaces: $PKG_OLD
Maintainer: Roman Horshkov <https://github.com/RomanHorshkov>
Description: Development files for $PKG_RUNTIME (header, static library, linker symlink)
EOF

install -d -m 0755 "${STAGE_DEV}/usr/share/doc/${PKG_DEV}"
install -m 0644 "${COPYRIGHT_SRC}" "${STAGE_DEV}/usr/share/doc/${PKG_DEV}/copyright"
DEB_DEV="${PKG_DEV}_${VER}_${ARCH}.deb"
fakeroot dpkg-deb --build "$STAGE_DEV" "$OUT_DIR/$DEB_DEV"

# --- manifest ----------------------------------------------------------------
(
    cd "$OUT_DIR"
    sha256sum -- *.deb > SHA256SUMS
)

printf '\nBuilt:\n  %s\n  %s\n' "$OUT_DIR/$DEB_RT" "$OUT_DIR/$DEB_DEV"
printf 'checksums: %s/SHA256SUMS\n' "$OUT_DIR"
printf 'install with: sudo apt install %s/%s %s/%s\n' "$OUT_DIR" "$DEB_RT" "$OUT_DIR" "$DEB_DEV"
