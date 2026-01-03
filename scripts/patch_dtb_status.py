#!/usr/bin/env python3
import argparse
import struct
import sys
from pathlib import Path

MAGIC = 0xD00DFEED
FDT_BEGIN_NODE = 1
FDT_END_NODE = 2
FDT_PROP = 3
FDT_NOP = 4
FDT_END = 9


def read_u32(buf, off):
    return struct.unpack_from(">I", buf, off)[0]


def align4(x):
    return (x + 3) & ~3


def decode_str(val: bytes) -> str:
    if not val:
        return ""
    if b"\x00" in val:
        val = val.split(b"\x00", 1)[0]
    return val.decode("ascii", errors="ignore")


def parse_header(data: bytes):
    if len(data) < 40:
        raise ValueError("DTB header too small")
    magic = read_u32(data, 0)
    if magic != MAGIC:
        raise ValueError("Bad DTB magic")
    totalsize = read_u32(data, 4)
    off_struct = read_u32(data, 8)
    off_strings = read_u32(data, 12)
    size_strings = read_u32(data, 32)
    size_struct = read_u32(data, 36)
    return totalsize, off_struct, off_strings, size_struct, size_strings


def find_status_prop(data: bytes, target_path: str):
    totalsize, off_struct, off_strings, size_struct, size_strings = parse_header(data)
    struct_block = data[off_struct : off_struct + size_struct]
    strings_block = data[off_strings : off_strings + size_strings]

    def get_string(off):
        end = strings_block.find(b"\x00", off)
        if end == -1:
            return ""
        return strings_block[off:end].decode("ascii", errors="ignore")

    stack = []
    off = 0
    while off + 4 <= len(struct_block):
        token = read_u32(struct_block, off)
        off += 4

        if token == FDT_BEGIN_NODE:
            end = struct_block.find(b"\x00", off)
            if end == -1:
                raise ValueError("Unterminated node name")
            name = struct_block[off:end].decode("ascii", errors="ignore")
            off = align4(end + 1)
            stack.append(name)
        elif token == FDT_END_NODE:
            if stack:
                stack.pop()
        elif token == FDT_PROP:
            if off + 8 > len(struct_block):
                raise ValueError("Truncated property")
            length = read_u32(struct_block, off)
            nameoff = read_u32(struct_block, off + 4)
            off += 8
            val_off = off
            off = align4(off + length)
            pname = get_string(nameoff)
            path = "/" + "/".join([n for n in stack if n])
            if path == target_path and pname == "status":
                abs_off = off_struct + val_off
                return abs_off, length
        elif token == FDT_NOP:
            continue
        elif token == FDT_END:
            break
        else:
            break
    return None, None


def main():
    parser = argparse.ArgumentParser(description="Patch DTB status property in a raw image.")
    parser.add_argument("--image", required=True, help="Path to image file")
    parser.add_argument("--offset", required=True, help="DTB offset in image (hex like 0x0817d000)")
    parser.add_argument("--path", required=True, help="DT node path (e.g. /soc/mmc@50450000)")
    parser.add_argument("--status", default="okay", help="Status string (default: okay)")
    parser.add_argument("--backup", help="Write original DTB to this file")
    parser.add_argument("--out-dtb", help="Write patched DTB to this file")
    args = parser.parse_args()

    image = Path(args.image).expanduser().resolve()
    if not image.exists():
        print(f"Image not found: {image}", file=sys.stderr)
        return 1

    offset = int(args.offset, 0)
    status_bytes = args.status.encode("ascii") + b"\x00"

    with image.open("r+b") as f:
        f.seek(offset)
        header = f.read(40)
        totalsize, off_struct, off_strings, size_struct, size_strings = parse_header(header)
        f.seek(offset)
        dtb = bytearray(f.read(totalsize))

        if args.backup:
            Path(args.backup).write_bytes(dtb)

        val_off, length = find_status_prop(dtb, args.path)
        if val_off is None:
            print(f"status property not found at {args.path}", file=sys.stderr)
            return 1

        current = decode_str(dtb[val_off : val_off + length])
        if length < len(status_bytes):
            print("status field too small for new value", file=sys.stderr)
            return 1

        # overwrite, keep original length to avoid resizing
        dtb[val_off : val_off + length] = status_bytes.ljust(length, b"\x00")

        new_val = decode_str(dtb[val_off : val_off + length])
        f.seek(offset)
        f.write(dtb)

    if args.out_dtb:
        Path(args.out_dtb).write_bytes(dtb)

    print(f"status: {current} -> {new_val}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
