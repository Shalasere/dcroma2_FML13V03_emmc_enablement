# SPI env discovery (read-only)

Goal: identify the correct SPI environment offsets without writing anything to SPI. Until this is
confirmed, avoid `saveenv` and avoid writes to `/dev/mtd*`.

Why this matters
- U-Boot boot order and distroboot targets live in SPI env.
- Wrong offsets can corrupt SPI contents, which can break boot.

Phase 1: U-Boot evidence (UART, read-only)
```
printenv
env info        # if supported
help env
```
Record the output. If `printenv` works in U-Boot but `fw_printenv` fails in Linux, the offsets in
`/etc/fw_env.config` are likely wrong.

Phase 2: Linux evidence (read-only)
```
cat /proc/mtd
mtdinfo /dev/mtd0
mtdinfo /dev/mtd1
fw_printenv -V
fw_printenv
```
If `fw_printenv` fails, keep the error output for the record.

Optional: cautious SPI reads
- Some systems react poorly to raw reads on `/dev/mtd0` (we observed kernel warnings before).
- If you choose to read, do small, bounded reads and watch `dmesg` for errors.
Example (adjust offset/size as needed):
```
sudo dd if=/dev/mtd0 of=/tmp/mtd0_env.bin bs=4096 skip=$((0x4a0000/4096)) count=4
hexdump -C /tmp/mtd0_env.bin | head
```
If you see kernel warnings or faults, stop and avoid further raw reads.

Phase 3: Map candidate offsets (analysis)
- Common layouts use two redundant env sectors of size 0x80000 or 0x10000, aligned to erase size.
- Search read-only dumps for ASCII keys like `bootcmd=`, `boot_targets=`, `ethaddr=`.
- Once a candidate offset is found, update `/etc/fw_env.config` and re-test `fw_printenv` (still read-only).

Do not write
- Do not run `saveenv` until `fw_printenv` can read reliably with the final offsets.
