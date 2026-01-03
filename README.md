# dcroma2_FML13V03_emmc_enablement

Bring-up harness for DC-ROMA 2 (FML13V03) eMMC enablement with a reproducible, reviewable workflow.

Goals
- Enable stable eMMC detection in U-Boot and Linux.
- Keep the control plane in SPI (U-Boot + environment) while booting from SD/eMMC/NVMe.
- Use UART as the authoritative log path.
- Make changes as patch series against a known vendor baseline.
- For simple SD→eMMC boot testing, keep kernel/initrd on SD and point root= to eMMC using `scripts/setup_emmc_extlinux.sh`.

Current field status (2026-01-02)
- Vendor Debian image 15307 with DTB patched (`/soc/mmc@50450000` set to `okay`) now enumerates the eMMC reliably.
- With SD inserted, U-Boot’s extlinux menu includes an `emmc` entry that boots `root=LABEL=root-emmc`; default is still the SD entry.
- eMMC root (`root-emmc`) has UART login enabled via `serial-getty@ttyS0`; SPI env readout via `fw_printenv` is still failing with the current offsets.
- See `docs/08-boot-to-emmc.md` for the exact boot/runbook with SD inserted.

Quick start (high level)
1) Capture a baseline on the board: `scripts/capture_hw.sh` (see `docs/02-capture.md`).
2) Record vendor image metadata: `scripts/record_vendor_image.sh`.
3) Apply patches (if you have sources): `scripts/apply_patches.sh`.
4) Build artifacts (if you have sources): `scripts/build.sh`.
5) Test via closed-loop netboot or boot-partition swap (see `docs/01-closed-loop.md`).

Repo layout
- `captures/` hardware capture logs and DT/config snapshots (committed for audit).
- `docs/` workflow, capture, build, and troubleshooting docs.
- `scripts/` bash tooling for capture/build/packaging.
- `patches/` patch series for Linux and U-Boot.
- `configs/` defconfig fragments and notes.
- `dts/` DTS/DTSI or overlay sources used by patches.
- `vendor/` vendor image metadata and audit notes.

Start with the docs in `docs/00-overview.md`.
