#!/usr/bin/env bash
set -euo pipefail

# Adds an extlinux entry that boots from eMMC (mmcblk0p3) while keeping kernel/initrd on the current /boot (typically SD).
# Usage: sudo scripts/setup_emmc_extlinux.sh [--default]
#   --default  Set DEFAULT to emmc-root in extlinux.conf

set_default=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --default) set_default=1; shift ;;
    -h|--help)
      echo "Usage: sudo $0 [--default]"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Must run as root (sudo)." >&2
  exit 1
fi

extlinux=/boot/extlinux/extlinux.conf
if [[ ! -f "$extlinux" ]]; then
  echo "Missing $extlinux (are you on the SD boot root?)." >&2
  exit 1
fi

if [[ ! -b /dev/mmcblk0p3 ]]; then
  echo "Expected /dev/mmcblk0p3 (eMMC rootfs) not found." >&2
  exit 1
fi

partuuid=$(blkid -s PARTUUID -o value /dev/mmcblk0p3)
if [[ -z "$partuuid" ]]; then
  echo "Could not read PARTUUID for /dev/mmcblk0p3." >&2
  exit 1
fi

ts=$(date +%Y%m%d_%H%M%S)
cp "$extlinux" "${extlinux}.bak_${ts}"

entry=$(cat <<EOF

LABEL emmc-root
  LINUX /boot/vmlinuz
  INITRD /boot/initrd.img
  APPEND root=PARTUUID=${partuuid} rootwait console=ttyS0,115200n8
EOF
)

# If an emmc-root entry already exists, replace it; else append.
tmp=$(mktemp)
if grep -q '^LABEL emmc-root' "$extlinux"; then
  awk -v repl="$entry" '
    /^LABEL emmc-root/ {in_entry=1; if (!printed) {print repl; printed=1} next}
    /^LABEL / && in_entry {in_entry=0; next}
    !in_entry {print}
  ' "$extlinux" > "$tmp"
else
  cat "$extlinux" > "$tmp"
  echo "$entry" >> "$tmp"
fi

if [[ $set_default -eq 1 ]]; then
  if grep -q '^DEFAULT ' "$tmp"; then
    sed -i 's/^DEFAULT .*/DEFAULT emmc-root/' "$tmp"
  else
    sed -i '1iDEFAULT emmc-root' "$tmp"
  fi
fi

mv "$tmp" "$extlinux"
sync

echo "Updated $extlinux with emmc-root (root=PARTUUID=${partuuid}). Backup: ${extlinux}.bak_${ts}"
