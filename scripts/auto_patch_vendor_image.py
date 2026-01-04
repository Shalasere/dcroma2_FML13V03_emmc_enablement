#!/usr/bin/env python3
"""Auto-find and patch a DTB inside a disk image.

Why this exists
--------------
The earlier workflow (`extract_dtbs_from_image.py` -> inspect -> patch by offset) works, but it's
easy to make mistakes and the naive extractor reads the *entire* image into RAM.

This script scans the image via `mmap`, identifies candidate DTBs by model string, and patches the
`status` property of a given node (default: /soc/mmc@50450000) in-place.

Safety
------
* No SPI writes.
* Only patches an existing string property *in place* and only when the new string fits in the old
  allocation (e.g., "disabled" -> "okay"). If the property is missing or too small, it refuses.
"""

from __future__ import annotations

import argparse
import mmap
import os
import struct
import sys
from pathlib import Path


MAGIC = 0xD00DFEED

FDT_BEGIN_NODE = 1
FDT_END_NODE = 2
FDT_PROP = 3
FDT_NOP = 4
FDT_END = 9


def read_u32_be(buf: bytes, off: int) -> int:
    return struct.unpack_from(">I", buf, off)[0]


def align4(x: int) -> int:
    return (x + 3) & ~3


def parse_header(dtb: bytes) -> dict:
    if len(dtb) < 40:
        raise ValueError("DTB too small")
    magic = read_u32_be(dtb, 0)
    if magic != MAGIC:
        raise ValueError("bad magic")
    return {
        "totalsize": read_u32_be(dtb, 4),
        "off_struct": read_u32_be(dtb, 8),
        "off_strings": read_u32_be(dtb, 12),
        "size_strings": read_u32_be(dtb, 32),
        "size_struct": read_u32_be(dtb, 36),
    }


def get_string(strings_block: bytes, off: int) -> str:
    end = strings_block.find(b"\x00", off)
    if end == -1:
        return ""
    return strings_block[off:end].decode("ascii", errors="ignore")


def decode_str(val: bytes) -> str:
    if not val:
        return ""
    parts = [p.decode("ascii", errors="ignore") for p in val.split(b"\x00") if p]
    return ",".join(parts)


def dtb_get_props(dtb: bytes) -> list[tuple[str, str, bytes]]:
    """Return [(path, prop_name, value_bytes)] for all properties."""
    h = parse_header(dtb)
    off_struct = h["off_struct"]
    off_strings = h["off_strings"]
    size_struct = h["size_struct"]
    size_strings = h["size_strings"]

    struct_block = dtb[off_struct : off_struct + size_struct]
    strings_block = dtb[off_strings : off_strings + size_strings]

    stack: list[str] = []
    props: list[tuple[str, str, bytes]] = []

    off = 0
    while off + 4 <= len(struct_block):
        token = read_u32_be(struct_block, off)
        off += 4

        if token == FDT_BEGIN_NODE:
            end = struct_block.find(b"\x00", off)
            if end == -1:
                break
            name = struct_block[off:end].decode("ascii", errors="ignore")
            off = align4(end + 1)
            stack.append(name)
        elif token == FDT_END_NODE:
            if stack:
                stack.pop()
        elif token == FDT_PROP:
            if off + 8 > len(struct_block):
                break
            length = read_u32_be(struct_block, off)
            nameoff = read_u32_be(struct_block, off + 4)
            off += 8
            val = struct_block[off : off + length]
            off = align4(off + length)
            pname = get_string(strings_block, nameoff)
            path = "/" + "/".join([n for n in stack if n])
            props.append((path, pname, val))
        elif token == FDT_NOP:
            continue
        elif token == FDT_END:
            break
        else:
            break

    return props


def dtb_find_status_value_offset(dtb: bytes, node_path: str) -> tuple[int, int] | None:
    """Return (value_offset_in_dtb, value_length) for <node_path>/status, or None.

    The offset returned points into the DTB byte-string (not the struct_block slice).
    """
    h = parse_header(dtb)
    off_struct = h["off_struct"]
    off_strings = h["off_strings"]
    size_struct = h["size_struct"]
    size_strings = h["size_strings"]

    struct_block = dtb[off_struct : off_struct + size_struct]
    strings_block = dtb[off_strings : off_strings + size_strings]

    stack: list[str] = []
    off = 0
    while off + 4 <= len(struct_block):
        token = read_u32_be(struct_block, off)
        off += 4

        if token == FDT_BEGIN_NODE:
            end = struct_block.find(b"\x00", off)
            if end == -1:
                break
            name = struct_block[off:end].decode("ascii", errors="ignore")
            off = align4(end + 1)
            stack.append(name)
        elif token == FDT_END_NODE:
            if stack:
                stack.pop()
        elif token == FDT_PROP:
            if off + 8 > len(struct_block):
                break
            length = read_u32_be(struct_block, off)
            nameoff = read_u32_be(struct_block, off + 4)
            off += 8

            pname = get_string(strings_block, nameoff)
            path = "/" + "/".join([n for n in stack if n])

            value_struct_off = off  # offset inside struct_block where value starts
            off = align4(off + length)

            if path == node_path and pname == "status":
                # convert struct_block offset to dtb offset
                return off_struct + value_struct_off, length
        elif token == FDT_NOP:
            continue
        elif token == FDT_END:
            break
        else:
            break

    return None


def main() -> int:
    ap = argparse.ArgumentParser(description="Auto-find and patch DTB status property inside an image (mmap-based).")
    ap.add_argument("--image", required=True, help="Path to disk image (e.g., sdcard.img)")
    ap.add_argument("--match-model", default="FML13V03", help="Substring that must appear in DTB model")
    ap.add_argument("--path", default="/soc/mmc@50450000", help="Node path whose status will be patched")
    ap.add_argument("--status", default="okay", help="New status string (default: okay)")
    ap.add_argument("--max-dtb", type=int, default=4 * 1024 * 1024, help="Ignore DTBs larger than this (bytes)")
    ap.add_argument("--dry-run", action="store_true", help="Scan and report candidates, do not modify the image")
    ap.add_argument("--backup-dtb", help="Write the original DTB bytes here")
    ap.add_argument("--out-dtb", help="Write the patched DTB bytes here")
    args = ap.parse_args()

    img_path = Path(args.image)
    if not img_path.exists():
        print(f"Missing image: {img_path}", file=sys.stderr)
        return 2

    new_status = (args.status + "\x00").encode("ascii")

    # Open RW only when actually patching.
    mode = "r+b" if not args.dry_run else "rb"
    with img_path.open(mode) as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_WRITE if not args.dry_run else mmap.ACCESS_READ)

        candidates: list[tuple[int, str, str]] = []  # (offset, model, current_status)
        pos = 0
        magic_bytes = struct.pack(">I", MAGIC)
        img_size = mm.size()

        while True:
            off = mm.find(magic_bytes, pos)
            if off == -1:
                break
            pos = off + 4

            # Quick header sanity
            if off + 40 > img_size:
                continue
            hdr = mm[off : off + 40]
            try:
                h = parse_header(hdr)
            except Exception:
                continue

            totalsize = h["totalsize"]
            if totalsize <= 0 or totalsize > args.max_dtb:
                continue
            if off + totalsize > img_size:
                continue

            dtb = mm[off : off + totalsize]
            try:
                props = dtb_get_props(dtb)
            except Exception:
                continue

            model = ""
            for p, n, v in props:
                if p == "/" and n == "model":
                    model = decode_str(v)
                    break
            if args.match_model and args.match_model not in model:
                continue

            cur_status = "<missing>"
            for p, n, v in props:
                if p == args.path and n == "status":
                    cur_status = decode_str(v)
                    break

            candidates.append((off, model, cur_status))

        if not candidates:
            print("No DTB candidates found that matched the model filter.")
            return 1

        # Prefer a candidate where the node exists and is not already okay.
        pick = None
        for off, model, st in candidates:
            if st and st != "okay" and st != "<missing>":
                pick = (off, model, st)
                break
        if pick is None:
            pick = candidates[0]

        off, model, st = pick
        print(f"Selected DTB at offset 0x{off:08x}")
        print(f"model: {model}")
        print(f"{args.path} status: {st}")
        if len(candidates) > 1:
            print("Other candidates:")
            for o, m, s in candidates[:10]:
                if o == off:
                    continue
                print(f"  0x{o:08x}  status={s}  model={m}")

        totalsize = read_u32_be(mm[off : off + 8], 4)
        dtb = mm[off : off + totalsize]

        loc = dtb_find_status_value_offset(dtb, args.path)
        if loc is None:
            print(f"ERROR: did not find an existing '{args.path}/status' property to patch.", file=sys.stderr)
            return 1
        val_off, val_len = loc

        if len(new_status) > val_len:
            print(
                f"ERROR: new status '{args.status}' is longer than existing allocation ({val_len} bytes).",
                file=sys.stderr,
            )
            return 1

        # Backup DTB bytes (optional)
        if args.backup_dtb:
            Path(args.backup_dtb).write_bytes(bytes(dtb))

        if args.dry_run:
            print("Dry-run: not modifying the image.")
            return 0

        # Patch in-place: write new string and pad the remainder with NULs.
        abs_val_off = off + val_off
        mm[abs_val_off : abs_val_off + len(new_status)] = new_status
        if len(new_status) < val_len:
            mm[abs_val_off + len(new_status) : abs_val_off + val_len] = b"\x00" * (val_len - len(new_status))

        # Export patched DTB (optional)
        if args.out_dtb:
            dtb_patched = bytes(mm[off : off + totalsize])
            Path(args.out_dtb).write_bytes(dtb_patched)

        mm.flush()
        mm.close()

    print("Patched image in-place.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
