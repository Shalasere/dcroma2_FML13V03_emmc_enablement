#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/sources/opensbi"
OUT="$ROOT/out/opensbi"

if [[ ! -d "$SRC" ]]; then
  echo "OpenSBI source not found, skipping." >&2
  exit 0
fi

if [[ -z "${CROSS_COMPILE:-}" ]]; then
  echo "Set CROSS_COMPILE (e.g. riscv64-unknown-linux-gnu-)" >&2
  exit 1
fi

if [[ -z "${OPENSBI_PLATFORM:-}" ]]; then
  echo "Set OPENSBI_PLATFORM (e.g. generic)" >&2
  exit 1
fi

JOBS=${JOBS:-"$(getconf _NPROCESSORS_ONLN)"}

mkdir -p "$OUT"

make -C "$SRC" O="$OUT" CROSS_COMPILE="$CROSS_COMPILE" PLATFORM="$OPENSBI_PLATFORM" -j"$JOBS"

echo "OpenSBI build complete: $OUT"
