#!/usr/bin/env bash
# run_pipeline.sh — thin wrapper: resolves build/sysroot (utils/deps.sh sysroot), then runs the pinned kyr-build's pipeline.sh;
# repository-specific stages come from KYR_PIPELINE_EXTRA in the project file. Exit 1 on any failure.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR
out="$("${ROOT_DIR}/utils/deps.sh" sysroot)" || { printf '%s\n' "${out}"; exit 1; }
eval "$(grep '^export' <<< "${out}")"
exec "${KYR_BUILD_DIR}/pipeline.sh" "$@"
