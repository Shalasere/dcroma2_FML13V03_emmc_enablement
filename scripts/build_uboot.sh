#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/sources/u-boot"
OUT="$ROOT/out/u-boot"

if [[ ! -d "$SRC" ]]; then
  echo "Missing source tree: $SRC" >&2
  exit 1
fi

if [[ -z "${CROSS_COMPILE:-}" ]]; then
  echo "Set CROSS_COMPILE (e.g. riscv64-unknown-linux-gnu-)" >&2
  exit 1
fi

if [[ -z "${UBOOT_DEFCONFIG:-}" ]]; then
  echo "Set UBOOT_DEFCONFIG (board defconfig name)" >&2
  exit 1
fi

JOBS=${JOBS:-"$(getconf _NPROCESSORS_ONLN)"}

mkdir -p "$OUT"

make -C "$SRC" O="$OUT" ARCH=riscv CROSS_COMPILE="$CROSS_COMPILE" "$UBOOT_DEFCONFIG"
make -C "$SRC" O="$OUT" ARCH=riscv CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS"

echo "U-Boot build complete: $OUT"
