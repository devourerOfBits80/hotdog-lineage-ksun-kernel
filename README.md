# hotdog-lineage-ksun-kernel

Weekly AnyKernel3 build for **OnePlus 7T Pro (`hotdog`)** using the matching **LineageOS kernel branch**, with **KernelSU-Next** integrated automatically.

## What it does

- runs every **Friday at 12:00 UTC**, or manually via `workflow_dispatch`
- detects the newest common `lineage-*` branch shared by:
  - `LineageOS/android_device_oneplus_hotdog`
  - `LineageOS/android_kernel_oneplus_sm8150`
- resolves upstream SHAs for that branch and **skips build only if a release for the current state already exists** (same branch + device SHA + kernel SHA + KernelSU-Next tag)
- extracts build metadata from the kernel tree (`build.config`, `defconfig`, clang revision, image name)
- downloads matching AOSP clang/GCC prebuilts
- integrates KernelSU-Next and records its version + SHA in release notes
- builds the legacy make-based kernel (merging `vendor/oplus.config`) and packages an **AnyKernel3 ZIP**
- includes WLAN module as **systemless ak3-helper** for KernelSU (automatic overlay)
- uploads artifacts (ZIP + raw kernel image) and creates a **GitHub Release**

## Release policy

A release is created only when the release tag would be new — i.e. the upstream state changed in at least one of:

- `android_device_oneplus_hotdog`
- `android_kernel_oneplus_sm8150`
- **KernelSU-Next** (new tag in the repo)

Tag format:

`lineage-XX.Y-<device_sha12>-<kernel_sha12>-<ksun_tag>`

## Release naming

- title: `OnePlus 7T Pro AnyKernel3 | lineage-XX.Y | YYYY-MM-DD`
- asset: `AnyKernel3-hotdog-lineage-XX.Y-YYYY-MM-DD.zip`

## Layout

- `.github/workflows/build-weekly.yml` — CI workflow
- `scripts/detect-lineage-branch.sh` — branch detection + upstream SHA resolution
- `scripts/detect-clang-version.sh` — clang revision from LineageOS manifest
- `scripts/detect-ksun-version.sh` — KernelSU-Next version detection
- `scripts/extract-build-metadata.sh` — build inputs + toolchain metadata
- `scripts/workaround-spmi-usid.sh` — DTS SPMI_USID patching
- `scripts/build-kernel.sh` — legacy kernel build + oplus config merge
- `scripts/detect-built-image.sh` — built image selection
- `scripts/retry-helper.sh` — retry wrapper used by workflow
- `scripts/setup-lineage-toolchain.sh` — AOSP clang/GCC prebuilts
- `scripts/prepare-anykernel.sh` — AnyKernel3 staging (dynamic image name)
- `anykernel/anykernel.sh` — AnyKernel3 installer for **hotdog** (OnePlus 7T Pro)

## Installation

1. **Flash AnyKernel3 ZIP** via recovery (installs kernel + WLAN module)
2. **Reboot** — WiFi should work automatically

The ZIP uses AnyKernel3's **systemless module** feature (`do.systemless=1`) to create an `ak3-helper` KernelSU module that overlays the compatible WLAN driver without modifying read-only vendor partitions.

## Notes

- This repo intentionally ships **AnyKernel3 ZIPs**, not raw `boot.img`.
- WLAN module is included as a systemless overlay.
- If the kernel tree migrates to **Kleaf/Bazel**, the workflow exits with a clear error.
