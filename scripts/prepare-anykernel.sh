#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_PATH:?missing IMAGE_PATH}"
: "${RELEASE_LABEL:?missing RELEASE_LABEL}"

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

if [[ -f AnyKernel3/README.md ]]; then
  printf '\nBuilt by workflow: %s\n' "$RELEASE_LABEL" >> AnyKernel3/README.md
fi

# Copy WLAN module if it was built
WLAN_MODULE="kernel/out/modules/qca_cld3_wlan.ko"
if [[ -f "$WLAN_MODULE" ]]; then
  echo "Copying WLAN module to AnyKernel3"
  mkdir -p AnyKernel3/modules/vendor_dlkm/lib/modules
  cp -f "$WLAN_MODULE" AnyKernel3/modules/vendor_dlkm/lib/modules/
fi
