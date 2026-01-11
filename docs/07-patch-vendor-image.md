# Patch a vendor image DTB

This process patches the DTB inside a vendor image so the eMMC controller is enabled.
The patching scripts modify the image file in place, so make a copy first.

Example (Linux/macOS):
```
cp sdcard.img sdcard.emmcfix.img
```

Example (Windows PowerShell):
```
Copy-Item sdcard.img sdcard.emmcfix.img
```

Prereqs
- Vendor image file (e.g. `sdcard.img`)
- Python 3 on the host

Optional (recommended): auto-patch without manual offset selection
```
python scripts/auto_patch_vendor_image.py --image "/path/to/sdcard.emmcfix.img" --path /soc/mmc@50450000 --status okay \
  --backup-dtb vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_auto.orig.dtb \
  --out-dtb vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_auto.patched.dtb
```
Note: `dtbs_all/` is ignored by git and is meant for local, temporary artifacts. Use any local path you prefer.

This script scans DTB blobs in the image via `mmap`, filters by DTB `model` containing `FML13V03`,
and patches the first matching `/soc/mmc@50450000/status` it finds.

If you prefer the manual/explicit offset workflow (useful for audit), follow the steps below.

Step 1: Extract DTBs and find the FML13V03 blob
```
python scripts/extract_dtbs_from_image.py --image "/path/to/sdcard.img" --out "vendor/debian/15307-debian14-desktop-sdcard/dtbs_all" --no-filter
```

Identify the FML13V03 DTB and its offset (filename encodes offset).
```
python scripts/dtb_inspect.py vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_0817d000.dtb --model --mmc
```

The filename `dtb_0817d000.dtb` means the DTB starts at offset `0x0817d000` in the image.

Step 2: Patch the DTB in the image
Linux/macOS:
```
python scripts/patch_dtb_status.py \
  --image "/path/to/sdcard.emmcfix.img" \
  --offset 0x0817d000 \
  --path /soc/mmc@50450000 \
  --status okay \
  --backup vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_0817d000.orig.dtb \
  --out-dtb vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_0817d000.patched.dtb
```

Windows (cmd.exe caret continuation):
```
python scripts/patch_dtb_status.py ^
  --image "C:\\path\\to\\sdcard.emmcfix.img" ^
  --offset 0x0817d000 ^
  --path /soc/mmc@50450000 ^
  --status okay ^
  --backup vendor\\debian\\15307-debian14-desktop-sdcard\\dtbs_all\\dtb_0817d000.orig.dtb ^
  --out-dtb vendor\\debian\\15307-debian14-desktop-sdcard\\dtbs_all\\dtb_0817d000.patched.dtb
```

Step 3: Verify the patched DTB
```
python scripts/dtb_inspect.py vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_0817d000.patched.dtb --model --mmc
```

Expected: `/soc/mmc@50450000 status=okay`.

Post-patch boot/run (with SD inserted)
1) Write the patched image to SD and to eMMC (e.g., `dd` from the SD booted system to `/dev/mmcblk0`).
2) After booting the patched SD image, confirm the live DT status:
   ```
   tr -d '\0' </proc/device-tree/soc/mmc@50450000/status; echo
   ```
   Expected: `okay`.
3) Ensure labels are unique: on the eMMC set `boot-emmc` and `root-emmc`:
   ```
   sudo e2label /dev/mmcblk0p1 boot-emmc
   sudo e2label /dev/mmcblk0p3 root-emmc
   ```
   Leave the SD as `boot-15307`/`root-15307` (or similar) so labels don't collide.
4) On the SD boot partition (`/boot` when booted from SD, or mount the SD boot as `/mnt/sdboot`), ensure `extlinux.conf` has an entry like:
   ```
   label emmc
     # NOTE: linux/initrd/fdt* paths should match your existing working `sd` entry.
     # Paths are relative to the boot partition root (do not prefix with /boot).
     linux /vmlinuz-6.6.92-eic7x-2025.07
     initrd /initrd.img-6.6.92-eic7x-2025.07
     fdtdir /dtbs/6.6.92-eic7x-2025.07/
     append root=PARTUUID=<emmc-root-partuuid> console=tty0 console=ttyS0,115200 rootwait rw earlycon selinux=0 LANG=en_US.UTF-8 audit=0
   ```
   Keep the `sd` entry as a fallback. Leave `default sd` for safety or change to `default emmc` once you're confident.
   Find the PARTUUID with:
   ```
   blkid -s PARTUUID -o value /dev/disk/by-label/root-emmc
   ```
5) Boot with the SD inserted and pick the `emmc` menu entry over UART. Verify:
   - `findmnt -no SOURCE /` shows `root-emmc` (eMMC).
   - `findmnt -no SOURCE /boot` shows the **SD boot** label (e.g., `boot-15307`).
     In this phase, `/boot` should stay on SD so kernel/initramfs updates land on the media that
     U-Boot actually reads.
   - `lsblk` shows both SD (`mmcblk1...`) and eMMC (`mmcblk0...`).

Note: reading SPI env via `fw_printenv` is currently failing with the vendor offsets; avoid writes to SPI until the correct layout is confirmed.
