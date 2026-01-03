# Testing

U-Boot checks
- `mmc list` should show the eMMC controller.
- `mmc dev 0` (or `mmc dev 1` if SD inserted) should succeed.
- `mmc info` should report vendor, capacity, and mode.

Linux checks
- `/sys/class/mmc_host` should show more than `mmc0` when SD is present.
- `dmesg | grep -i -E 'mmc|sdhci|dwc|dwmshc|emmc'` should show probe + card init.
- `lsblk` should show `/dev/mmcblk*` for the eMMC.

Success criteria
- eMMC enumerates on every boot.
- No intermittent timeouts or CRC errors under repeated read/write.
- U-Boot env remains in SPI, and boot targets still include SD/eMMC/NVMe.
