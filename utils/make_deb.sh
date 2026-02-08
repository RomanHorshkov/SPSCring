#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PKG_NAME="spscring"

cd "$ROOT_DIR"

# Build the library artifacts
./utils/make_libs.sh


# Read version + architecture
VER="$(< VERSION)"
ARCH="$(dpkg --print-architecture)"

# Split version safely (keep IFS local)
IFS='.' read -r MAJOR MINOR PATCH <<< "$VER"

# Prepare package staging dir (kept under build/ so it doesn't pollute the repo root).
STAGE="${ROOT_DIR}/build/pkgroot"
rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$STAGE/usr/local/lib" "$STAGE/usr/local/include"

# Install payload into /usr/local (inside the package)
install -m 0644 app/spscring.h "$STAGE/usr/local/include/spscring.h"

install -m 0755 "build/libspscring.so.$VER" "$STAGE/usr/local/lib/libspscring.so.$VER"
ln -sf "libspscring.so.$VER" "$STAGE/usr/local/lib/libspscring.so.$MAJOR"
ln -sf "libspscring.so.$VER" "$STAGE/usr/local/lib/libspscring.so"

install -m 0644 build/libspscring.a "$STAGE/usr/local/lib/libspscring.a"

# Control file
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VER
Section: libs
Priority: optional
Architecture: $ARCH
Maintainer: Roman Horshkov <https://github.com/RomanHorshkov>
Description: spscring personal library installed under /usr/local
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

echo
echo "Built complete"

OUT_DIR="${OUT_DIR:-${ROOT_DIR}/build/debs}"
mkdir -p "$OUT_DIR"
mv -f "$DEB" "$OUT_DIR/"

echo "see .deb info with dpkg-deb -c $DEB or dpkg-deb -I $DEB"
echo "moved to $OUT_DIR/"
echo "install with sudo apt install $OUT_DIR/$DEB"
