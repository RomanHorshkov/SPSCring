#!/usr/bin/env bash
# shellcheck shell=bash
# spscring_project.sh — what the ABI gate (utils/check_abi.sh, kyr-build share/abi) treats as SPSCring's public ABI: the
# one public header app/spscring.h, and the prefixes of its types, functions and numeric constants. The build scripts do not read
# this file; the linker map's node is SPSCRING_<major>.
KYR_LIB="spscring"
KYR_ABI_NAME="SPSCring"
KYR_ABI_INCLUDE_DIR="app"
KYR_ABI_UMBRELLA="spscring.h"
KYR_ABI_TYPE_PREFIX="spsc_ring_"
KYR_ABI_FUNC_PREFIX="spsc_ring_"
KYR_ABI_CONST_PREFIX="SPSC_RING_"
KYR_ABI_NODE="SPSCRING"
