#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_PATH:?missing IMAGE_PATH}"

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "Missing kernel image at $IMAGE_PATH" >&2
  exit 1
fi
if [[ ! -d AnyKernel3 ]]; then
  echo "Missing AnyKernel3 directory in workspace" >&2
  exit 1
fi

echo "Staging AnyKernel3 templates"
cp -f anykernel/anykernel.sh AnyKernel3/anykernel.sh
cp -f anykernel/banner AnyKernel3/banner
IMAGE_NAME="$(basename "$IMAGE_PATH")"
if ! grep -q '__IMAGE_NAME__' AnyKernel3/anykernel.sh; then
  echo "Missing __IMAGE_NAME__ placeholder in AnyKernel3/anykernel.sh" >&2
  exit 1
fi
echo "Copying kernel image: ${IMAGE_NAME}"
cp -f "$IMAGE_PATH" "AnyKernel3/${IMAGE_NAME}"
escaped_image_name="$(printf '%s' "$IMAGE_NAME" | sed -e 's/[\\/&]/\\&/g')"
sed -i "s#__IMAGE_NAME__#${escaped_image_name}#" AnyKernel3/anykernel.sh
