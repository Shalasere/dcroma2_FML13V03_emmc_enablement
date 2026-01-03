# Hardware capture

Hardware captures are committed under `captures/` so changes can be audited against real board logs.

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
- Keep UART logs locally; the repo `.gitignore` skips `captures/` and `.log` files to avoid churn. If you need to share a snippet, drop it under `captures/<distro>/.../` temporarily or summarize it in a README.
- If you use a terminal logger, note baudrate and settings in a `uart.meta` file next to the log.
