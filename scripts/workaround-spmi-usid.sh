#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="${1:?missing kernel dir}"

dts_root="${KERNEL_DIR}/arch/arm64/boot/dts"
if [[ -d "$dts_root" ]]; then
  matches="$(grep -RIl "SPMI_USID" "$dts_root" || true)"
  if [[ -n "$matches" ]]; then
    echo "Replacing SPMI_USID in:"
    echo "$matches"
    while read -r path; do
      [[ -n "$path" ]] || continue
      sed -i -E 's/\<SPMI_USID\([^)]*\)\>/0x0/g; s/\<SPMI_USID\>/0x0/g' "$path"
    done <<< "$matches"
    echo "Remaining SPMI_USID references (post-patch):"
    grep -RIn "SPMI_USID" "$dts_root" || true
  else
    echo "No SPMI_USID references found in $dts_root"
  fi
fi
