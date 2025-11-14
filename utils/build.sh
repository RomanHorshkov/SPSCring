#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper to build the spsc_ring libraries.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/build_libs.sh" "$@"
