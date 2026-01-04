# Tooling outline

Host requirements
- git
- bash
- make
- device-tree-compiler (dtc)
- U-Boot tools (mkimage)
- RISC-V cross-compiler (e.g. riscv64-unknown-linux-gnu-*)

Optional but useful
- ccache
- python3 (some build helpers)
- bc, bison, flex, openssl headers

Script expectations
- Vendor image metadata lives in `vendor/`.
- Source trees (if available) are cloned into `sources/`.
- Build outputs go to `out/` and packaging to `dist/`.

Scripts
- `scripts/record_vendor_image.sh` captures vendor image metadata for audit.
- `scripts/extract_dtbs_from_image.py` scans a vendor image for DTBs and extracts candidates.
- `scripts/dtb_inspect.py` inspects a DTB for model and MMC node status.
- `scripts/patch_dtb_status.py` patches a DTB status property in a raw image.
- `scripts/auto_patch_vendor_image.py` auto-finds the DTB in an image and patches status in-place.
- `scripts/apply_patches.sh` applies patch series in lexical order.
- `scripts/build_*.sh` builds U-Boot, Linux, and optional OpenSBI.
- `scripts/pack_release.sh` assembles a release bundle with metadata.
- `scripts/setup_emmc_extlinux.sh` adds an extlinux entry for eMMC root using PARTUUID.
- `scripts/install_emmc_boot_assets.sh` stages boot assets onto the eMMC boot partition.
- `scripts/verify_boot_state.sh` prints boot/root/label sanity checks.
