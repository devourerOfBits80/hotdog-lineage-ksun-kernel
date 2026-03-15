#!/usr/bin/env bash
# Apply SUSFS change to fs/proc/task_mmu.c when the first hunk of the upstream
# patch fails (LineageOS kernel has different include layout at top of file).
set -euo pipefail

TASK_MMU="${1:?missing path to fs/proc/task_mmu.c}"

if [[ ! -f "$TASK_MMU" ]]; then
  echo "File not found: $TASK_MMU"
  exit 1
fi

block='
#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
#include <linux/susfs.h>
#endif
'

count=0
while IFS= read -r line; do
  echo "$line"
  if [[ "$line" =~ ^#include[[:space:]]*\<linux/ ]]; then
    count=$(( count + 1 ))
    if [[ "$count" -eq 3 ]]; then
      printf '%s\n' "$block"
    fi
  fi
done < "$TASK_MMU" > "${TASK_MMU}.tmp"
mv "${TASK_MMU}.tmp" "$TASK_MMU"
echo "Inserted SUSFS include block after 3rd linux/ include in task_mmu.c"
