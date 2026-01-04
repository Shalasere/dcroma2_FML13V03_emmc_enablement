# U-Boot one-shots (no SPI writes)

This page is intentionally **read-only**: these commands do not write SPI env. They are useful when
`fw_printenv` offsets are unknown and you want to avoid `saveenv`.

## 1) Check whether U-Boot sees the eMMC

At the UART prompt:
Note: `mmc dev 0` is just an example. Use `mmc list` to identify which mmc index is eMMC vs SD on your board.
```
mmc list
mmc dev 0
mmc rescan
mmc info
part list mmc 0
```

Repeat for `mmc dev 1` if needed.

If you do not see an eMMC device here, note that **Linux DTB patching does not change U-Boot's DTB**.
In that case, "root-on-eMMC with kernel-on-SD" can still work (because U-Boot does not need to see eMMC),
but full "boot kernel/initrd from eMMC" cannot.

## 2) One-shot boot extlinux from a specific MMC device

If your U-Boot has `sysboot` (check via `help sysboot`), you can boot an extlinux config without
changing SPI env:
```
# Example: boot extlinux from mmc0 partition 1
mmc dev 0
mmc rescan
sysboot mmc 0:1 any ${scriptaddr} /extlinux/extlinux.conf
```

Notes:
- This boots the **DEFAULT** label in that extlinux file.
- This is a clean way to test an eMMC-resident `/extlinux/extlinux.conf` without changing `bootcmd`.

## 3) Safe pattern for "eMMC-first" testing

If (and only if) U-Boot can see the eMMC, you can stage an eMMC boot partition with:
- `/extlinux/extlinux.conf`
- kernel + initrd files referenced by that config
- the DTB referenced by that config

Then do a one-shot `sysboot mmc 0:1 ...` as above. Once proven, the next step is determining safe
SPI env offsets so `boot_targets` / `bootcmd` can be updated persistently.

## 4) SPI env caution

Do not run `saveenv` until you have a confirmed SPI env layout and `fw_printenv` works reliably in Linux.
