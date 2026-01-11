#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'MSG'
Defensive flasher for cloning an image or block device onto eMMC.

Usage:
  sudo scripts/flash_emmc.sh --source <image|blockdev> --target <blockdev>
    [--allow-mounted-source] [--bs 4M]

Examples:
  sudo scripts/flash_emmc.sh --source /dev/mmcblk1 --target /dev/mmcblk0
  sudo scripts/flash_emmc.sh --source /path/to/sdcard.img --target /dev/mmcblk0

Notes:
  - Requires root.
  - Refuses to write if the target has mounted partitions.
  - If the source is a block device with mounted partitions, you must pass --allow-mounted-source.
MSG
}

source_path=""
target=""
allow_mounted_source=0
bs="4M"
note_gpt_fix=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) source_path="$2"; shift 2 ;;
    --target) target="$2"; shift 2 ;;
    --allow-mounted-source) allow_mounted_source=1; shift ;;
    --bs) bs="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Must run as root (sudo)." >&2
  exit 1
fi

if [[ -z "$source_path" || -z "$target" ]]; then
  echo "Missing --source and/or --target." >&2
  usage
  exit 1
fi

if [[ "$source_path" == "$target" ]]; then
  echo "Source and target must be different." >&2
  exit 1
fi

if [[ ! -e "$source_path" ]]; then
  echo "Missing source: $source_path" >&2
  exit 1
fi

if [[ ! -b "$target" ]]; then
  echo "Target must be a block device (got: $target)." >&2
  exit 1
fi

target_type=$(lsblk -no TYPE "$target" 2>/dev/null || true)
if [[ "$target_type" != "disk" ]]; then
  echo "Target must be a whole-disk device (got type: $target_type)." >&2
  exit 1
fi

if [[ -b "$source_path" ]]; then
  source_type=$(lsblk -no TYPE "$source_path" 2>/dev/null || true)
  if [[ "$source_type" != "disk" ]]; then
    echo "Source block device must be a whole-disk device (got type: $source_type)." >&2
    exit 1
  fi
fi

echo "== device inventory =="
lsblk -e7 -o NAME,SIZE,MODEL,TYPE,FSTYPE,LABEL,UUID,PARTUUID,MOUNTPOINTS
echo

if lsblk -n -o MOUNTPOINTS "$target" | grep -q '\S'; then
  echo "Target has mounted partitions. Unmount before flashing:" >&2
  lsblk -o NAME,MOUNTPOINTS "$target" >&2
  exit 1
fi

source_mounted=0
if [[ -b "$source_path" ]]; then
  if lsblk -n -o MOUNTPOINTS "$source_path" | grep -q '\S'; then
    source_mounted=1
    if [[ $allow_mounted_source -ne 1 ]]; then
      echo "Source has mounted partitions. Rerun with --allow-mounted-source to continue." >&2
      lsblk -o NAME,MOUNTPOINTS "$source_path" >&2
      exit 1
    fi
  fi
fi

if command -v blockdev >/dev/null 2>&1; then
  target_size=$(blockdev --getsize64 "$target" 2>/dev/null || true)
  if [[ -n "$target_size" && -b "$source_path" ]]; then
    source_size=$(blockdev --getsize64 "$source_path" 2>/dev/null || true)
  elif [[ -n "$target_size" && -f "$source_path" ]]; then
    source_size=$(stat -c %s "$source_path" 2>/dev/null || true)
  else
    source_size=""
  fi

  if [[ -n "$target_size" && -n "$source_size" && "$source_size" -gt "$target_size" ]]; then
    echo "Source is larger than target (source: $source_size bytes, target: $target_size bytes)." >&2
    exit 1
  fi
  if [[ -n "$target_size" && -n "$source_size" && "$target_size" -gt "$source_size" ]]; then
    note_gpt_fix=1
  fi
fi

echo "About to write:"
echo "  source: $source_path"
echo "  target: $target"
read -r -p "Type the full target device ($target) to continue: " confirm
if [[ "$confirm" != "$target" ]]; then
  echo "Confirmation did not match. Aborting." >&2
  exit 1
fi

if [[ $source_mounted -eq 1 ]]; then
  echo "WARNING: source is mounted; the clone may be inconsistent if the filesystem is changing." >&2
  echo "Prefer an unmounted source or a host image file when possible." >&2
fi

dd if="$source_path" of="$target" bs="$bs" conv=fsync status=progress
sync
if command -v blockdev >/dev/null 2>&1; then
  blockdev --flushbufs "$target" || true
fi

if [[ $note_gpt_fix -eq 1 ]]; then
  echo "NOTE: source is smaller than target; relocate backup GPT with:" >&2
  echo "  sudo sgdisk -e $target" >&2
  echo "  sudo partprobe $target || true" >&2
fi

echo "Flash complete: $source_path -> $target"
