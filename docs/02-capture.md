# Hardware capture

Hardware captures are written under `captures/` for local debugging. By default the repo ignores
`captures/` to avoid constant churn from timestamped logs.

What to capture
- UART boot log for each test run.
- Kernel logs for MMC bring-up.
- Live DTB and decompiled DTS.
- Kernel config (if `config.gz` is enabled).
- Device enumeration (`mmc_host`, `lsblk`).

Run the capture script on the board
```
cd /path/to/repo
sudo ./scripts/capture_hw.sh --distro debian --label deb14-15307
```

Record vendor image metadata (run on your host)
```
./scripts/record_vendor_image.sh --distro debian --image /path/to/vendor.img --label deb14-15307
```

This creates a timestamped folder under `captures/<distro>/` with:
- `uname.txt`
- `cmdline.txt`
- `mmc_host.txt`
- `lsblk.txt`
- `dmesg_mmc.txt`
- `config_mmc.txt`
- `live.dtb`
- `live.dts` (if `dtc` is available)

UART logs
- Keep UART logs locally.
- If you need to share evidence, copy the relevant files into a new, explicitly versioned folder under
  `vendor/<distro>/.../` or attach them to an issue/PR. (Avoid committing raw, high-volume logs.)
- If you use a terminal logger, note baudrate and settings in a `uart.meta` file next to the log.
