#!/usr/bin/env bash
set -euo pipefail

# Quick sanity checks for the SD->eMMC boot setup.
# Safe to run unprivileged, but root provides better device metadata.

echo "== kernel cmdline =="
cat /proc/cmdline || true
echo

echo "== device tree (mmc@50450000) =="
dt_status="/proc/device-tree/soc/mmc@50450000/status"
if [[ -r "$dt_status" ]]; then
  status=$(tr -d '\0' < "$dt_status" || true)
  if [[ -n "$status" ]]; then
    echo "status=${status}"
  else
    echo "status=<empty>"
  fi
else
  echo "Missing $dt_status (DT node not found or not readable)."
fi
echo

echo "== mounts =="
findmnt -no TARGET,SOURCE,FSTYPE / /boot 2>/dev/null || true
echo

echo "== block devices =="
lsblk -e7 -o NAME,SIZE,MODEL,TYPE,FSTYPE,LABEL,UUID,PARTUUID,MOUNTPOINTS 2>/dev/null || true
echo

echo "== label collisions (blkid) =="
if command -v blkid >/dev/null 2>&1; then
  # Print duplicate labels, if any.
  labels=$(blkid -o export 2>/dev/null | awk -F= '/^LABEL=/{print $2}') || labels=""
  if [[ -n "$labels" ]]; then
    dup=$(printf "%s\n" "$labels" | sort | uniq -d || true)
    if [[ -n "$dup" ]]; then
      echo "WARNING: duplicate filesystem LABEL(s) detected:" >&2
      printf "  %s\n" $dup >&2
      echo "This can cause initramfs to mount the wrong root. Use unique labels or PARTUUID." >&2
    else
      echo "No duplicate LABELs detected."
    fi
  else
    echo "No LABELs found (unexpected)."
  fi
else
  echo "blkid not found."
fi
echo

extlinux=/boot/extlinux/extlinux.conf
echo "== extlinux =="
if [[ -f "$extlinux" ]]; then
  echo "extlinux.conf: $extlinux"
  awk 'BEGIN{IGNORECASE=1}
       /^DEFAULT[[:space:]]+/{print;}
       /^LABEL[[:space:]]+/{label=$2; print "LABEL " label;}
       /^[[:space:]]*APPEND[[:space:]]+/{print "  " $0;}
  ' "$extlinux" || true
else
  echo "Missing $extlinux (is /boot mounted?)."
fi
echo

echo "== checks =="
root_src=$(findmnt -no SOURCE / 2>/dev/null || true)
boot_src=$(findmnt -no SOURCE /boot 2>/dev/null || true)

if [[ -n "$root_src" && -n "$boot_src" && "$root_src" == "$boot_src" ]]; then
  echo "NOTE: / and /boot are on the same source ($root_src)." 
  echo "If you intend to keep kernel/initrd on SD while rooting from eMMC, this is unusual." 
fi

if systemctl >/dev/null 2>&1; then
  echo "serial-getty@ttyS0 enabled?: $(systemctl is-enabled serial-getty@ttyS0.service 2>/dev/null || echo unknown)"
fi

echo "Done."
