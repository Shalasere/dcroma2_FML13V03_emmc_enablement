#!/usr/bin/env python3
import argparse
import gzip
import hashlib
import lzma
import mmap
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

MAGIC = b"\xd0\r\xfe\xed"
HEADER_SIZE = 40
DEFAULT_FILTERS = ["fml13", "deepcomputing", "eic7702", "dc-roma"]


def sha256_bytes(data: bytes) -> str:
    h = hashlib.sha256()
    h.update(data)
    return h.hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def decompress_if_needed(src: Path, tmp_dir: Path) -> Path:
    suffix = src.suffix.lower()
    if suffix in (".gz", ".xz", ".lzma"):
        tmp_dir.mkdir(parents=True, exist_ok=True)
        out_path = tmp_dir / src.stem
        if out_path.exists() and out_path.stat().st_mtime >= src.stat().st_mtime:
            return out_path
        opener = gzip.open if suffix == ".gz" else lzma.open
        with opener(src, "rb") as fin, out_path.open("wb") as fout:
            shutil.copyfileobj(fin, fout, length=8 * 1024 * 1024)
        return out_path
    if suffix in (".zst", ".zstd"):
        raise RuntimeError("zst image detected; please decompress first (zstd -d).")
    return src


def scan_dtbs(mm: mmap.mmap, size: int):
    candidates = []
    offset = 0
    while True:
        idx = mm.find(MAGIC, offset)
        if idx == -1:
            break
        if idx + HEADER_SIZE <= size:
            header = mm[idx : idx + HEADER_SIZE]
            fields = struct.unpack(">10I", header)
            magic, totalsize, off_struct, off_strings, _off_mem_rsv, _ver, _last, _boot, size_strings, size_struct = fields
            if magic == 0xD00DFEED:
                if totalsize >= HEADER_SIZE and idx + totalsize <= size:
                    if (
                        off_struct < totalsize
                        and off_strings < totalsize
                        and off_struct + size_struct <= totalsize
                        and off_strings + size_strings <= totalsize
                    ):
                        candidates.append((idx, totalsize, off_strings, size_strings))
        offset = idx + 4
    return candidates


def filter_match(strings_block: bytes, filters):
    if not filters:
        return True, []
    lower = strings_block.lower()
    hits = [f for f in filters if f.encode("ascii", "ignore") in lower]
    return bool(hits), hits


def try_dtc(dtb_path: Path):
    dtc = shutil.which("dtc")
    if not dtc:
        return None
    dts_path = dtb_path.with_suffix(".dts")
    try:
        subprocess.run([dtc, "-I", "dtb", "-O", "dts", "-o", str(dts_path), str(dtb_path)], check=False)
    except OSError:
        return None
    return dts_path


def main():
    parser = argparse.ArgumentParser(description="Extract DTBs from a vendor disk image.")
    parser.add_argument("--image", required=True, help="Path to vendor image (.img, .gz, .xz)")
    parser.add_argument("--out", required=True, help="Output directory for extracted DTBs")
    parser.add_argument("--tmp-dir", default="tmp", help="Temporary directory for decompression")
    parser.add_argument("--filter", action="append", default=None, help="String filter (repeatable)")
    parser.add_argument("--no-filter", action="store_true", help="Disable default filters")
    parser.add_argument("--compare", help="Reference DTB to compare (sha256)")
    args = parser.parse_args()

    image_path = Path(args.image).expanduser().resolve()
    out_dir = Path(args.out).expanduser().resolve()
    tmp_dir = Path(args.tmp_dir).expanduser().resolve()

    if not image_path.exists():
        print(f"Image not found: {image_path}", file=sys.stderr)
        return 1

    filters = args.filter if args.filter is not None else []
    if not filters and not args.no_filter:
        filters = DEFAULT_FILTERS

    try:
        img = decompress_if_needed(image_path, tmp_dir)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)
    ref_hash = sha256_file(Path(args.compare).resolve()) if args.compare else None

    with img.open("rb") as f, mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
        size = mm.size()
        candidates = scan_dtbs(mm, size)
        seen = set()
        extracted = []

        for idx, totalsize, off_strings, size_strings in candidates:
            dtb = mm[idx : idx + totalsize]
            sha = sha256_bytes(dtb)
            if sha in seen:
                continue
            seen.add(sha)

            strings_block = mm[idx + off_strings : idx + off_strings + size_strings]
            match, hits = filter_match(strings_block, filters)
            if not match:
                continue

            name = f"dtb_{idx:08x}.dtb"
            dtb_path = out_dir / name
            dtb_path.write_bytes(dtb)

            meta_path = out_dir / f"dtb_{idx:08x}.meta.txt"
            meta = [
                f"offset=0x{idx:x}",
                f"size={totalsize}",
                f"sha256={sha}",
            ]
            if hits:
                meta.append(f"filter_hits={','.join(hits)}")
            if ref_hash and sha == ref_hash:
                meta.append("matches_reference=yes")
            meta_path.write_text("\n".join(meta) + "\n", encoding="ascii")

            dts_path = try_dtc(dtb_path)
            extracted.append((dtb_path, dts_path, sha, hits))

    print(f"Image: {img}")
    print(f"Extracted: {len(extracted)} DTB(s) into {out_dir}")
    if ref_hash:
        print(f"Reference DTB sha256: {ref_hash}")
    for dtb_path, dts_path, sha, hits in extracted:
        line = f"- {dtb_path.name} sha256={sha}"
        if hits:
            line += f" hits={','.join(hits)}"
        if ref_hash and sha == ref_hash:
            line += " matches_reference=yes"
        if dts_path:
            line += f" dts={dts_path.name}"
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
