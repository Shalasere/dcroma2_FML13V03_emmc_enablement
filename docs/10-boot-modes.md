# Boot modes matrix

This page defines the supported boot modes and the `/boot` ownership rule for each. The goal is to
avoid silent kernel/initramfs drift when SD and eMMC are both present.

Legend
- "Boot assets" = kernel, initrd, DTB/overlays read by U-Boot (extlinux).
- "Root" = Linux root filesystem (`/`).

Modes
```
Mode | Boot assets (U-Boot reads) | Linux root | /boot should mount | Notes
-----|---------------------------|-----------|--------------------|-----------------------------
A    | SD boot partition         | SD root   | SD boot partition  | Factory baseline
B    | SD boot partition         | eMMC root | SD boot partition  | Current bring-up mode
C    | eMMC boot partition       | eMMC root | eMMC boot partition| SD optional / removed
```

Ownership rules (do not mix)
- Mode B: `/boot` must be the SD boot partition. If `/boot` is mounted from eMMC while U-Boot still
  reads extlinux + kernel from SD, kernel updates go to the wrong place and the next boot uses old
  assets.
- Mode C: `/boot` must be the eMMC boot partition. Once U-Boot is booting from eMMC, stop mounting
  `/boot` from SD.

Keeping SD inserted but non-bootable (recommended for Mode C)
U-Boot's default `boot_targets` prefers SD over eMMC, so with SD inserted it will usually boot SD
unless SD is made non-bootable. The reversible way is to rename SD's extlinux directory:
```
sudo mount -L boot-15307 /mnt/sdboot
sudo mv /mnt/sdboot/extlinux /mnt/sdboot/extlinux.SD_DISABLED.$(date +%s)
sudo sync
sudo umount /mnt/sdboot
```
To restore SD boot later:
```
sudo mount -L boot-15307 /mnt/sdboot
sudo mv /mnt/sdboot/extlinux.SD_DISABLED.* /mnt/sdboot/extlinux
sudo sync
sudo umount /mnt/sdboot
```

Quick verification
```
cat /proc/cmdline
findmnt -no SOURCE / /boot
lsblk -o NAME,SIZE,LABEL,MOUNTPOINTS
```
Or run:
```
./scripts/verify_boot_state.sh
```

Interpretation
- Mode B looks like:
  - `/proc/cmdline` root=LABEL=root-emmc (or PARTUUID of eMMC root)
  - `/` -> root-emmc
  - `/boot` -> boot-15307 (SD)
- Mode C looks like:
  - `/proc/cmdline` root=LABEL=root-emmc (or PARTUUID of eMMC root)
  - `/` -> root-emmc
  - `/boot` -> boot-emmc (eMMC)
