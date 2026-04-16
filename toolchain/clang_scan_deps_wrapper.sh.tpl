#!/bin/bash
# Wrapper for clang-scan-deps that translates Bazel's cpp-module-deps-scanner
# calling convention into clang-scan-deps's P1689 format interface.
#
# Bazel 9 calls the deps scanner with compiler-like flags directly:
#   <scanner> [compiler-flags] -c source.cpp -o output.ddi
#
# But LLVM 14+'s clang-scan-deps expects its own flags only, followed by
# compiler args separated by "--":
#   clang-scan-deps -format=p1689 -o output.ddi -- clang [flags] -c source.cpp
#
# This wrapper bridges the gap by parsing Bazel's args, extracting -o
# (the .ddi output path), and forwarding everything else to clang via
# clang-scan-deps's "--" separator.
#
# %{toolchain_path_prefix} is substituted at toolchain-configuration time by
# configure.bzl, so these paths are fixed for the lifetime of the toolchain
# repo. Bazel runs actions from the execroot, so relative paths are valid.

# shellcheck disable=SC1083

set -euo pipefail

CLANG_SCAN_DEPS="%{toolchain_path_prefix}bin/clang-scan-deps"
CLANG="%{toolchain_path_prefix}bin/clang"

# Parse args from Bazel.
# Bazel 9 passes compiler-like flags where -o points to the .ddi output file.
# We extract -o <output> to pass to clang-scan-deps; all remaining args are
# forwarded to clang after the "--" separator.
output_file=""
clang_args=()
i=1
while [[ $i -le $# ]]; do
  arg="${!i}"
  if [[ "${arg}" == "-o" ]]; then
    i=$((i + 1))
    output_file="${!i}"
  else
    clang_args+=("${arg}")
  fi
  i=$((i + 1))
done

# Fall back to env var set by Bazel 9 for some scanner invocations.
if [[ -z "${output_file}" ]]; then
  output_file="${DEPS_SCANNER_OUTPUT_FILE:-}"
fi

if [[ -z "${output_file}" ]]; then
  echo >&2 "ERROR: clang_scan_deps_wrapper: no output file specified (no -o flag and DEPS_SCANNER_OUTPUT_FILE not set)"
  exit 1
fi

exec "${CLANG_SCAN_DEPS}" -format=p1689 -o "${output_file}" -- "${CLANG}" "${clang_args[@]}"
