# Choosing Hardware: hardware matrix

> Verified against NVIDIA pages (GeForce RTX 5090, RTX PRO 6000, DGX Spark, H100, H200, DGX B200, GB200 NVL72), AMD ROCm GPU specifications (ROCm 10.1.0), Apple Mac Studio technical specifications, Intel Arc B580 specifications, Ollama GPU docs, 2026-10-11

**(unverified)** means the value was not confirmed on a vendor page in this pass and is omitted from decisions. Prices are not listed: the only price found was a launch list price, and street prices move. Check current prices at purchase time.

## 1. NVIDIA

| Hardware                       | Class                       | Memory                                                     | Memory bandwidth                      | Notes (from the vendor page)                                                                                                                        |
| ------------------------------ | --------------------------- | ---------------------------------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| GeForce RTX 4090               | Consumer, Ada               | 24 GB GDDR6X                                               | 1008 GB/s                             | From the RTX 5090 comparison table                                                                                                                  |
| GeForce RTX 5090               | Consumer, Blackwell         | 32 GB GDDR7, 512-bit                                       | 1792 GB/s                             | CUDA compute 12.0, 575 W total graphics power, NVLink: No, 5th-gen Tensor Cores with FP4                                                            |
| RTX PRO 6000 Blackwell         | Workstation                 | 96 GB GDDR7 with ECC                                       | 1792 GB/s                             | Blackwell workstation card                                                                                                                          |
| DGX Spark (GB10)               | Desktop, Grace Blackwell    | 128 GB LPDDR5x coherent unified (a 64 GB option is listed) | 273 GB/s                              | ConnectX-7 NIC at 200 Gbps, up to four systems connectable, up to 1 petaFLOP FP4, NVIDIA states inference of models up to 200B parameters on 128 GB |
| H100                           | Datacenter, Hopper          | 80 GB                                                      | 3.35 TB/s (SXM column of the page)    | NVLink and NVSwitch scaling                                                                                                                         |
| H200                           | Datacenter, Hopper          | 141 GB HBM3e                                               | 4.8 TB/s                              | First GPU with HBM3e per NVIDIA                                                                                                                     |
| DGX B200 (8 GPUs)              | Datacenter, Blackwell       | 1,440 GB total HBM3e                                       | 64 TB/s total                         | Derived per GPU: 180 GB and 8 TB/s (arithmetic on the totals)                                                                                       |
| GB200 NVL72 (72 GPUs)          | Rack-scale, Grace Blackwell | 13.4 TB HBM3E total; 372 GB per Superchip (2 GPUs)         | 576 TB/s total; 16 TB/s per Superchip | Derived per GPU: 186 GB and 8 TB/s. 130 TB/s NVLink domain, NVFP4 and FP8 tensor cores                                                              |
| GB300 NVL72, B300, DGX Station | Datacenter / desk           | (unverified)                                               | (unverified)                          | NVIDIA lists GB300 NVL72 as 72 Blackwell Ultra GPUs and 36 Grace CPUs; per-GPU memory not read                                                      |

Ollama NVIDIA support (docs.ollama.com/gpu): compute capability 12.1 (GB10), 12.0 (RTX 50 series and RTX PRO Blackwell), 9.0 (H100, H200), 8.9 (RTX 40, L4, L40), 8.6 (RTX 30, A40, A10), 8.0 (A100, A30), and older down to 5.0. Driver 550 or newer.

Choosing among NVIDIA parts:

- **Capacity per dollar and bandwidth** favour the RTX line for one to a few users. Multi-card consumer builds lack NVLink (RTX 5090 lists NVLink as No), so tensor parallel runs over PCIe.
- **RTX PRO 6000 Blackwell** gives 96 GB in one card at the same listed bandwidth as the RTX 5090, so it fits 70B-class 4-bit weights plus KV cache without splitting.
- **DGX Spark** gives the most memory in a desktop box but 273 GB/s, so it suits large MoE models and several small ones, not fast dense 70B decode. Details in the `self-hosted-llms` skill.
- **H100, H200, B200 class** are for many users or very large models. H200 raises both capacity and bandwidth over H100.
- **Engine fit:** TensorRT-LLM supports Blackwell, Grace Hopper, Hopper, Ada and Ampere on Linux. Check `choosing-inference-engine`.

## 2. AMD

VRAM below is from the ROCm GPU specifications page (GiB, not GB). Bandwidth was not on any page fetched in this pass.

| Hardware                       | Class              | Memory                                  | Bandwidth    | LLVM target |
| ------------------------------ | ------------------ | --------------------------------------- | ------------ | ----------- |
| Instinct MI300X                | Datacenter, CDNA3  | 192 GiB                                 | (unverified) | gfx942      |
| Instinct MI300A                | APU, CDNA3         | 128 GiB                                 | (unverified) | gfx942      |
| Instinct MI325X                | Datacenter, CDNA3  | 256 GiB                                 | (unverified) | gfx942      |
| Instinct MI350X and MI355X     | Datacenter, CDNA4  | 288 GiB                                 | (unverified) | gfx950      |
| Instinct MI350P                | CDNA4              | 144 GiB                                 | (unverified) | gfx950      |
| Radeon AI PRO R9700            | Workstation, RDNA4 | 32 GiB                                  | (unverified) | gfx1201     |
| Radeon PRO W7900               | Workstation, RDNA3 | 48 GiB                                  | (unverified) | gfx1100     |
| Radeon RX 7900 XTX             | Consumer, RDNA3    | 24 GiB                                  | (unverified) | gfx1100     |
| Radeon RX 9070 XT              | Consumer, RDNA4    | 16 GiB                                  | (unverified) | gfx1201     |
| Ryzen AI Max+ 395 (Strix Halo) | APU, RDNA3.5       | "Dynamic + carveout" from system memory | (unverified) | gfx1151     |

Strix Halo shares system memory with the GPU, so the usable pool depends on the BIOS carveout and the OS. Its maximum configurable memory and its bandwidth were not verified here. Check the vendor page and the machine's spec sheet.

Ollama lists ROCm v7 support on Linux for Radeon RX 9000 and 7000 series, Radeon AI PRO R9700, Radeon PRO W7000 series, Ryzen AI Max+ 395 and Instinct MI100 through MI350X. Windows support is a shorter list. Vulkan covers additional GPUs on Windows and Linux. vLLM lists AMD ROCm, and llama.cpp lists HIP and Vulkan backends. Engine details: `choosing-inference-engine`.

## 3. Apple Silicon

From the Mac Studio technical specifications page.

| Configuration         | Unified memory options | Memory bandwidth |
| --------------------- | ---------------------- | ---------------- |
| M5 Max, 32-core GPU   | 36 GB                  | 460 GB/s         |
| M5 Max, 40-core GPU   | 48, 64 or 128 GB       | 614 GB/s         |
| M5 Ultra, 64-core GPU | 96 GB                  | 1.2 TB/s         |
| M5 Ultra, 80-core GPU | 256 or 512 GB          | 1.2 TB/s         |

Other facts from that page: four Thunderbolt 5 ports (up to 120 Gb/s), 10 Gb Ethernet, maximum continuous power 480 W. Older chips (M1 to M4, laptops) were not read in this pass, so their bandwidths are **(unverified)** here.

The GPU cannot use all of unified memory. Apple documents `recommendedMaxWorkingSetSize` as the memory a Metal device can allocate without affecting runtime performance. Community guides report it is commonly about 75 percent of installed memory by default and can be raised with the undocumented `iogpu.wired_limit_mb` sysctl (value in MB, `0` means the system default, resets on reboot, key name differs on older macOS). Treat the 75 percent figure as **(unverified, community-reported)**. Setting it too high risks swapping and freezes, so leave several GB for the OS.

Engines: llama.cpp (Metal, first class), Ollama (Metal), TensorFold (qualified models), SGLang and vLLM (listed, check maturity), MLX tooling and LM Studio. See `choosing-inference-engine`.

## 4. Intel

| Hardware                      | Class   | Memory       | Bandwidth    | Other                                                                                                       |
| ----------------------------- | ------- | ------------ | ------------ | ----------------------------------------------------------------------------------------------------------- |
| Arc B580                      | Desktop | 12 GB GDDR6  | 456 GB/s     | 190 W TBP, PCIe 4.0 x8, oneAPI and OpenVINO support, Q4 2024 launch, launch recommended customer price $249 |
| Arc Pro B-series, Xeon, Gaudi | Various | (unverified) | (unverified) | SGLang lists Arc and Arc Pro B-series GPUs and Xeon CPUs; vLLM lists Intel XPU                              |

llama.cpp lists SYCL (Intel GPU) and an OpenVINO backend marked in progress. Ollama supports Intel GPUs through Vulkan.

## 5. CPU-only

llama.cpp lists AVX, AVX2, AVX512 and AMX support for x86 and NEON for Arm, and CPU+GPU hybrid inference for models larger than VRAM. vLLM lists x86 and Arm CPU support. CPU decode is bounded by system memory bandwidth, which was not verified for specific server or desktop platforms in this pass. Use CPU-only for small models, batch work that can wait, or as the overflow tier for MoE experts.

## 6. Quick picks (derived from the figures above)

| Need                                                   | Fits on                                                                          | Why                                                     |
| ------------------------------------------------------ | -------------------------------------------------------------------------------- | ------------------------------------------------------- |
| 8B to 14B at 8-bit or 4-bit, one user                  | RTX 5090 (32 GB), 24 GB cards, Mac 36 GB+                                        | 7 to 14 GB weights plus KV cache                        |
| 32B at 4-bit (about 16 GB weights), long context       | RTX 5090, RTX PRO 6000, Mac 64 GB+, DGX Spark                                    | Leaves room for KV cache                                |
| 70B at 4-bit (about 35 GB), one user                   | RTX PRO 6000, Mac 64 GB+, DGX Spark, Strix Halo (if enough memory is configured) | Needs more than one consumer card unless split          |
| 120B MoE at 4-bit (about 60 GB), low active parameters | DGX Spark, Mac 96 GB+, RTX PRO 6000                                              | Memory fits; low active reads make bandwidth acceptable |
| 70B at 8-bit or FP8, many users                        | H100, H200, MI300X-class, multi-GPU                                              | Weights 70 GB plus KV per sequence                      |
| 200B+ dense or very large MoE                          | Multi-GPU nodes, Mac Ultra 256 GB+, DGX Spark pairs                              | Capacity first; check the engine for multi-node         |

These rows use the weights-only table in `sizing-math.md`. Add KV cache and headroom before deciding.

## Sources

- https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/rtx-5090/
- https://www.nvidia.com/en-us/products/workstations/professional-desktop-gpus/rtx-pro-6000/
- https://www.nvidia.com/en-us/products/workstations/dgx-spark/
- https://www.nvidia.com/en-us/data-center/h100/
- https://www.nvidia.com/en-us/data-center/h200/
- https://www.nvidia.com/en-us/data-center/dgx-b200/
- https://www.nvidia.com/en-us/data-center/gb200-nvl72/
- https://rocm.docs.amd.com/en/latest/reference/gpu-arch-specs.html
- https://www.apple.com/mac-studio/specs/
- https://developer.apple.com/documentation/metal/mtldevice/recommendedmaxworkingsetsize
- https://www.intel.com/content/www/us/en/products/sku/241598/intel-arc-pro-b60-graphics/specifications.html
- https://docs.ollama.com/gpu
