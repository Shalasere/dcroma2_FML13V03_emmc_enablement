# Repeatable finish line (Mode C)

The remaining work is to prove the boot source, remove GUID ambiguity, then optionally persist the boot order.

Phase 0 - Capture a final state snapshot
Run this from the running system (Mode B or Mode C):
```
./scripts/verify_boot_state.sh
cat /proc/cmdline
findmnt -no TARGET,SOURCE,FSTYPE / /boot
lsblk -e7 -o NAME,SIZE,LABEL,UUID,PARTUUID,MOUNTPOINTS
```
Save the output locally (no need to commit).

Phase 1 - Prove Mode C boot source (not just runtime mounts)
Pick one:

Option A (strongest): boot once with SD removed
1) Power off
2) Remove SD
3) Boot and capture UART log
If it boots, this proves U-Boot is using eMMC for boot assets.

Option B (still good): one-shot sysboot from eMMC
At the U-Boot prompt:
```
mmc list
mmc dev <N>
mmc rescan
ext4ls mmc <N>:1 /extlinux/extlinux.conf
sysboot mmc <N>:1 any ${scriptaddr} /extlinux/extlinux.conf
```
If it boots into the normal OS with / and /boot on eMMC, U-Boot can boot from eMMC without SPI env changes.

Phase 2 - Fix PARTUUID / GPT GUID collisions
If SD and eMMC were cloned, their GUIDs and PARTUUIDs will match, which breaks PARTUUID-based boot when both are inserted.

Check:
```
lsblk -e7 -o NAME,LABEL,PARTUUID /dev/mmcblk0 /dev/mmcblk1
```

If there are duplicates, regenerate GUIDs on the device you can safely invalidate (usually SD):
```
sudo sgdisk -G /dev/mmcblk1
```
Then re-check uniqueness and update any PARTUUID references as needed.

Phase 3 - Ensure eMMC boot assets are self-contained
Stage boot assets onto eMMC (Mode C prep):
```
sudo ./scripts/install_emmc_boot_assets.sh \
  --boot-label boot-emmc \
  --root-label root-emmc \
  --entry-label emmc \
  --default
```
Confirm /boot uses the eMMC boot label:
```
findmnt -no TARGET,SOURCE,FSTYPE /boot
```
If needed, edit /etc/fstab so /boot is LABEL=boot-emmc, then reboot and re-check.

If eMMC userspace diverged from SD
- If UART login is still missing or systemd behavior differs, a full userspace align from the SD root is a reliable reset:
  ```
  sudo mount -L root-emmc /mnt/emmc
  sudo rsync -aHAXx --numeric-ids --delete --info=progress2 / /mnt/emmc/
  sudo umount /mnt/emmc
  ```
  Then fix `/mnt/emmc/etc/fstab` (labels) and clear `machine-id` if you want a unique identity.

Phase 4 (optional) - Persist boot order in SPI env
Only do this after offsets are proven:
1) Collect U-Boot evidence (printenv, env info).
2) Collect Linux evidence (/proc/mtd, mtdinfo, fw_printenv output).
3) Update /etc/fw_env.config and verify fw_printenv works reliably.
4) Then update boot_targets / bootcmd and saveenv.

Definition of done
- Boots with SD removed into eMMC root.
- /boot is on the eMMC boot partition.
- extlinux on eMMC is actually used (proved by UART log and/or SD-less boot).
- PARTUUIDs are unique across inserted media.
- Optional: SPI env is readable and boot order is persistent.

Alternative to SPI env while SD is inserted
- If you want deterministic eMMC boot without touching SPI env, keep SD non-bootable by renaming its
  `/boot/extlinux` directory (see `docs/10-boot-modes.md`).

Optional (session only) - keep the system awake while working
If autosuspend is enabled and you want to keep the system alive for a session:
```
sudo systemd-inhibit --what=idle --mode=block --why="UART session" bash
```
