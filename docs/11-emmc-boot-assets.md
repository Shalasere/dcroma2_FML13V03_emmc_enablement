# Stage eMMC boot assets (Mode C prep)

This runbook makes the eMMC boot partition self-contained so U-Boot can boot from eMMC without SD.

Prereqs
- The DTB patch enabling `/soc/mmc@50450000` is applied (Linux sees eMMC).
- eMMC partitions are labeled: `boot-emmc` and `root-emmc`.
- You can access the system via UART.
- Optional: confirm U-Boot can see eMMC (see `docs/09-uboot-oneshots.md`).

One-command (recommended)
```
sudo ./scripts/install_emmc_boot_assets.sh \
  --boot-label boot-emmc \
  --root-label root-emmc \
  --entry-label emmc \
  --default
```

What this does
- Mounts the eMMC boot partition.
- Copies the current `/boot` contents onto it.
- Writes/updates an extlinux `emmc` stanza with `root=PARTUUID=<root-emmc>`.
- Optionally sets `DEFAULT emmc` for the eMMC extlinux file.

Drift warning (Mode B -> Mode C)
- While you are still booting kernel/initrd from SD (Mode B), any kernel/initramfs update will land
  on the SD `/boot`. If you intend to boot from eMMC later (Mode C), re-run this staging step after
  such updates so the eMMC `/boot` stays in sync.

Manual steps (if you prefer)
```
sudo mkdir -p /mnt/emmc-boot
sudo mount /dev/disk/by-label/boot-emmc /mnt/emmc-boot
sudo rsync -a --delete /boot/. /mnt/emmc-boot/
sudo ./scripts/setup_emmc_extlinux.sh \
  --extlinux /mnt/emmc-boot/extlinux/extlinux.conf \
  --root-label root-emmc \
  --entry-label emmc \
  --default
sync
sudo umount /mnt/emmc-boot
```

Switch /boot ownership for Mode C
- When you intend to boot from eMMC, update the eMMC root `/etc/fstab` so `/boot` mounts `LABEL=boot-emmc`.
  ```
  sudo mount /dev/disk/by-label/root-emmc /mnt/emmc
  sudo sed -n '1,200p' /mnt/emmc/etc/fstab
  # edit so /boot -> LABEL=boot-emmc
  sudo umount /mnt/emmc
  ```

Validate without SPI writes
- Use a one-shot sysboot from U-Boot:
  ```
  mmc dev 0
  mmc rescan
  ext4ls mmc 0:1 /extlinux/extlinux.conf
  sysboot mmc 0:1 any ${scriptaddr} /extlinux/extlinux.conf
  ```
- If that boots, Mode C is viable once SPI env offsets are known (for persistent boot order).
