#!/usr/bin/env bash
# deps.sh — thin wrapper with one job of its own: bootstrap the pinned kyr-build (the `own kyr-build <ver> <repo> <sha256>`
# line of deps.txt) into build/sysroot/share/kyr-build, verified by sha256, then run its deps.sh with the same arguments.
# kyr-build cannot pin itself through the file it ships, so this is the one script a repository keeps (plan 4.1).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSROOT="${ROOT_DIR}/build/sysroot"
KYR_BUILD_DIR="${KYR_BUILD_DIR:-${SYSROOT}/share/kyr-build}"
CACHE_DIR="${KYR_DEPS_CACHE:-${HOME}/.cache/rh-deps}/debs"
die() { printf 'deps.sh: %s\n' "$*" >&2; exit 1; }
OLD_CACHE="RH""_DEPS_CACHE"; [[ -z "${!OLD_CACHE:-}" || -n "${KYR_DEPS_CACHE:-}" ]] || die "${OLD_CACHE} is no longer read: export KYR_DEPS_CACHE=${!OLD_CACHE}"   # 3.0.0: the Utils-era name alone is refused
[[ -f "${ROOT_DIR}/deps.txt" ]] || die "missing ${ROOT_DIR}/deps.txt"
read -r pkg ver repo sha < <(awk '$1=="own" && $2=="kyr-build" {print $2, $3, $4, $5}' "${ROOT_DIR}/deps.txt") || true
[[ -n "${ver:-}" ]] || die "deps.txt pins no kyr-build (own kyr-build <ver> <owner/repo> <sha256>)"
[[ "${sha:-}" =~ ^[0-9a-f]{64}$ ]] || die "the kyr-build pin carries no sha256"
if [[ ! -f "${KYR_BUILD_DIR}/VERSION" || "$(tr -d '[:space:]' < "${KYR_BUILD_DIR}/VERSION")" != "${ver}" ]]; then
    deb="${CACHE_DIR}/${pkg}_${ver}_all.deb"
    mkdir -p "${CACHE_DIR}"
    if [[ ! -s "${deb}" ]]; then
        if command -v gh >/dev/null 2>&1 && { [[ -n "${GH_TOKEN:-}" ]] || gh auth status >/dev/null 2>&1; }; then
            gh release download "v${ver}" --repo "${repo}" --pattern "${pkg}_${ver}_all.deb" --dir "${CACHE_DIR}" --clobber
        else
            curl -fsSL --retry 3 -o "${deb}.part" "https://github.com/${repo}/releases/download/v${ver}/${pkg}_${ver}_all.deb" \
                && mv -f "${deb}.part" "${deb}"
        fi
        [[ -s "${deb}" ]] || die "${pkg} ${ver}: download from ${repo} failed"
    fi
    have="$(sha256sum "${deb}" | awk '{print $1}')"
    [[ "${have}" == "${sha}" ]] || { rm -f "${deb}"; die "${pkg} ${ver}: sha256 ${have} != pinned ${sha} (file removed from cache)"; }
    tmp="$(mktemp -d)"
    dpkg-deb -x "${deb}" "${tmp}"
    rm -rf "${KYR_BUILD_DIR}"
    mkdir -p "$(dirname "${KYR_BUILD_DIR}")"
    cp -a "${tmp}/usr/local/share/kyr-build" "${KYR_BUILD_DIR}"
    rm -rf "${tmp}"
fi
export ROOT_DIR
exec "${KYR_BUILD_DIR}/deps.sh" "$@"
