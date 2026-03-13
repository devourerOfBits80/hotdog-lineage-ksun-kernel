#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="${1:?missing kernel dir}"
DEFCONFIG="${2:?missing defconfig}"

cd "$KERNEL_DIR"

for dtsi in \
  "arch/arm64/boot/dts/18821/pm8150.dtsi" \
  "arch/arm64/boot/dts/18857/pm8150.dtsi"; do
  if [[ -f "$dtsi" ]]; then
    sed -i -E 's/\<SPMI_USID\([^)]*\)\>/0x0/g; s/\<SPMI_USID\>/0x0/g' "$dtsi"
    sed -i -E 's|&spmi_bus[[:space:]]*\{|\&{/soc/qcom,spmi@c440000} {|' "$dtsi"
    if grep -q "SPMI_USID" "$dtsi"; then
      echo "Error: SPMI_USID still present in $dtsi before build."
      grep -n "SPMI_USID" "$dtsi" || true
      exit 1
    fi
    if grep -q "&spmi_bus" "$dtsi"; then
      echo "Error: &spmi_bus still present in $dtsi before build."
      grep -n "&spmi_bus" "$dtsi" || true
      exit 1
    fi
  fi
done

export PATH="${GITHUB_WORKSPACE}/clang/bin:${GITHUB_WORKSPACE}/toolchains/aarch64/bin:${GITHUB_WORKSPACE}/toolchains/arm32/bin:$PATH"
export KBUILD_BUILD_USER=github-actions
export KBUILD_BUILD_HOST=github
export CC=clang
export LLVM=1
export LLVM_IAS=1
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-
export CCACHE_DIR="${GITHUB_WORKSPACE}/.ccache"
export CCACHE_COMPRESS=1
export CC="ccache clang"
export DTC_EXT="$(command -v dtc)"
export DTC_CPP_FLAGS="-DSPMI_USID=0x0"
export DTC_FLAGS="-@"

echo "DTC_EXT=${DTC_EXT}"
echo "DTC_FLAGS=${DTC_FLAGS}"
if ! grep -q "DTC_FLAGS += -@" scripts/Makefile.lib; then
  echo "Forcing dtc overlay support in scripts/Makefile.lib"
  sed -i '/^DTC_FLAGS += -q/a DTC_FLAGS += -@' scripts/Makefile.lib
fi
if ! grep -q "dtc_cpp_flags.*DTC_CPP_FLAGS" scripts/Makefile.lib; then
  echo "Wiring DTC_CPP_FLAGS into dtc_cpp_flags"
  sed -i -E 's/(-undef -D__DTS__)/\1 $(DTC_CPP_FLAGS)/' scripts/Makefile.lib
fi

mkdir -p out
make O=out ARCH=arm64 "$DEFCONFIG" \
  DTC_FLAGS="-@" \
  DTC_CPP_FLAGS="-DSPMI_USID=0x0" \
  2>&1

if [[ -f "scripts/kconfig/merge_config.sh" && -f "arch/arm64/configs/vendor/oplus.config" ]]; then
  echo "Merging oplus config fragment into defconfig"
  scripts/kconfig/merge_config.sh -m -O out out/.config arch/arm64/configs/vendor/oplus.config \
    2>&1
fi

echo "Configuring module compatibility (MODVERSIONS, disable LOCALVERSION_AUTO)"
sed -i '/CONFIG_MODVERSIONS/d; /CONFIG_MODULE_SIG_FORCE/d; /CONFIG_MODULE_FORCE_LOAD/d; /CONFIG_LOCALVERSION_AUTO/d' out/.config
{
  echo "CONFIG_MODVERSIONS=y"
  echo "# CONFIG_MODULE_FORCE_LOAD is not set"
  echo "# CONFIG_MODULE_SIG_FORCE is not set"
  echo "# CONFIG_LOCALVERSION_AUTO is not set"
} >> out/.config

if [[ -d "drivers/kernelsu" || -d "KernelSU-Next" ]]; then
  echo "Enabling KernelSU-Next config options"
  sed -i '/CONFIG_KPROBES/d; /CONFIG_KPROBE_EVENTS/d; /CONFIG_KSU/d' out/.config
  {
    echo "CONFIG_KPROBES=y"
    echo "CONFIG_KPROBE_EVENTS=y"
    echo "CONFIG_KSU=y"
  } >> out/.config
fi
make O=out ARCH=arm64 olddefconfig 2>&1

echo "=== Kernel config status ==="
grep -E "CONFIG_MODVERSIONS|CONFIG_MODULE_SIG" out/.config | head -5 || true
grep -E "CONFIG_KSU|CONFIG_KPROBES|CONFIG_KRETPROBES" out/.config || true
if grep -q "CONFIG_KSU=y" out/.config; then
  echo "CONFIG_KSU=y is set - KernelSU-Next will be built into kernel"
  if grep -q "CONFIG_KPROBES=y" out/.config; then
    echo "CONFIG_KPROBES=y - using kprobe hooks"
  else
    echo "Warning: CONFIG_KPROBES not enabled - manual hooks may be required"
  fi
else
  echo "ERROR: CONFIG_KSU is not enabled - KernelSU-Next will NOT work"
  exit 1
fi
echo "==================================="

make -j"$(nproc)" O=out ARCH=arm64 \
  CC="ccache clang" LLVM=1 LLVM_IAS=1 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-androideabi- \
  DTC_FLAGS="-@" \
  DTC_CPP_FLAGS="-DSPMI_USID=0x0" \
  2>&1
