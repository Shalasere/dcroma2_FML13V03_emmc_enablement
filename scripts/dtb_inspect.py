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


def parse_dtb(path: Path):
    data = path.read_bytes()
    if len(data) < 40:
        raise ValueError("File too small for DTB header")

    magic = read_u32(data, 0)
    if magic != MAGIC:
        raise ValueError("Not a DTB (bad magic)")

    totalsize = read_u32(data, 4)
    off_struct = read_u32(data, 8)
    off_strings = read_u32(data, 12)
    size_strings = read_u32(data, 32)
    size_struct = read_u32(data, 36)

    struct_block = data[off_struct : off_struct + size_struct]
    strings_block = data[off_strings : off_strings + size_strings]

    def get_string(off):
        end = strings_block.find(b"\x00", off)
        if end == -1:
            return ""
        return strings_block[off:end].decode("ascii", errors="ignore")

    nodes = []
    props = []

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
            nodes.append("/" + "/".join([n for n in stack if n]))
        elif token == FDT_END_NODE:
            if stack:
                stack.pop()
        elif token == FDT_PROP:
            if off + 8 > len(struct_block):
                raise ValueError("Truncated property")
            length = read_u32(struct_block, off)
            nameoff = read_u32(struct_block, off + 4)
            off += 8
            val = struct_block[off : off + length]
            off = align4(off + length)
            pname = get_string(nameoff)
            path = "/" + "/".join([n for n in stack if n])
            props.append((path, pname, val))
        elif token == FDT_NOP:
            continue
        elif token == FDT_END:
            break
        else:
            # Unknown token
            break

    return props


def decode_str(val: bytes):
    if not val:
        return ""
    # strings are null-terminated; may be multiple strings
    parts = val.split(b"\x00")
    parts = [p.decode("ascii", errors="ignore") for p in parts if p]
    return ",".join(parts)


def main():
    parser = argparse.ArgumentParser(description="Inspect DTB for key properties.")
    parser.add_argument("dtb", help="Path to .dtb")
    parser.add_argument("--mmc", action="store_true", help="Show mmc@* nodes and status")
    parser.add_argument("--model", action="store_true", help="Show model and compatible")
    args = parser.parse_args()

    dtb = Path(args.dtb)
    if not dtb.exists():
        print(f"Missing: {dtb}", file=sys.stderr)
        return 1

    props = parse_dtb(dtb)

    if args.model:
        model = [decode_str(v) for p, n, v in props if p == "/" and n == "model"]
        compat = [decode_str(v) for p, n, v in props if p == "/" and n == "compatible"]
        if model:
            print(f"model: {model[0]}")
        if compat:
            print(f"compatible: {compat[0]}")

    if args.mmc:
        mmc_nodes = {}
        for path, name, val in props:
            if "/mmc@" in path:
                mmc_nodes.setdefault(path, {})
                if name in ("status", "compatible", "bus-width"):
                    mmc_nodes[path][name] = decode_str(val)
        for path in sorted(mmc_nodes.keys()):
            info = mmc_nodes[path]
            status = info.get("status", "<missing>")
            compat = info.get("compatible", "<missing>")
            bw = info.get("bus-width", "<missing>")
            print(f"{path} status={status} compatible={compat} bus-width={bw}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
