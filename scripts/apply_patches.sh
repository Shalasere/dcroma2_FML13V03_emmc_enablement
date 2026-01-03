#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

apply_series() {
  local name="$1"
  local repo_dir="$2"
  local patch_dir="$3"

  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "Missing repo: $repo_dir" >&2
    exit 1
  fi

  if ! git -C "$repo_dir" diff --quiet || ! git -C "$repo_dir" diff --cached --quiet; then
    echo "Working tree dirty in $repo_dir. Clean before applying patches." >&2
    exit 1
  fi

  shopt -s nullglob
  local patches=("$patch_dir"/*.patch)
  shopt -u nullglob

  if [[ ${#patches[@]} -eq 0 ]]; then
    echo "No patches for $name in $patch_dir"
    return 0
  fi

  echo "Applying ${#patches[@]} patches to $name"
  for p in "${patches[@]}"; do
    git -C "$repo_dir" am --3way "$p"
  done
}

apply_series "u-boot" "$ROOT/sources/u-boot" "$ROOT/patches/u-boot"
apply_series "linux" "$ROOT/sources/linux" "$ROOT/patches/linux"

echo "Patch application complete"
