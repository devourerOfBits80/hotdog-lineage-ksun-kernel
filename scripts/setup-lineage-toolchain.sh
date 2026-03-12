#!/usr/bin/env bash
set -euo pipefail

MODE="${1:?missing mode}"
IDENT="${2:?missing identifier}"
DEST="${3:?missing destination}"

export GIT_TERMINAL_PROMPT=0

AOSP_CLANG_REPO="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86"
AOSP_GCC_AARCH64_REPO="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9"
AOSP_GCC_ARM_REPO="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9"

if [[ -n "$(ls -A "$DEST" 2>/dev/null || true)" ]]; then
  echo "Toolchain destination is not empty: $DEST" >&2
  exit 1
fi
mkdir -p "$DEST"

try_clone_url() {
  local url="$1"
  local target="$2"
  local attempts=0
  local max_attempts=3
  local delay=3
  local tmpdir=""
  local clone_dir=""
  while true; do
    attempts=$((attempts + 1))
    tmpdir="$(mktemp -d)"
    clone_dir="${tmpdir}/repo"
    if git clone --depth=1 "$url" "$clone_dir"; then
      rm -rf "$target"
      mv "$clone_dir" "$target"
      rm -rf "$tmpdir"
      return 0
    fi
    rm -rf "$tmpdir"
    if [[ $attempts -ge $max_attempts ]]; then
      return 1
    fi
    echo "Retrying clone in ${delay}s: ${url}"
    sleep "$delay"
    delay=$((delay * 2))
  done
}

try_git_fetch() {
  local repo_dir="$1"
  local ref="$2"
  local attempts=0
  local max_attempts=3
  local delay=3
  while true; do
    attempts=$((attempts + 1))
    if git -C "$repo_dir" fetch --depth=1 origin "$ref"; then
      return 0
    fi
    if [[ $attempts -ge $max_attempts ]]; then
      return 1
    fi
    echo "Retrying fetch in ${delay}s: ${ref}"
    sleep "$delay"
    delay=$((delay * 2))
  done
}

clone_clang_from_repo() {
  local repo_url="$1"
  local repo_label="$2"
  local ident="$3"
  local target="$4"
  local repo_revision="${5:-}"
  local tmpdir=""
  local match_dir=""
  local search_root=""
  local candidate=""
  local base_name=""
  local -a search_roots=()
  local -a candidates=()
  local -a prefix_matches=()
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  echo "Cloning ${repo_label} clang prebuilts to extract ${ident}"
  if ! try_clone_url "$repo_url" "$tmpdir"; then
    return 1
  fi
  if [[ -n "$repo_revision" ]]; then
    echo "Checking out ${repo_label} clang repo revision: ${repo_revision}"
    if ! try_git_fetch "$tmpdir" "$repo_revision" || \
      ! git -C "$tmpdir" checkout --detach FETCH_HEAD; then
      echo "Warning: unable to checkout ${repo_label} revision ${repo_revision}; using repo HEAD" >&2
    fi
  fi
  search_roots=("$tmpdir" "$tmpdir/prebuilts/clang/host/linux-x86")
  for search_root in "${search_roots[@]}"; do
    if [[ ! -d "$search_root" ]]; then
      continue
    fi
    while IFS= read -r candidate; do
      if [[ -d "$candidate/bin" ]]; then
        candidates+=("$candidate")
      fi
    done < <(find "$search_root" -mindepth 1 -maxdepth 2 -type d -name 'clang-r*' 2>/dev/null || true)
  done

  for candidate in "${candidates[@]}"; do
    base_name="$(basename "$candidate")"
    if [[ "$base_name" == "$ident" ]]; then
      match_dir="$candidate"
      break
    fi
  done

  if [[ -z "$match_dir" ]]; then
    for candidate in "${candidates[@]}"; do
      base_name="$(basename "$candidate")"
      if [[ "$base_name" == "$ident"* ]]; then
        prefix_matches+=("$candidate")
      fi
    done
    if [[ ${#prefix_matches[@]} -gt 0 ]]; then
      match_dir="$(
        for candidate in "${prefix_matches[@]}"; do
          printf '%s\t%s\n' "$(basename "$candidate")" "$candidate"
        done | sort -V | tail -n1 | cut -f2-
      )"
    fi
  fi

  if [[ -z "$match_dir" && ${#candidates[@]} -gt 0 ]]; then
    match_dir="$(
      for candidate in "${candidates[@]}"; do
        printf '%s\t%s\n' "$(basename "$candidate")" "$candidate"
      done | sort -V | tail -n1 | cut -f2-
    )"
    echo "Falling back to latest available ${repo_label} clang revision: $(basename "$match_dir")"
  fi

  if [[ -n "$match_dir" && -d "$match_dir/bin" ]]; then
    if [[ "$(basename "$match_dir")" != "$ident" ]]; then
      echo "Using ${repo_label} clang revision: $(basename "$match_dir")"
    fi
    if command -v rsync >/dev/null 2>&1; then
      rsync -a \
        --exclude='*riscv*' \
        --exclude='*lsan*' \
        --exclude='*tsan*' \
        --exclude='*msan*' \
        --exclude='*asan*' \
        --exclude='*ubsan*' \
        --exclude='*fuzzer*' \
        --exclude='*profile*' \
        "$match_dir/" "$target/"
    else
      cp -a "$match_dir/." "$target/"
    fi
    return 0
  fi
  return 1
}

normalize_gcc_prefixes() {
  local target="$1"
  local target_bin="$target/bin"
  if [[ -d "$target_bin" ]]; then
    if compgen -G "$target_bin/aarch64-linux-android-*" >/dev/null 2>&1; then
      for tool in "$target_bin"/aarch64-linux-android-*; do
        ln -sf "$(basename "$tool")" "$target_bin/${tool##*/aarch64-linux-android-}" >/dev/null 2>&1 || true
        ln -sf "$(basename "$tool")" "$target_bin/aarch64-linux-gnu-${tool##*/aarch64-linux-android-}" >/dev/null 2>&1 || true
      done
    fi
    if compgen -G "$target_bin/arm-linux-androideabi-*" >/dev/null 2>&1; then
      for tool in "$target_bin"/arm-linux-androideabi-*; do
        ln -sf "$(basename "$tool")" "$target_bin/arm-linux-gnueabi-${tool##*/arm-linux-androideabi-}" >/dev/null 2>&1 || true
      done
    fi
  fi
}

if [[ "$MODE" == "clang" ]]; then
  if clone_clang_from_repo "$AOSP_CLANG_REPO" "AOSP" "$IDENT" "$DEST" "${CLANG_REPO_REVISION:-}"; then
    exit 0
  fi
  echo "Unable to locate AOSP clang prebuilts for ${IDENT}" >&2
  exit 1
fi

if [[ "$MODE" == "gcc" ]]; then
  case "$IDENT" in
    aarch64-linux-gnu-)
      ;;
    arm-linux-androideabi-|arm-linux-gnueabi-)
      ;;
    *)
      echo "Unsupported gcc toolchain identifier: ${IDENT}" >&2
      exit 1
      ;;
  esac

  if [[ "$IDENT" == "aarch64-linux-gnu-" ]]; then
    echo "Falling back to AOSP GCC aarch64 prebuilts"
    if try_clone_url "$AOSP_GCC_AARCH64_REPO" "$DEST"; then
      normalize_gcc_prefixes "$DEST"
      exit 0
    fi
  fi
  if [[ "$IDENT" == "arm-linux-androideabi-" || "$IDENT" == "arm-linux-gnueabi-" ]]; then
    echo "Falling back to AOSP GCC arm prebuilts"
    if try_clone_url "$AOSP_GCC_ARM_REPO" "$DEST"; then
      normalize_gcc_prefixes "$DEST"
      exit 0
    fi
  fi

  echo "Unable to locate AOSP GCC prebuilts for ${IDENT}" >&2
  exit 1
fi

echo "Unsupported setup mode: ${MODE}" >&2
exit 1
