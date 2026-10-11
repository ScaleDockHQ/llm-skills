# Hardware, OS and ROCm support

> Verified against ROCm 10.1.0 compatibility matrix and install guide, strix-halo-toolboxes.com host guide, Strix Halo Wiki AI overview (written 2025-08), 2026-10-11

## The chip

| Item           | Value                                                                       | Source                          |
| -------------- | --------------------------------------------------------------------------- | ------------------------------- |
| Family         | Ryzen AI Max / Max+ (Strix Halo) and the 400-series successor (Gorgon Halo) | ROCm matrix codename row        |
| CPU / GPU      | Zen 5, RDNA 3.5 iGPU (Radeon 8060S on Max+ 395), LLVM target `gfx1151`      | ROCm matrix, toolboxes site     |
| Unified memory | Up to 128 GB LPDDR5X-8000, 256-bit bus, theoretical 256 GB/s                | Strix Halo Wiki (2025-08)       |
| GPU compute    | 40 CU at up to 2.9 GHz, about 59 TFLOPS FP16 peak (wiki calculation)        | Strix Halo Wiki                 |
| NPU            | XDNA, about 50 INT8 TOPS; needs the IOMMU enabled                           | Strix Halo Wiki, toolboxes site |

The wiki's own comparison: the GPU behaves like a mid-range discrete card with a huge memory pool; 256 GB/s is well below discrete GPU bandwidth, so decode speed is bound by memory bandwidth and mixture-of-experts models with few active parameters suit it best.

Other Ryzen AI parts appear in the same ROCm matrix with other targets (`gfx1150` Strix Point, `gfx1152`, `gfx1153`, `gfx1103`); this skill covers `gfx1151` only.

## ROCm 10.1.0 support for gfx1151

- Listed parts: Ryzen AI Max+ PRO 495, 395 and PRO 395, Max+ 392, 388, Max PRO 490, 485, 390, 385, 380, and Max 390 and 385.
- Linux: Ubuntu 26.04.1 (kernel GA 7.0) and Ubuntu 24.04.5 (kernel HWE 7.0). The kernel driver is the inbox one that ships with Ubuntu; AMD's install page says Ryzen APUs need no separate `amdgpu` driver (`amdgpu-install ... --no-dkms` skips it).
- AMD's install page also says Ryzen APUs on Ubuntu 24.04 need OEM kernel 6.14 or newer (`sudo apt install linux-oem-24.04d`), while the matrix lists HWE 7.0. The two statements differ; use at least the matrix kernel and treat the OEM line as the minimum.
- Windows 11 25H2 with Adrenalin 26.10.41.05. WSL2 is a technical preview in 10.1.0.
- Meta package for apt/dnf: `amdrocm10.1-gfx1151`. Install steps are in `backends-and-engines.md`.

## Kernel and firmware

- The `amdgpu` driver is in the kernel; newer kernels carry fixes for this chip. The wiki (2025-08) recommended 6.15 or newer; the toolbox maintainer's reference host runs Fedora 43 with Linux 6.18.5, and the Ubuntu setup is documented with mainline 6.18.7.
- Install the latest `linux-firmware` for your distro; the wiki says recent firmware carries stability fixes.
- Boot arguments and the memory limit are in `memory.md`.

## OS notes

- Fedora uses Toolbx natively; Ubuntu and Debian users should use Distrobox, because the default `toolbox` package can have permission issues on those distributions (toolboxes site).
- AMD's Ryzen AI Halo developer machine ships a Debian-based distribution with systemd-boot, not GRUB; the memory tool `amd-ttm` exists for it (`memory.md`).
- Windows: Vulkan comes with the AMD driver, so a `win-vulkan` llama.cpp release runs without extra setup. The wiki says Windows allocates GPU memory automatically up to 96 GB (2025-08).
