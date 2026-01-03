# Closed-loop development

The fastest loop is to netboot the kernel + DTB from your dev machine while keeping U-Boot and its environment in SPI. This avoids re-imaging SD/eMMC on every iteration.

Recommended loop (netboot)
1) Build kernel `Image` and DTB on your dev machine.
2) Host them in a TFTP directory.
3) Load and boot from U-Boot over UART.

Example U-Boot session (adjust IPs and filenames):
```
setenv ipaddr 192.168.1.50
setenv serverip 192.168.1.2

# load kernel + dtb
tftpboot ${kernel_addr_r} Image
tftpboot ${fdt_addr_r} eic7702-deepcomputing-fml13v03.dtb

# optional initramfs
# tftpboot ${ramdisk_addr_r} initramfs.cpio.gz

# boot (use booti for raw Image; use bootm for uImage)
booti ${kernel_addr_r} - ${fdt_addr_r}
```

Alternate loop (boot-partition swap)
- Keep your OS on SD/NVMe for now.
- Drop a new DTB into `/boot/` and reboot.
- Use this when netboot is not available.

Surgical loop (initramfs-only)
- Boot a tiny initramfs that only probes MMC and dumps logs.
- Useful for isolating power/DT issues without full rootfs.

Notes
- Removing the SD card during bring-up reduces device-number ambiguity.
- Do not change SPI env storage while iterating.
- Always capture UART logs for each test run.
