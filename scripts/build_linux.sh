#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/sources/linux"
OUT="$ROOT/out/linux"

if [[ ! -d "$SRC" ]]; then
  echo "Missing source tree: $SRC" >&2
  exit 1
fi

if [[ -z "${CROSS_COMPILE:-}" ]]; then
  echo "Set CROSS_COMPILE (e.g. riscv64-unknown-linux-gnu-)" >&2
  exit 1
fi

if [[ -z "${LINUX_DEFCONFIG:-}" ]]; then
  echo "Set LINUX_DEFCONFIG (base defconfig name)" >&2
  exit 1
fi

JOBS=${JOBS:-"$(getconf _NPROCESSORS_ONLN)"}

mkdir -p "$OUT"

make -C "$SRC" O="$OUT" ARCH=riscv CROSS_COMPILE="$CROSS_COMPILE" "$LINUX_DEFCONFIG"
make -C "$SRC" O="$OUT" ARCH=riscv CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS" Image dtbs modules

echo "Linux build complete: $OUT"
