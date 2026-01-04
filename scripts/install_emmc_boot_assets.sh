#!/usr/bin/env bash
set -euo pipefail

# Stage boot assets on the eMMC boot partition and add an extlinux entry that
# points root= to the eMMC root partition.
#
# Usage:
#   sudo scripts/install_emmc_boot_assets.sh \
#     [--boot-label boot-emmc] \
#     [--root-label root-emmc] \
#     [--entry-label emmc] \
#     [--src-boot /boot] \
#     [--mount-point /mnt/emmc-boot] \
#     [--copy-from <label>] \
#     [--default] \
#     [--purge]

boot_label="boot-emmc"
root_label="root-emmc"
entry_label="emmc"
src_boot="/boot"
mount_point="/mnt/emmc-boot"
copy_from=""
set_default=0
purge=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --boot-label) boot_label="$2"; shift 2 ;;
    --root-label) root_label="$2"; shift 2 ;;
    --entry-label) entry_label="$2"; shift 2 ;;
    --src-boot) src_boot="$2"; shift 2 ;;
    --mount-point) mount_point="$2"; shift 2 ;;
    --copy-from) copy_from="$2"; shift 2 ;;
    --default) set_default=1; shift ;;
    --purge) purge=1; shift ;;
    -h|--help)
      sed -n '1,80p' "$0"
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

if [[ ! -d "$src_boot" ]]; then
  echo "Missing source boot dir: $src_boot" >&2
  exit 1
fi
if [[ ! -f "$src_boot/extlinux/extlinux.conf" ]]; then
  echo "Missing $src_boot/extlinux/extlinux.conf" >&2
  exit 1
fi

boot_dev="/dev/disk/by-label/${boot_label}"
if [[ ! -e "$boot_dev" ]]; then
  echo "Missing $boot_dev. Ensure the eMMC boot partition is labeled '${boot_label}'." >&2
  exit 1
fi

mkdir -p "$mount_point"

mounted=0
boot_real=$(readlink -f "$boot_dev" 2>/dev/null || echo "$boot_dev")
if ! mountpoint -q "$mount_point"; then
  mount "$boot_dev" "$mount_point"
  mounted=1
fi

# If mount_point was already mounted, ensure it is actually the eMMC boot partition we expect.
src=$(findmnt -no SOURCE "$mount_point" 2>/dev/null || true)
src_real=$(readlink -f "$src" 2>/dev/null || echo "$src")
if [[ -n "$src" && "$src_real" != "$boot_real" ]]; then
  echo "Mountpoint $mount_point is already mounted from $src (resolved: $src_real), not $boot_dev (resolved: $boot_real)." >&2
  echo "Refusing to continue to avoid copying boot assets to the wrong filesystem." >&2
  exit 1
fi


if [[ $purge -eq 1 ]]; then
  if [[ "$mount_point" == "/" || "$mount_point" == "/boot" ]]; then
    echo "Refusing to purge $mount_point (unsafe)." >&2
    exit 1
  fi
  if [[ "$mount_point" != /mnt/* && "$mount_point" != /media/* ]]; then
    echo "Refusing to purge $mount_point (not under /mnt or /media)." >&2
    exit 1
  fi
  rm -rf "${mount_point:?}/"*
fi

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$src_boot/." "$mount_point/"
else
  echo "rsync not found; copying without delete. Old files may remain on eMMC /boot." >&2
  cp -a "$src_boot/." "$mount_point/"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
args=(--extlinux "$mount_point/extlinux/extlinux.conf" --root-label "$root_label" --entry-label "$entry_label")
if [[ -n "$copy_from" ]]; then
  args+=(--copy-from "$copy_from")
fi
if [[ $set_default -eq 1 ]]; then
  args+=(--default)
fi

"$script_dir/setup_emmc_extlinux.sh" "${args[@]}"

sync

if [[ $mounted -eq 1 ]]; then
  umount "$mount_point"
fi

echo "Staged boot assets on ${boot_label} and updated extlinux for root=${root_label}."
