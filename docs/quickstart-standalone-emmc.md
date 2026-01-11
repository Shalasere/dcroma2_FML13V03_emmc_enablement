# Standalone eMMC Quickstart (Mode C)

This path makes the eMMC bootable without SD using the existing scripts.

Assumptions
- Patched vendor image where `/soc/mmc@50450000/status` is `"okay"` (see `docs/07-patch-vendor-image.md`).
- You can boot the board from SD at least once.
- Vendor image layout is still p1 boot, p3 root (confirm with `lsblk`).
- You can identify which mmcblk device is SD vs eMMC.

Step 1: Patch the vendor image (host)
- Copy the image first (patching scripts modify the image in place).
  ```
  cp sdcard.img sdcard.emmcfix.img
  ```
- Patch the copy:
  ```
  python scripts/auto_patch_vendor_image.py --image "/path/to/sdcard.emmcfix.img" --path /soc/mmc@50450000 --status okay
  ```
- Flash the patched image to SD and boot the board from SD.

Step 2: Identify SD vs eMMC devices
```
lsblk -e7 -o NAME,SIZE,MODEL,LABEL,PARTUUID,MOUNTPOINTS
```
Do not assume `mmcblk0` vs `mmcblk1` without confirming the model/size/mountpoints.

Step 3: Clone SD -> eMMC (destructive)
Use the defensive flasher on the running SD system:
```
sudo ./scripts/flash_emmc.sh --source /dev/mmcblk1 --target /dev/mmcblk0 --allow-mounted-source
```
Replace the device names with your confirmed SD (source) and eMMC (target).

Step 4: Relabel the eMMC partitions
```
sudo e2label /dev/mmcblk0p1 boot-emmc
sudo e2label /dev/mmcblk0p3 root-emmc
```

Step 5: Stage eMMC boot assets and set default entry
```
sudo ./scripts/install_emmc_boot_assets.sh \
  --boot-label boot-emmc \
  --root-label root-emmc \
  --entry-label emmc \
  --default
```

Step 6: Make the eMMC root mount its own /boot
```
sudo mount -L root-emmc /mnt/emmc
sudo $EDITOR /mnt/emmc/etc/fstab
# ensure /boot points to LABEL=boot-emmc (or a unique UUID/PARTUUID)
sudo umount /mnt/emmc
```

Step 7: Enable serial login on the eMMC install (recommended)
```
sudo mount -L root-emmc /mnt/emmc
sudo systemctl --root=/mnt/emmc enable serial-getty@ttyS0.service
sudo umount /mnt/emmc
```

Step 8: Boot from eMMC
Power off, remove SD, then boot. Verify:
```
./scripts/verify_boot_state.sh
```

Optional: If you plan to re-insert the SD, avoid PARTUUID collisions by regenerating the SD GUIDs:
```
sudo sgdisk -G /dev/mmcblk1
```
Then update any PARTUUID references in extlinux or fstab as needed.

If something fails, see:
- `docs/06-troubleshooting.md`
- `docs/11-emmc-boot-assets.md`
- `docs/13-repeatable.md`
