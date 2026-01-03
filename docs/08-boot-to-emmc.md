# Boot to eMMC with SD inserted

This runbook uses the patched vendor Debian 15307 image (DTB with `/soc/mmc@50450000` set to `okay`) and keeps the SD card inserted. U-Boot lives in SPI; UART is the control plane.

Prereqs
- eMMC written with the vendor SD image (patched DTB). SD still has the same image.
- Labels: eMMC `boot-emmc` + `root-emmc`; SD `boot-15307` + `root-15307` (or similar) so labels do not collide.
- UART on `ttyS0` reachable.

Prepare once (from the SD-booted system)
```
# label eMMC partitions uniquely
sudo e2label /dev/mmcblk0p1 boot-emmc
sudo e2label /dev/mmcblk0p3 root-emmc

# ensure serial console inside eMMC root
sudo mkdir -p /mnt/emmc
sudo mount /dev/disk/by-label/root-emmc /mnt/emmc
sudo systemctl --root=/mnt/emmc enable serial-getty@ttyS0.service
sudo systemctl --root=/mnt/emmc is-enabled serial-getty@ttyS0.service
sudo sync
sudo umount /mnt/emmc
```

Extlinux menu (on the SD boot partition)
- File: `/boot/extlinux/extlinux.conf` when booted from SD (or mount the SD boot as `/mnt/sdboot` and edit there).
- Ensure entries:
  ```
  label sd
    append root=/dev/mmcblk0p3 ...        # SD root as fallback

  label emmc
    append root=LABEL=root-emmc ...       # eMMC root

  label sd-rescue
    append root=/dev/mmcblk0p3 ... single
  ```
- Keep `default sd` while experimenting; switch to `default emmc` after confidence.

Boot steps
1) Power on with SD inserted; watch UART.
2) In the extlinux menu, choose `emmc`.
3) Verify after boot:
   - `findmnt -no SOURCE /` → `root-emmc`
   - `findmnt -no SOURCE /boot` → `boot-emmc`
   - `lsblk` shows both SD and eMMC.

If you drop to initramfs because `root-15307` is missing
- The SD entry was used. Reboot and pick `emmc`, or change `default` in `extlinux.conf` to `emmc`.
- If labels are wrong, relabel from initramfs:
  ```
  mkdir -p /newroot
  mount /dev/mmcblk0p3 /newroot
  export LD_LIBRARY_PATH=/newroot/lib/riscv64-linux-gnu:/newroot/usr/lib/riscv64-linux-gnu:/newroot/lib:/newroot/usr/lib
  /newroot/sbin/e2label /dev/mmcblk0p3 root-emmc
  /newroot/sbin/e2label /dev/mmcblk0p1 boot-emmc
  sync
  reboot -f
  ```

SPI env note
- `fw_printenv` currently fails with the vendor offsets (mtd0/mtd1 @ 0x4a0000). Avoid writes to SPI until the correct layout is identified.
