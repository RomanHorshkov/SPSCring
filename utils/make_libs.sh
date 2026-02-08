#!/usr/bin/env bash
set -euo pipefail

# SET THE SCRIPT TO GO INTO DESIRED FOLDER AND COME BACK FROM WHERE LAUNCHED.
# Save where launched the script from
START_DIR="$(pwd -P)"
# Always come back, even if something fails
cleanup() { cd -- "$START_DIR"; }
trap cleanup EXIT

# Set the project root (works regardless of where the script is launched from)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$ROOT_DIR"

# Read the VERSION file and split it into its components
V_FILE="VERSION"

# Check if the version file exists and it is a file
if [[ ! -e "$V_FILE" ]]; then
    # first print the script from which the error is coming
    echo ${BASH_SOURCE[0]} "VERSION file does not exist"
    exit 1
elif [[ ! -f "$V_FILE" ]]; then
    echo ${BASH_SOURCE[0]} "VERSION is not a file"
    exit 1
fi

VER="$(cat VERSION)"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VER"

# Display clearly what is happening
echo "compiling libraries for $ROOT_DIR project"
echo "VER=$VER" "MAJOR=$MAJOR MINOR=$MINOR PATCH=$PATCH"

# create build dir
mkdir -p build

# Set compilation flags
WARN_FLAGS=(
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

CFLAGS=(
  -std=c11
  -O2
  -I app/
  "${WARN_FLAGS[@]}"
)

# PIC object for shared lib
gcc "${CFLAGS[@]}" -fPIC -c app/spscring.c -o build/spscring.pic.o

# non-PIC object for static lib
gcc "${CFLAGS[@]}"       -c app/spscring.c -o build/spscring.o

# Create the shared .so library with the pic.o object file
gcc -shared -Wl,-soname,libspscring.so.$MAJOR -o build/libspscring.so.$VER build/spscring.pic.o

# Create the static .a library with the .o object file
ar rcs build/libspscring.a build/spscring.o

# Do not Link the new libraries, other scripts will.
#cd build/
#dln -sf libspscring.so.$VER libspscring.so.$MAJOR
#dln -sf libspscring.so.$VER libspscring.so

echo "compiled libraries for $ROOT_DIR project into $(pwd)"

# Remove useless files
#rm build/*.o
