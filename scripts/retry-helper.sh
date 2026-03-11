#!/usr/bin/env bash
set -euo pipefail

get_git_clone_target() {
  local -a args=("$@")
  local -a positional=()
  local skip_next=0
  local arg=""
  local i=2
  while (( i < ${#args[@]} )); do
    arg="${args[i]}"
    if (( skip_next )); then
      skip_next=0
      ((i++))
      continue
    fi
    if [[ "$arg" == "--" ]]; then
      ((i++))
      break
    fi
    if [[ "$arg" == --* ]]; then
      if [[ "$arg" == *=* ]]; then
        ((i++))
        continue
      fi
      case "$arg" in
        --branch|--depth|--filter|--shallow-since|--shallow-exclude|--reference|--reference-if-able|--template|--config|--origin|--upload-pack|--separate-git-dir|--server-option|--jobs)
          skip_next=1
          ;;
      esac
      ((i++))
      continue
    fi
    if [[ "$arg" == -* ]]; then
      case "$arg" in
        -b|-c|-o|-j)
          skip_next=1
          ;;
      esac
      ((i++))
      continue
    fi
    positional+=("$arg")
    ((i++))
  done
  while (( i < ${#args[@]} )); do
    positional+=("${args[i]}")
    ((i++))
  done
  if (( ${#positional[@]} >= 2 )); then
    printf '%s' "${positional[-1]}"
  fi
}

cleanup_git_clone_target() {
  local target=""
  target="$(get_git_clone_target "$@")"
  if [[ -z "$target" ]]; then
    return 0
  fi
  if [[ "$target" == "/" || "$target" == "." || "$target" == ".." ]]; then
    return 0
  fi
  if [[ -d "$target" ]]; then
    rm -rf "$target"
  fi
}

retry() {
  local attempts=0
  local max_attempts=3
  local delay=5
  until "$@"; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge $max_attempts ]]; then
      echo "Command failed after ${attempts} attempts: $*" >&2
      return 1
    fi
    if [[ "${1-}" == "git" && "${2-}" == "clone" ]]; then
      cleanup_git_clone_target "$@"
    fi
    echo "Retrying in ${delay}s: $*"
    sleep "$delay"
    delay=$((delay * 2))
  done
}

retry "$@"
