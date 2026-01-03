# Troubleshooting

No eMMC in U-Boot
- Check physical seating and known-good module.
- Confirm the eMMC controller node exists in the board DT.
- Verify clocks/resets and pinmux for the eMMC controller.

U-Boot sees eMMC, Linux does not
- Confirm the DT node is `status = "okay"` in the DTB Linux boots.
- Verify the compatible string maps to a built-in driver.
- Ensure required regulators are described and enabled.

Probe timeouts or I/O errors
- Verify vmmc/vqmmc supplies and signaling voltage.
- Check bus width and HS200/HS400 modes.
- Lower max-frequency temporarily to confirm signal integrity.

Device numbering confusion
- Remove SD during early bring-up to reduce mmc0/mmc1 ambiguity.
- Use by-path or UUIDs instead of hard-coding mmc indices.
