#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist/$(date +%F_%H%M%S)"

mkdir -p "$DIST"

copy_if_exists() {
  local src="$1"
  local dest_dir="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$dest_dir"
    cp -a "$src" "$dest_dir/"
  fi
}

OUT_UBOOT="$ROOT/out/u-boot"
OUT_LINUX="$ROOT/out/linux"
OUT_OPENSBI="$ROOT/out/opensbi"

copy_if_exists "$OUT_UBOOT/u-boot.bin" "$DIST/u-boot"
copy_if_exists "$OUT_UBOOT/u-boot.itb" "$DIST/u-boot"
copy_if_exists "$OUT_UBOOT/spl/u-boot-spl.bin" "$DIST/u-boot"

copy_if_exists "$OUT_LINUX/arch/riscv/boot/Image" "$DIST/linux"

if [[ -d "$OUT_LINUX/arch/riscv/boot/dts" ]]; then
  mkdir -p "$DIST/dtbs"
  find "$OUT_LINUX/arch/riscv/boot/dts" -name '*fml13v03*.dtb' -exec cp -a {} "$DIST/dtbs/" \; || true
fi

if [[ -d "$OUT_OPENSBI" ]]; then
  mkdir -p "$DIST/opensbi"
  find "$OUT_OPENSBI" -name 'fw_*.bin' -exec cp -a {} "$DIST/opensbi/" \; || true
fi

META="$DIST/metadata.txt"
{
  echo "timestamp=$(date -u +%F_%H%M%SZ)"
  if [[ -d "$ROOT/vendor" ]]; then
    echo ""
    echo "[vendor-manifests]"
    find "$ROOT/vendor" -name 'manifest.txt' -print
  fi
  for repo in u-boot linux opensbi; do
    if [[ -d "$ROOT/sources/$repo/.git" ]]; then
      echo ""
      echo "[$repo]"
      git -C "$ROOT/sources/$repo" rev-parse HEAD
    fi
  done
  if [[ -n "${CROSS_COMPILE:-}" ]]; then
    echo ""
    echo "[toolchain]"
    "${CROSS_COMPILE}gcc" --version | head -n 1 || true
  fi
} > "$META"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$DIST" && find . -type f ! -name 'SHA256SUMS' -exec sha256sum {} + | sort -k2) > "$DIST/SHA256SUMS" || true
fi

echo "Release bundle created: $DIST"
