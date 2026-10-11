# Driver, CUDA and sm_120

> Verified against NVIDIA RTX PRO Blackwell datasheets, CUDA Toolkit 13.4 Update 1 and driver 580 README, 2026-10-11

## Open kernel modules are required

NVIDIA's driver README: the proprietary kernel module flavor supports architectures up to, but not including, Blackwell; Blackwell and later are supported only by the open kernel modules (dual MIT/GPLv2). The installer picks open by default when no pre-Turing GPU is present, and `-M=open` forces it. Forum reports of `nvidia-smi` printing "No devices were found" on an RTX PRO 6000 were resolved by switching to the open driver.

```bash
modinfo nvidia | grep -E '^(license|version)'       # open flavor reports Dual MIT/GPL
apt list --installed 2>/dev/null | grep -E 'nvidia-(open|driver|kernel)'
```

On Ubuntu install the open flavor package for your branch (for example `nvidia-open` meta-package from the NVIDIA CUDA repository, or `nvidia-driver-<branch>-open` from Ubuntu). Ask before replacing an installed driver, and reboot after.

## Branches and CUDA

From the CUDA 13.4 Update 1 release notes: CUDA 13.0 pairs with R580, 13.1 with R590, 13.2 with R595, 13.3 with R610, 13.4 with R615. CUDA 13.x applications run on drivers 580 or newer through minor-version compatibility. Since CUDA 13.4 on Linux the toolkit no longer bundles the driver; install it separately. CUDA 13 dropped Maxwell, Pascal and Volta support.

## sm_120

CUDA 12.8 was the first toolkit with native compute capability 12.0 (sm_120) and needs an R570 or newer driver. Build with `-gencode=arch=compute_120,code=sm_120` and keep PTX with `code=compute_120`, or `CMAKE_CUDA_ARCHITECTURES=120`. Libraries built without 120 or PTX fail or JIT-compile slowly; use wheels and images built for CUDA 12.8+ (PyTorch cu128 or newer). Note some cuBLAS known issues name compute capability 12.0 and 12.1 in the 13.4 release notes; read them if you hit wrong GEMV results.

## Operations

- Persistence mode keeps the driver loaded (`sudo nvidia-smi -pm 1` or the persistenced service; ask first).
- Container GPU access needs the NVIDIA Container Toolkit; check with `docker run --rm --gpus all ubuntu nvidia-smi`.

## Sources

- <https://download.nvidia.com/XFree86/Linux-x86_64/580.159.03/README/kernel_open.html>
- <https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html>
- <https://docs.nvidia.com/cuda/archive/12.8.2/blackwell-compatibility-guide/index.html>
- <https://forums.developer.nvidia.com/t/rtx-pro-6000-blackwell-workstation-edition-driver-support/332701>
