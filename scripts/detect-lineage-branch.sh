#!/usr/bin/env bash
set -euo pipefail

DEVICE_REPO="${1:?missing device repo}"
KERNEL_REPO="${2:?missing kernel repo}"

list_remote_heads() {
  local repo="$1"
  local output=""
  if ! output="$(git ls-remote --heads "https://github.com/${repo}.git")"; then
    echo "Failed to list remote heads for ${repo}" >&2
    exit 1
  fi
  if [[ -z "$output" ]]; then
    echo "No remote heads found for ${repo}" >&2
    exit 1
  fi
  printf '%s\n' "$output" \
    | awk '{print $2}' \
    | sed 's#refs/heads/##'
}

latest_common_lineage_branch() {
  local regex='^lineage-[0-9]+(\.[0-9]+)?$'
  comm -12 \
    <(list_remote_heads "$DEVICE_REPO" | grep -E "$regex" | sort -V) \
    <(list_remote_heads "$KERNEL_REPO" | grep -E "$regex" | sort -V) \
    | tail -n1
}

resolve_head_sha() {
  local repo="$1"
  local branch="$2"
  local output=""
  if ! output="$(git ls-remote "https://github.com/${repo}.git" "refs/heads/${branch}")"; then
    echo "Failed to resolve HEAD for ${repo} on ${branch}" >&2
    exit 1
  fi
  printf '%s\n' "$output" | awk '{print $1}'
}

BRANCH="$(latest_common_lineage_branch)"
if [[ -z "$BRANCH" ]]; then
  echo "No common lineage-* branch found between ${DEVICE_REPO} and ${KERNEL_REPO}" >&2
  exit 1
fi

DEVICE_SHA="$(resolve_head_sha "$DEVICE_REPO" "$BRANCH")"
KERNEL_SHA="$(resolve_head_sha "$KERNEL_REPO" "$BRANCH")"

if [[ -z "$DEVICE_SHA" || -z "$KERNEL_SHA" ]]; then
  echo "Failed to resolve upstream SHAs for branch ${BRANCH}" >&2
  exit 1
fi

{
  echo "branch=${BRANCH}"
  echo "device_sha=${DEVICE_SHA}"
  echo "kernel_sha=${KERNEL_SHA}"
  echo "device_short=${DEVICE_SHA:0:12}"
  echo "kernel_short=${KERNEL_SHA:0:12}"
} >> "$GITHUB_OUTPUT"

printf 'Detected branch: %s\n' "$BRANCH"
printf 'Device SHA: %s\n' "$DEVICE_SHA"
printf 'Kernel SHA: %s\n' "$KERNEL_SHA"
