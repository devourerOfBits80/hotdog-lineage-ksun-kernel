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
- integrates **KernelSU-Next** (legacy_susfs branch) and **SUSFS** kernel patches (4.14)
- builds the legacy make-based kernel (merging `vendor/oplus.config`) and packages an **AnyKernel3 ZIP**
- builds a separate **KernelSU WLAN module** ZIP for WiFi support

## Release policy

A release is created only when the release tag would be new — i.e. the upstream state changed in at least one of:

- `android_device_oneplus_hotdog`
- `android_kernel_oneplus_sm8150`
- **KernelSU-Next** (new tag in the repo)

Tag format:

`lineage-XX.Y-<device_sha12>-<kernel_sha12>-<ksun_tag>-susfs`

## Release naming

- title: `OnePlus 7T Pro AnyKernel3 | lineage-XX.Y | YYYY-MM-DD`
- assets:
  - `AnyKernel3-hotdog-lineage-XX.Y-YYYY-MM-DD.zip` (kernel)
  - `WLAN-Module-lineage-XX.Y-YYYY-MM-DD.zip` (WiFi module)

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

1. **Flash AnyKernel3 ZIP** via recovery
2. **Reboot** — KernelSU-Next will be active (WiFi not yet working)
3. **Install WLAN module** via KernelSU Manager or:
   ```bash
   adb push WLAN-Module-*.zip /sdcard/
   adb shell su -c "ksud module install /sdcard/WLAN-Module-*.zip"
   ```
4. **Reboot** — WiFi should work

The WLAN module uses `insmod` to load the kernel-compatible driver at boot.

**SUSFS (root hiding):** The kernel includes SUSFS support. Install the [susfs4ksu module](https://github.com/sidex15/susfs4ksu-module/releases) via KernelSU Manager for root-hiding features.

## Notes

- This repo ships **AnyKernel3 ZIPs**, not raw `boot.img`.
- Kernel includes **KernelSU-Next** (legacy_susfs) and **SUSFS**; optional susfs4ksu module for root hiding (see Installation).
- A separate **WLAN module ZIP** is required for WiFi (loaded via `insmod` at boot).
- If the kernel tree migrates to **Kleaf/Bazel**, the workflow exits with a clear error.
