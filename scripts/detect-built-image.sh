#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="${1:?missing kernel dir}"
OUTPUT_FILE="${2:?missing output file}"

candidates=(
  "out/arch/arm64/boot/Image.gz-dtb"
  "out/arch/arm64/boot/Image.gz"
  "out/arch/arm64/boot/Image.lz4-dtb"
  "out/arch/arm64/boot/Image.lz4"
  "out/arch/arm64/boot/Image"
)
image_relpath=""
for rel in "${candidates[@]}"; do
  if [[ -f "${KERNEL_DIR}/${rel}" ]]; then
    image_relpath="$rel"
    break
  fi
done
if [[ -z "$image_relpath" ]]; then
  echo "No kernel image found in ${KERNEL_DIR}/out/arch/arm64/boot" >&2
  ls -la "${KERNEL_DIR}/out/arch/arm64/boot" || true
  exit 1
fi
echo "Selected image: ${image_relpath}"
echo "image_relpath=${image_relpath}" >> "$OUTPUT_FILE"
