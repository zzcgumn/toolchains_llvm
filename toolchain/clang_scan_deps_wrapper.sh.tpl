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

# shellcheck disable=SC1083

set -euo pipefail

# Path resolution (same pattern as cc_wrapper.sh).
# This script lives at <execroot>/external/<repo_name>/bin/clang_scan_deps_wrapper.sh
# The toolchain binaries live at %{toolchain_path_prefix}bin/.

dirname_shim() {
  local path="$1"

  # Remove trailing slashes
  path="${path%/}"

  # If there's no slash, return "."
  if [[ "${path}" != */* ]]; then
    echo "."
    return
  fi

  # Remove the last component after the final slash
  path="${path%/*}"

  # If it becomes empty, it means root "/"
  echo "${path:-/}"
}

if [[ "${BASH_SOURCE[0]}" == "/"* ]]; then
  bash_source_abs="$(realpath "${BASH_SOURCE[0]}")"
  pwd_abs="$(realpath ".")"
  bash_source_rel=${bash_source_abs#"${pwd_abs}/"}
else
  bash_source_rel="${BASH_SOURCE[0]}"
fi
script_dir=$(dirname_shim "${bash_source_rel}")
toolchain_path_prefix="%{toolchain_path_prefix}"
# Sometimes this path may be an absolute path in which case we don't modify it.
if [[ ${toolchain_path_prefix} != /* ]]; then
  # shellcheck disable=SC2312
  toolchain_path_prefix="$(dirname_shim "$(dirname_shim "${script_dir}")")/${toolchain_path_prefix#external/}"
fi

CLANG_SCAN_DEPS="${toolchain_path_prefix}bin/clang-scan-deps"
CLANG="${toolchain_path_prefix}bin/clang"

if [[ ! -f "${CLANG_SCAN_DEPS}" ]]; then
  echo >&2 "ERROR: clang_scan_deps_wrapper: could not find clang-scan-deps; toolchain_path_prefix=${toolchain_path_prefix}"
  exit 5
fi

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
