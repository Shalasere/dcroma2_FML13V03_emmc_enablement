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

No UART login on eMMC (boots but no prompt)
- Symptom: systemd debug shows `serial-getty@ttyS0.service` "starting held back" behind `plymouth-quit-wait.service`, and no `login:` ever appears.
- Practical fix that worked: align eMMC userspace to the known-good SD install.
  ```
  sudo mount -L root-emmc /mnt/emmc
  sudo rsync -aHAXx --numeric-ids --delete --info=progress2 / /mnt/emmc/
  sudo umount /mnt/emmc
  ```
  Then fix `/mnt/emmc/etc/fstab` for `root-emmc`/`boot-emmc` and clear `machine-id` if you want a unique identity.
- If you don't want a full rsync, the targeted Plymouth/getty masks still work:
  ```
  sudo mount -L root-emmc /mnt/emmc
  sudo ln -sf /dev/null /mnt/emmc/etc/systemd/system/plymouth-quit-wait.service
  sudo ln -sf /dev/null /mnt/emmc/etc/systemd/system/plymouth-start.service
  sudo ln -sf /dev/null /mnt/emmc/etc/systemd/system/plymouth-read-write.service
  sudo ln -sf /dev/null /mnt/emmc/etc/systemd/system/serial-getty@hvc0.service
  sudo systemctl --root=/mnt/emmc unmask serial-getty@ttyS0.service || true
  sudo systemctl --root=/mnt/emmc enable serial-getty@ttyS0.service
  sudo umount /mnt/emmc
  ```
  Optional belt-and-suspenders: add `plymouth.enable=0 nosplash` to the SD extlinux emmc entry.
