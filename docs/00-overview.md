# Overview

This repo is a bring-up harness for DC-ROMA 2 (FML13V03) eMMC enablement. It is designed for closed-loop development with UART logs and a stable SPI-resident U-Boot environment.

Workflow summary
1) Capture a baseline from current vendor images.
2) Identify DT and kernel config deltas needed for eMMC.
3) Encode deltas as patches against the vendor baseline (or source tree if available).
4) Build artifacts if you have sources; otherwise test DTB changes directly.
5) Iterate until eMMC enumerates reliably, then package a release bundle.

Current validated state (2026-01-02)
- Baseline: vendor Debian 15307 image with DTB patched to set `/soc/mmc@50450000` to `status = "okay"`.
- Results: Linux now sees the eMMC (mmc host + block device) with SD inserted; UART console available on `ttyS0`.
- Bootflow: extlinux menu (on SD boot media) has `sd`, `emmc`, and `sd-rescue` entries; default remains `sd`. Selecting `emmc` boots `root=PARTUUID=<emmc-root-partuuid>` (preferred; older runs used `root=LABEL=root-emmc`).
- Known gap: `fw_printenv` fails against the current SPI offsets (mtd0/mtd1 @ 0x4a0000); avoid writing to SPI until offsets are confirmed.

Key principles
- Keep SPI as the control plane.
- UART logs are the source of truth.
- Patch series, not forks.
- Everything is reproducible from a recorded vendor baseline.

Next docs
- `docs/01-closed-loop.md`
- `docs/02-capture.md`
- `docs/03-tooling.md`
- `docs/04-build.md`
- `docs/05-testing.md`
- `docs/06-troubleshooting.md`
- `docs/07-patch-vendor-image.md`
- `docs/08-boot-to-emmc.md`
- `docs/09-uboot-oneshots.md`
- `docs/10-boot-modes.md`
- `docs/11-emmc-boot-assets.md`
- `docs/12-spi-env-discovery.md`
- `docs/13-repeatable.md`
