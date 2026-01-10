# Boot to eMMC with SD inserted

This runbook uses the patched vendor Debian 15307 image (DTB with `/soc/mmc@50450000` set to `okay`) and keeps the SD card inserted. U-Boot lives in SPI; UART is the control plane.
This corresponds to Mode B in `docs/10-boot-modes.md`.

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
    append root=LABEL=root-15307 ...      # SD root as fallback (use your actual SD root label)

  label emmc
    append root=PARTUUID=<emmc-root-partuuid> ...  # eMMC root (preferred)

  label sd-rescue
    append root=LABEL=root-15307 ... single
  ```
- Keep `default sd` while experimenting; switch to `default emmc` after confidence.
  - Find the PARTUUID with:
    ```
    blkid -s PARTUUID -o value /dev/disk/by-label/root-emmc
    ```

Tip: you can generate/update the `emmc` entry by copying your current default stanza and rewriting
`root=` via:
```
sudo ./scripts/setup_emmc_extlinux.sh --root-label root-emmc --entry-label emmc
```
This uses `root=PARTUUID=...` to avoid label collisions.

Boot steps
1) Power on with SD inserted; watch UART.
2) In the extlinux menu, choose `emmc`.
3) Verify after boot:
   - `findmnt -no SOURCE /` -> `root-emmc`
   - `findmnt -no SOURCE /boot` -> the **SD boot** label (e.g., `boot-15307`)
   - `lsblk` shows both SD and eMMC.
   - Optional: run `./scripts/verify_boot_state.sh` to catch common label/mount issues.

If eMMC boots but you still get no UART login
- The quickest fix that resolved this on the board was to align eMMC userspace with the known-good SD install:
  ```
  sudo mount -L root-emmc /mnt/emmc
  sudo rsync -aHAXx --numeric-ids --delete --info=progress2 / /mnt/emmc/
  sudo umount /mnt/emmc
  ```
- After rsync, fix `/mnt/emmc/etc/fstab` for `root-emmc`/`boot-emmc` and clear `machine-id` if you want a unique identity.

Avoid the /boot trap in this phase
- In this runbook, U-Boot is reading `/boot/extlinux/extlinux.conf` and kernel/initrd from the SD.
  If the eMMC root's `/etc/fstab` mounts `/boot` from eMMC (`boot-emmc`), then future kernel updates
  inside the eMMC root will update the *wrong* `/boot` (the eMMC one), and the next boot may silently
  keep using the older SD kernel/initrd.
- Recommended: in the eMMC root, ensure `/boot` mounts the SD boot label while you are still
  booting extlinux from SD.
  Example (edit inside the eMMC root):
  
  1) `sudo mount /dev/disk/by-label/root-emmc /mnt/emmc`
  2) Edit `/mnt/emmc/etc/fstab` so `/boot` uses `LABEL=boot-15307` (or your SD boot label)
  3) `sudo umount /mnt/emmc`

If you drop to initramfs because `root-15307` is missing
- The SD entry was used. Reboot and pick `emmc`, or change `default` in `extlinux.conf` to `emmc`.
- If labels are wrong, relabel from initramfs:
  ```
  # Prefer by-label if present (more robust than /dev/mmcblk* numbering)
  mkdir -p /newroot
  mount /dev/disk/by-label/root-emmc /newroot || mount /dev/mmcblk0p3 /newroot
  export LD_LIBRARY_PATH=/newroot/lib/riscv64-linux-gnu:/newroot/usr/lib/riscv64-linux-gnu:/newroot/lib:/newroot/usr/lib
  /newroot/sbin/e2label /dev/mmcblk0p3 root-emmc
  /newroot/sbin/e2label /dev/mmcblk0p1 boot-emmc
  sync
  reboot -f
  ```

SPI env note
- `fw_printenv` currently fails with the vendor offsets (mtd0/mtd1 @ 0x4a0000). Avoid writes to SPI until the correct layout is identified.

When you want eMMC to win while SD stays inserted
- U-Boot prefers SD by default (`boot_targets=usb mmc1 mmc0 nvme`).
- To keep SD inserted but force eMMC boot, disable SD's extlinux directory as described in
  `docs/10-boot-modes.md` (reversible).
