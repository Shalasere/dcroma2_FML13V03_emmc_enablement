# Patch a vendor image DTB

This process patches the DTB inside a vendor image so the eMMC controller is enabled.

Prereqs
- Vendor image file (e.g. `sdcard.img`)
- Python 3 on the host

Step 1: Extract DTBs and find the FML13V03 blob
```
python scripts/extract_dtbs_from_image.py --image "G:\Downloads\15307-debian14-desktop-sdcard\sdcard.img" --out "vendor/debian/15307-debian14-desktop-sdcard/dtbs_all" --no-filter
```

Identify the FML13V03 DTB and its offset (filename encodes offset).
```
python scripts/dtb_inspect.py vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_0817d000.dtb --model --mmc
```

The filename `dtb_0817d000.dtb` means the DTB starts at offset `0x0817d000` in the image.

Step 2: Patch the DTB in the image
```
python scripts/patch_dtb_status.py ^
  --image "G:\Downloads\15307-debian14-desktop-sdcard\sdcard.img" ^
  --offset 0x0817d000 ^
  --path /soc/mmc@50450000 ^
  --status okay ^
  --backup vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_0817d000.orig.dtb ^
  --out-dtb vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_0817d000.patched.dtb
```

Step 3: Verify the patched DTB
```
python scripts/dtb_inspect.py vendor/debian/15307-debian14-desktop-sdcard/dtbs_all/dtb_0817d000.patched.dtb --model --mmc
```

Expected: `/soc/mmc@50450000 status=okay`.

Post-patch boot/run (with SD inserted)
1) Write the patched image to SD and to eMMC (e.g., `dd` from the SD booted system to `/dev/mmcblk0`).
2) Ensure labels are unique: on the eMMC set `boot-emmc` and `root-emmc`:
   ```
   sudo e2label /dev/mmcblk0p1 boot-emmc
   sudo e2label /dev/mmcblk0p3 root-emmc
   ```
   Leave the SD as `boot-15307`/`root-15307` (or similar) so labels don’t collide.
3) On the SD boot partition (`/boot` when booted from SD, or mount the SD boot as `/mnt/sdboot`), ensure `extlinux.conf` has an entry like:
   ```
   label emmc
     linux /vmlinuz-6.6.92-eic7x-2025.07
     initrd /initrd.img-6.6.92-eic7x-2025.07
     fdtdir /dtbs/6.6.92-eic7x-2025.07/
     fdoverlays /emmc-enable.dtbo
     append root=LABEL=root-emmc console=tty0 console=ttyS0,115200 rootwait rw earlycon selinux=0 LANG=en_US.UTF-8 audit=0
   ```
   Keep the `sd` entry as a fallback. Leave `default sd` for safety or change to `default emmc` once you’re confident.
4) Boot with the SD inserted and pick the `emmc` menu entry over UART. Verify:
   - `findmnt -no SOURCE /` shows `root-emmc` (eMMC).
   - `findmnt -no SOURCE /boot` shows `boot-emmc`.
   - `lsblk` shows both SD (`mmcblk1…`) and eMMC (`mmcblk0…`).

Note: reading SPI env via `fw_printenv` is currently failing with the vendor offsets; avoid writes to SPI until the correct layout is confirmed.
