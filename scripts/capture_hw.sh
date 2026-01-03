#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: capture_hw.sh --distro <debian|ubuntu> [--label <label>] [--out <dir>]

Captures hardware logs and DT snapshots into captures/<distro>/<timestamp>[_label].
USAGE
}

require_arg() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "Missing required arg: $name" >&2
    usage
    exit 1
  fi
}

DISTRO=""
LABEL=""
OUT_ROOT="captures"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --distro)
      DISTRO="$2"
      shift 2
      ;;
    --label)
      LABEL="$2"
      shift 2
      ;;
    --out)
      OUT_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_arg "--distro" "$DISTRO"

TS="$(date +%F_%H%M%S)"
if [[ -n "$LABEL" ]]; then
  OUT_DIR="$OUT_ROOT/$DISTRO/${TS}_${LABEL}"
else
  OUT_DIR="$OUT_ROOT/$DISTRO/$TS"
fi

mkdir -p "$OUT_DIR"

if [[ $EUID -ne 0 ]]; then
  echo "Note: run as root for complete dmesg/config capture." >&2
fi

uname -a > "$OUT_DIR/uname.txt"
cat /proc/cmdline > "$OUT_DIR/cmdline.txt"
ls -l /sys/class/mmc_host > "$OUT_DIR/mmc_host.txt" 2>&1 || true
lsblk -e7 -o NAME,SIZE,TYPE,MODEL > "$OUT_DIR/lsblk.txt" 2>&1 || true

dmesg | grep -i -E 'mmc|sdhci|dwc|dwmshc|emmc' > "$OUT_DIR/dmesg_mmc.txt" 2>&1 || true

if [[ -f /proc/config.gz ]]; then
  zcat /proc/config.gz | grep -i -E 'CONFIG_MMC|DWCMSHC|SDHCI' > "$OUT_DIR/config_mmc.txt" 2>&1 || true
else
  echo "config.gz not present" > "$OUT_DIR/config_mmc.txt"
fi

if [[ -r /sys/firmware/fdt ]]; then
  cp /sys/firmware/fdt "$OUT_DIR/live.dtb"
else
  echo "/sys/firmware/fdt not readable" > "$OUT_DIR/live.dtb"
fi

if command -v dtc >/dev/null 2>&1 && [[ -f "$OUT_DIR/live.dtb" ]]; then
  dtc -I dtb -O dts -o "$OUT_DIR/live.dts" "$OUT_DIR/live.dtb" 2>/dev/null || true
else
  echo "dtc not available" > "$OUT_DIR/live.dts"
fi

echo "Capture saved to $OUT_DIR"
