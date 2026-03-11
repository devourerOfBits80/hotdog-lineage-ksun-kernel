#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="${1:?missing kernel dir}"
OUTPUT_FILE="${2:?missing output file}"

ksu_version=""

if [[ -d "${KERNEL_DIR}/KernelSU-Next/.git" ]]; then
  ksu_version="$(git -C "${KERNEL_DIR}/KernelSU-Next" describe --tags --always 2>/dev/null || true)"
fi
for candidate in \
  "${KERNEL_DIR}/include/linux/ksu_version.h" \
  "${KERNEL_DIR}/drivers/kernelsu/ksu_version.h" \
  "${KERNEL_DIR}/kernel/kernelsu/ksu_version.h" \
  "${KERNEL_DIR}/KernelSU/ksu_version.h" \
  "${KERNEL_DIR}/drivers/kernelsu/ksu_version.c" \
  "${KERNEL_DIR}/KernelSU/ksu_version.c"; do
  if [[ -f "$candidate" ]]; then
    ksu_version="$(grep -Eo 'KSU_VERSION[^"]*"[^"]+"' "$candidate" | sed -n '1p' | sed -E 's/.*"([^"]+)".*/\1/' || true)"
    if [[ -n "$ksu_version" ]]; then
      break
    fi
  fi
done

if [[ -z "$ksu_version" ]]; then
  ksu_version="$(
    grep -RhoE 'KSU_VERSION[^"]*"[^"]+"' \
      "${KERNEL_DIR}/include/linux" \
      "${KERNEL_DIR}/drivers/kernelsu" \
      "${KERNEL_DIR}/kernel/kernelsu" \
      "${KERNEL_DIR}/KernelSU" 2>/dev/null | \
      sed -n '1p' | sed -E 's/.*"([^"]+)".*/\1/' || true
  )"
fi

if [[ -z "$ksu_version" ]]; then
  ksu_version="unknown"
fi

echo "version=${ksu_version}" >> "$OUTPUT_FILE"
echo "KernelSU-Next version: ${ksu_version}"
