#!/usr/bin/env bash
set -euo pipefail

# Adds/updates an extlinux entry that boots the kernel/initrd from the *current* /boot (typically SD)
# while switching the Linux root filesystem to the eMMC root partition.
#
# This script is intentionally conservative:
# - It copies an existing working entry (default: the current DEFAULT label) and only rewrites root=...
# - It uses root=PARTUUID=... by default (labels can collide and cause initramfs drops).
#
# Usage:
#   sudo scripts/setup_emmc_extlinux.sh \
#     [--extlinux /boot/extlinux/extlinux.conf] \
#     [--root-label root-emmc] \
#     [--entry-label emmc] \
#     [--copy-from <label>] \
#     [--default]

extlinux=/boot/extlinux/extlinux.conf
root_label="root-emmc"
entry_label="emmc"
copy_from=""
set_default=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --extlinux) extlinux="$2"; shift 2 ;;
    --root-label) root_label="$2"; shift 2 ;;
    --entry-label) entry_label="$2"; shift 2 ;;
    --copy-from) copy_from="$2"; shift 2 ;;
    --default) set_default=1; shift ;;
    -h|--help)
      sed -n '1,60p' "$0"
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

if [[ ! -f "$extlinux" ]]; then
  echo "Missing $extlinux." >&2
  exit 1
fi

root_dev="/dev/disk/by-label/${root_label}"
if [[ ! -e "$root_dev" ]]; then
  echo "Missing $root_dev. Ensure the eMMC root partition is labeled '${root_label}'." >&2
  echo "Hint: e2label /dev/<emmc-root-part> ${root_label}" >&2
  exit 1
fi

root_real=$(readlink -f "$root_dev")
partuuid=$(blkid -s PARTUUID -o value "$root_real" 2>/dev/null || true)
if [[ -z "$partuuid" ]]; then
  echo "Could not read PARTUUID for $root_real." >&2
  exit 1
fi

# Determine a source entry to copy.
if [[ -z "$copy_from" ]]; then
  copy_from=$(awk 'BEGIN{IGNORECASE=1} /^DEFAULT[[:space:]]+/ {print $2; exit}' "$extlinux" || true)
fi
if [[ -z "$copy_from" ]]; then
  copy_from=$(awk 'BEGIN{IGNORECASE=1} /^LABEL[[:space:]]+/ {print $2; exit}' "$extlinux" || true)
fi
if [[ -z "$copy_from" ]]; then
  echo "Could not determine a source LABEL to copy from in $extlinux." >&2
  exit 1
fi

ts=$(date +%Y%m%d_%H%M%S)
cp "$extlinux" "${extlinux}.bak_${ts}"

tmp=$(mktemp)

# Rewrite logic:
# - Capture stanza for LABEL <copy_from>
# - Drop any existing LABEL <entry_label>
# - After the source stanza, emit a duplicated stanza as LABEL <entry_label> with root=PARTUUID=...

awk -v src="$copy_from" -v dst="$entry_label" -v pu="$partuuid" -v make_default="$set_default" '
  BEGIN {
    IGNORECASE=1
    capturing=0
    skipping_dst=0
    have_src=0
    n=0
  }

  function reset_src() { n=0 }

  function stash(line) {
    src_lines[++n] = line
  }

  function emit_dst() {
    if (!have_src) return
    print ""
    for (i = 1; i <= n; i++) {
      line = src_lines[i]
      if (line ~ /^[[:space:]]*LABEL[[:space:]]+/) {
        sub(/^[[:space:]]*LABEL[[:space:]]+.*/, "LABEL " dst, line)
        print line
        continue
      }
      if (line ~ /^[[:space:]]*APPEND[[:space:]]+/) {
        if (line ~ /(^|[[:space:]])root=[^[:space:]]+/) {
          gsub(/(^|[[:space:]])root=[^[:space:]]+/, " root=PARTUUID=" pu, line)
        } else {
          sub(/^[[:space:]]*APPEND[[:space:]]+/, "APPEND root=PARTUUID=" pu " ", line)
        }
        print line
        continue
      }
      print line
    }
  }

  {
    # DEFAULT handling (optional)
    if (make_default == 1 && $1 ~ /^DEFAULT$/) {
      print "DEFAULT " dst
      next
    }

    # Stanza boundary detection
    if ($1 ~ /^LABEL$/) {
      # close out prior stanza if we were capturing source
      if (capturing) {
        capturing=0
        have_src=1
        emit_dst()
      }

      # start of a destination stanza: skip it entirely
      if (tolower($2) == tolower(dst)) {
        skipping_dst=1
        next
      }
      skipping_dst=0

      # start of a source stanza: capture and print
      if (tolower($2) == tolower(src)) {
        reset_src()
        capturing=1
        stash($0)
        print
        next
      }

      # any other stanza: normal pass-through
      print
      next
    }

    # Skip content of an existing destination stanza
    if (skipping_dst) {
      next
    }

    # While capturing source stanza, stash and pass-through
    if (capturing) {
      stash($0)
      print
      next
    }

    # default: pass-through
    print
  }

  END {
    if (capturing) {
      capturing=0
      have_src=1
      emit_dst()
    }
    if (!have_src) {
      print ""
      print "# Added by setup_emmc_extlinux.sh"
      print "LABEL " dst
      print "  # WARNING: source stanza not found; add LINUX/INITRD/FDT lines manually"
      print "  APPEND root=PARTUUID=" pu " rootwait rw console=ttyS0,115200n8"
    }
  }
' "$extlinux" > "$tmp"

mv "$tmp" "$extlinux"
sync

echo "Updated $extlinux: added/updated LABEL '${entry_label}' (root=PARTUUID=${partuuid})."
echo "Backup: ${extlinux}.bak_${ts}"
