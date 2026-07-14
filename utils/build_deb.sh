#!/usr/bin/env bash
# =============================================================================
# build_deb.sh — package the release-profile libspscring artifacts into a .deb
#
# author  Roman Horshkov <github.com/RomanHorshkov>
# date    2026
# (c) 2026
# =============================================================================
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PKG_NAME="spscring"
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

# Prepare package staging dir (kept under build/ so it doesn't pollute the repo root).
STAGE="${ROOT_DIR}/build/pkgroot"
rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$STAGE/usr/local/lib" "$STAGE/usr/local/include"

# Install payload into /usr/local (inside the package)
install -m 0644 app/spscring.h "$STAGE/usr/local/include/spscring.h"

install -m 0755 "build/release/libspscring.so.$VER" "$STAGE/usr/local/lib/libspscring.so.$VER"
"$STRIP" --strip-unneeded "$STAGE/usr/local/lib/libspscring.so.$VER"
ln -sf "libspscring.so.$VER" "$STAGE/usr/local/lib/libspscring.so.$MAJOR"
ln -sf "libspscring.so.$VER" "$STAGE/usr/local/lib/libspscring.so"

install -m 0644 build/release/libspscring.a "$STAGE/usr/local/lib/libspscring.a"

# Gate the staged, stripped shared library: the exact deb payload must carry
# the hardening the release profile promises. A hard failure aborts the build.
"${ROOT_DIR}/utils/check_hardening.sh" "$STAGE/usr/local/lib/libspscring.so.$VER"

# Control file
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VER
Section: libs
Priority: optional
Architecture: $ARCH
Maintainer: Roman Horshkov <https://github.com/RomanHorshkov>
Description: Single-producer single-consumer lock-free ring buffer library
EOF

# post installation script
# ldconfig hooks so runtime linker sees it immediately
cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
ldconfig
exit 0
EOF
chmod 0755 "$STAGE/DEBIAN/postinst"

cat > "$STAGE/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
ldconfig
exit 0
EOF
chmod 0755 "$STAGE/DEBIAN/postrm"

# Build .deb
DEB="${PKG_NAME}_${VER}_${ARCH}.deb"
fakeroot dpkg-deb --build "$STAGE" "$DEB"

printf '\nBuilt complete\n'

OUT_DIR="${OUT_DIR:-${ROOT_DIR}/build/debs}"
mkdir -p "$OUT_DIR"
mv -f "$DEB" "$OUT_DIR/"

# Refresh the checksum manifest covering every deb sitting next to this one.
(
    cd "$OUT_DIR"
    sha256sum -- *.deb > SHA256SUMS
)
printf 'checksums: %s/SHA256SUMS\n' "$OUT_DIR"

printf 'see .deb info with dpkg-deb -c %s or dpkg-deb -I %s\n' "$DEB" "$DEB"
printf 'moved to %s/\n' "$OUT_DIR"
printf 'install with sudo apt install %s/%s\n' "$OUT_DIR" "$DEB"
