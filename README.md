# dcroma2_FML13V03_emmc_enablement

Bring-up harness for DC-ROMA 2 (FML13V03) eMMC enablement with a reproducible, reviewable workflow.

Goals
- Enable stable eMMC detection in U-Boot and Linux.
- Keep the control plane in SPI (U-Boot + environment) while booting from SD/eMMC/NVMe.
- Use UART as the authoritative log path.
- Make changes as patch series against a known vendor baseline.
- For simple SD->eMMC boot testing, keep kernel/initrd on SD and point root= to eMMC using `scripts/setup_emmc_extlinux.sh`.

Current field status (2026-01-10)
- Vendor Debian image 15307 with DTB patched (`/soc/mmc@50450000` set to `okay`) now enumerates the eMMC reliably.
- U-Boot is in SPI (`sf probe` works). Default `boot_targets` is `usb mmc1 mmc0 nvme`, so SD wins if it is bootable.
- eMMC boots with SD inserted by keeping SD non-bootable (renamed `/boot/extlinux` on SD) and using eMMC `/boot` + `root=PARTUUID=<emmc-root-partuuid>`.
- UART login on eMMC is stable after aligning eMMC userspace with SD via `rsync -aHAXx --numeric-ids --delete / /mnt/emmc/` (see `docs/06-troubleshooting.md`).
- SPI env readout via `fw_printenv` is still failing with the current offsets.
- See `docs/08-boot-to-emmc.md` for the exact runbook with SD inserted.

Quick start (high level)
Fast path (vendor image, SD inserted, eMMC root):
0) Standalone eMMC quickstart (no Mode B): `docs/quickstart-standalone-emmc.md`.
1) Patch the vendor image DTB (host): `docs/07-patch-vendor-image.md`.
2) Write the patched image to SD and eMMC, label partitions uniquely.
3) Add the extlinux `emmc` entry on SD: `sudo ./scripts/setup_emmc_extlinux.sh`.
4) Boot, select `emmc`, verify with `./scripts/verify_boot_state.sh`.

Longer-term (source-based):
1) Capture a baseline on the board: `scripts/capture_hw.sh` (see `docs/02-capture.md`).
2) Record vendor image metadata: `scripts/record_vendor_image.sh`.
3) Apply patches (if you have sources): `scripts/apply_patches.sh`.
4) Build artifacts (if you have sources): `scripts/build.sh`.
5) Test via closed-loop netboot or boot-partition swap (see `docs/01-closed-loop.md`).

Repo layout
- `captures/` hardware capture logs and DT/config snapshots (gitignored by default to avoid churn).
- `docs/` workflow, capture, build, and troubleshooting docs.
- `scripts/` bash tooling for capture/build/packaging.
- `vendor/` vendor image metadata and audit notes.

Note: When sharing a zip/tarball, prefer `git archive` or remove `.git/` so reviewers do not receive repo history.

Note: `patches/`, `configs/`, and `dts/` are intended future additions once the bring-up work moves from
"vendor image DTB patching" into a source-based patch series.

Start with the docs in `docs/00-overview.md`.
Key deep-dives:
- `docs/10-boot-modes.md` for the boot modes matrix and /boot ownership rules.
- `docs/11-emmc-boot-assets.md` for staging eMMC boot assets (Mode C).
- `docs/12-spi-env-discovery.md` for read-only SPI env discovery steps.
- `docs/13-repeatable.md` for the "prove boot source + remove GUID ambiguity + persist boot order" finish line.
