#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:?missing branch}"
OUTPUT_FILE="${2:?missing output file}"

manifest_url="https://raw.githubusercontent.com/LineageOS/android/${BRANCH}/default.xml"
if ! curl -LSs "$manifest_url" -o manifest.xml; then
  echo "Failed to download manifest from ${manifest_url}" >&2
  echo "clang_repo_revision=" >> "$OUTPUT_FILE"
  exit 0
fi

if clang_rev="$(python3 -c "import xml.etree.ElementTree as ET,sys; root=ET.parse('manifest.xml').getroot(); target_path='prebuilts/clang/host/linux-x86'; target_name='LineageOS/android_prebuilts_clang_host_linux-x86'; proj=next((p for p in root.findall('project') if p.get('path')==target_path or p.get('name')==target_name), None); rev=proj.get('revision') if proj is not None else None; sys.exit(1) if not rev else None; print(rev)")"; then
  echo "clang_repo_revision=${clang_rev}" >> "$OUTPUT_FILE"
  echo "Detected clang repo revision: ${clang_rev}"
else
  echo "Failed to parse clang revision from manifest." >&2
  echo "clang_repo_revision=" >> "$OUTPUT_FILE"
fi
