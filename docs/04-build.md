# Build

This repo builds from source trees if you have them available and applies patch series.
Place source trees under `sources/` (e.g., `sources/linux`, `sources/u-boot`).

Environment variables
- `CROSS_COMPILE` (required for U-Boot and Linux, e.g. `riscv64-unknown-linux-gnu-`)
- `JOBS` (optional, defaults to number of cores)
- `UBOOT_DEFCONFIG` (optional, default in `scripts/build_uboot.sh`)
- `LINUX_DEFCONFIG` (optional, default in `scripts/build_linux.sh`)

Typical flow
```
./scripts/apply_patches.sh
./scripts/build.sh
```

Outputs
- `out/u-boot/` for U-Boot builds
- `out/linux/` for kernel builds
- `dist/` for packaged bundles
