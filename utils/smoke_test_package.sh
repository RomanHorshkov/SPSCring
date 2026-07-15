#!/usr/bin/env bash
set -euo pipefail

# Package smoke test: proves the .deb genuinely works for an external consumer — compiles and
# runs a tiny program against ONLY the installed system paths (/usr/local/include,
# /usr/local/lib), never the repo's own build/ tree. This is deliberately NOT a rebuild of the
# library: if this script had to compile app/spscring.c itself, it would only prove the
# SOURCE works, not that the shipped, installed PACKAGE does.

START_DIR="$(pwd -P)"
cleanup() { cd -- "${START_DIR}"; }
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd -- "${ROOT_DIR}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"; cleanup' EXIT

if [[ ! -f /usr/local/include/spscring.h ]]; then
    printf 'smoke_test_package: /usr/local/include/spscring.h not found — install the .deb first\n' >&2
    exit 1
fi

cat > "${WORK_DIR}/smoke.c" <<'EOF'
#include <assert.h>
#include <stdio.h>
#include <spscring.h>

int main(void)
{
    spsc_ring_t* ring = spsc_ring_init(8);
    assert(ring != NULL);
    for (int i = 1; i <= 8; ++i) {
        assert(spsc_ring_push(ring, i) == 0);
    }
    for (int i = 1; i <= 8; ++i) {
        int out = -1;
        assert(spsc_ring_pop(ring, &out) == 0);
        assert(out == i);
    }
    assert(spsc_ring_is_empty(ring));
    spsc_ring_destroy(&ring);
    assert(ring == NULL);
    printf("smoke test: installed package round-trips correctly\n");
    return 0;
}
EOF

gcc -std=c11 -Wall -Wextra -Werror \
    -I/usr/local/include \
    "${WORK_DIR}/smoke.c" \
    -L/usr/local/lib -Wl,-rpath,/usr/local/lib -lspscring \
    -o "${WORK_DIR}/smoke"

"${WORK_DIR}/smoke"
