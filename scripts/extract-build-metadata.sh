#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="${1:?missing kernel dir}"
DEFAULT_BUILD_CONFIG="${2:-build.config.aarch64}"
DEFAULT_DEFCONFIG="${3:-vendor/sm8150-perf_defconfig}"

BUILD_CONFIG=""
if [[ -f "$KERNEL_DIR/$DEFAULT_BUILD_CONFIG" ]]; then
  BUILD_CONFIG="$DEFAULT_BUILD_CONFIG"
else
  mapfile -t BUILD_CONFIGS < <(find "$KERNEL_DIR" -maxdepth 2 -type f -name 'build.config*' | sed "s#^$KERNEL_DIR/##" | sort)
  if [[ ${#BUILD_CONFIGS[@]} -gt 0 ]]; then
    BUILD_CONFIG="$(printf '%s\n' "${BUILD_CONFIGS[@]}" | grep -E 'hotdog' | head -n1 || true)"
    if [[ -z "$BUILD_CONFIG" ]]; then
      BUILD_CONFIG="$(printf '%s\n' "${BUILD_CONFIGS[@]}" | grep -E 'sm8150' | head -n1 || true)"
    fi
    if [[ -z "$BUILD_CONFIG" ]]; then
      BUILD_CONFIG="$(printf '%s\n' "${BUILD_CONFIGS[@]}" | grep -E 'sdm8150' | head -n1 || true)"
    fi
    if [[ -z "$BUILD_CONFIG" ]]; then
      BUILD_CONFIG="$(printf '%s\n' "${BUILD_CONFIGS[@]}" | grep -E 'kona' | head -n1 || true)"
    fi
    if [[ -z "$BUILD_CONFIG" ]]; then
      BUILD_CONFIG="${BUILD_CONFIGS[0]}"
    fi
  fi
fi
if [[ -n "$BUILD_CONFIG" && ! -f "$KERNEL_DIR/$BUILD_CONFIG" ]]; then
  echo "Resolved build.config path does not exist: $KERNEL_DIR/$BUILD_CONFIG" >&2
  exit 1
fi

BUILD_MODE="legacy"
if [[ -f "$KERNEL_DIR/MODULE.bazel" || -d "$KERNEL_DIR/build/kernel/kleaf" || -d "$KERNEL_DIR/kleaf" ]]; then
  BUILD_MODE="kleaf"
fi

CLANG_PATH=""
if [[ -n "$BUILD_CONFIG" ]]; then
  CLANG_PATH="$(grep -E '^CLANG_PREBUILT_BIN=' "$KERNEL_DIR/$BUILD_CONFIG" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '"'\''' || true)"
fi
if [[ -z "$CLANG_PATH" ]]; then
  CLANG_PATH="$(grep -RhoE 'CLANG_PREBUILT_BIN=[^ ]+' "$KERNEL_DIR"/build.config* 2>/dev/null | head -n1 | cut -d= -f2- || true)"
fi
CLANG_REVISION=""
if [[ -n "$CLANG_PATH" ]]; then
  CLANG_REVISION="$(basename "$(dirname "$CLANG_PATH")")"
fi
if [[ -z "$CLANG_REVISION" ]]; then
  CLANG_REVISION="clang-r416183b"
  echo "Warning: CLANG_PREBUILT_BIN not found; using fallback ${CLANG_REVISION}" >&2
fi

DEFCONFIG=""
if [[ -n "$BUILD_CONFIG" ]]; then
  DEFCONFIG="$(grep -E '^(KERNEL_DEFCONFIG|DEFCONFIG)=' "$KERNEL_DIR/$BUILD_CONFIG" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '"'\''' || true)"
fi
mapfile -t DEFCONFIGS < <(find "$KERNEL_DIR/arch/arm64/configs" -type f | sed "s#^$KERNEL_DIR/arch/arm64/configs/##" | sort)
if [[ ${#DEFCONFIGS[@]} -eq 0 ]]; then
  echo "Could not determine defconfig under arch/arm64/configs" >&2
  exit 1
fi
if [[ -n "$DEFCONFIG" && ! -f "$KERNEL_DIR/arch/arm64/configs/$DEFCONFIG" ]]; then
  DEFCONFIG=""
fi
if [[ -z "$DEFCONFIG" ]]; then
  DEFCONFIG="$(printf '%s\n' "${DEFCONFIGS[@]}" | grep -E '^vendor/.*hotdog.*defconfig' | head -n1 || true)"
fi
if [[ -z "$DEFCONFIG" ]]; then
  DEFCONFIG="$(printf '%s\n' "${DEFCONFIGS[@]}" | grep -E '^vendor/.*guacamole.*defconfig' | head -n1 || true)"
fi
if [[ -z "$DEFCONFIG" ]]; then
  DEFCONFIG="$(printf '%s\n' "${DEFCONFIGS[@]}" | grep -E '^vendor/.*oplus.*defconfig' | head -n1 || true)"
fi
if [[ -z "$DEFCONFIG" && -n "$DEFAULT_DEFCONFIG" ]]; then
  if [[ -f "$KERNEL_DIR/arch/arm64/configs/$DEFAULT_DEFCONFIG" ]]; then
    DEFCONFIG="$DEFAULT_DEFCONFIG"
  fi
fi
if [[ -z "$DEFCONFIG" ]]; then
  DEFCONFIG="$(printf '%s\n' "${DEFCONFIGS[@]}" | grep -E '^vendor/.*sm8150.*perf_defconfig' | head -n1 || true)"
fi
if [[ -z "$DEFCONFIG" ]]; then
  DEFCONFIG="$(printf '%s\n' "${DEFCONFIGS[@]}" | grep -E '^vendor/.*(sdm8150|kona).*perf_defconfig' | head -n1 || true)"
fi
if [[ -z "$DEFCONFIG" ]]; then
  DEFCONFIG="$(printf '%s\n' "${DEFCONFIGS[@]}" | grep -E 'sm8150|sdm8150|kona|hotdog' | head -n1 || true)"
fi
if [[ -z "$DEFCONFIG" ]]; then
  DEFCONFIG="${DEFCONFIGS[0]}"
fi
if [[ -z "$DEFCONFIG" ]]; then
  echo "Could not determine defconfig under arch/arm64/configs" >&2
  exit 1
fi

IMAGE_NAME=""
IMAGE_SOURCE="fallback"
if [[ -n "$BUILD_CONFIG" ]]; then
  IMAGE_NAME="$(grep -E '^IMAGE_NAME=' "$KERNEL_DIR/$BUILD_CONFIG" | head -n1 | cut -d= -f2- | tr -d '"'\''' || true)"
  if [[ -n "$IMAGE_NAME" ]]; then
    IMAGE_SOURCE="IMAGE_NAME"
  fi
fi
if [[ -z "$IMAGE_NAME" ]]; then
  IMAGE_NAME="$(grep -E '^FILES=' "$KERNEL_DIR/$BUILD_CONFIG" 2>/dev/null | head -n1 | grep -oE 'Image(\.gz)?(-dtb)?' | head -n1 || true)"
  if [[ -n "$IMAGE_NAME" ]]; then
    IMAGE_SOURCE="FILES"
  fi
fi
if [[ -z "$IMAGE_NAME" ]]; then
  IMAGE_NAME="Image.gz-dtb"
fi
IMAGE_REL="out/arch/arm64/boot/${IMAGE_NAME}"

{
  echo "build_mode=${BUILD_MODE}"
  if [[ -n "$BUILD_CONFIG" ]]; then
    echo "build_config=${BUILD_CONFIG}"
  else
    echo "build_config=(none)"
  fi
  echo "defconfig=${DEFCONFIG}"
  echo "clang_revision=${CLANG_REVISION}"
  echo "image_relpath=${IMAGE_REL}"
} >> "$GITHUB_OUTPUT"

printf 'Build mode: %s\n' "$BUILD_MODE"
printf 'Build config: %s\n' "$BUILD_CONFIG"
printf 'Defconfig: %s\n' "$DEFCONFIG"
printf 'Clang revision: %s\n' "$CLANG_REVISION"
printf 'Image name source: %s\n' "$IMAGE_SOURCE"
