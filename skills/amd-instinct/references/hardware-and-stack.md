# Hardware and current software stack

> Verified against ROCm 10.1.0 (compatibility matrix 2026-08-26, release notes 2026-10-05), 2026-10-11

Sources: <https://rocm.docs.amd.com/en/latest/compatibility/compatibility-matrix.html> and <https://rocm.docs.amd.com/en/latest/about/release-notes.html>. Since ROCm 7.14 ROCm is built and released with TheRock; version numbers went from 7.14.x to 10.0.0 and 10.1.0.

## Parts and LLVM targets

| Series | Architecture | LLVM target | Parts listed for ROCm 10.1.0 |
| ------ | ------------ | ----------- | ---------------------------- |
| MI350  | CDNA 4       | `gfx950`    | MI355X, MI350X, MI350P       |
| MI300  | CDNA 3       | `gfx942`    | MI325X, MI300X, MI300A       |
| MI200  | CDNA 2       | `gfx90a`    | MI250X, MI250, MI210         |
| MI100  | CDNA         | `gfx908`    | MI100                        |

MI300X: 8 XCDs and 192 GB HBM3 per GPU, 1.5 TB across an 8-GPU UBB 2.0 baseboard with fully meshed Infinity Fabric (AMD acceptance guide). Read memory sizes for other parts from AMD's datasheet for the exact SKU; this skill does not restate them.

## Operating systems (Instinct)

| Series | Ubuntu                                                | RHEL                            | Other                                                                |
| ------ | ----------------------------------------------------- | ------------------------------- | -------------------------------------------------------------------- |
| MI350  | 26.04.1 (GA 7.0), 24.04.5 (GA 6.8), 22.04.5 (GA 5.15) | 10.2, 10.0, 9.8, 9.6, 9.4, 8.10 | Debian 13 and 12, Oracle Linux 10 and 9, Rocky 9, SLES 16.0 and 15.7 |
| MI300  | 26.04.1 (GA 7.0), 24.04.5 (GA 6.8)                    | 10.2, 9.8, 9.6                  | Debian 13, Oracle Linux 10, 9 and 8, SLES 15.7                       |
| MI200  | none listed                                           | 10.2, 10.0, 9.8, 9.6, 9.4       | Debian 12                                                            |

The matrix is a selector page; confirm your series' column on the live page before pinning. In 10.1.0 Ubuntu 26.04.1 and 24.04.5 replaced 26.04 and 24.04.4.

## Kernel driver and firmware

- `amdgpu` driver versions listed: 31.60.0, 31.50.0, 31.40.1, 31.40.0, 31.30.0, 31.20.0, 31.10.0 and the 30.x line. Install it from AMD's Instinct documentation for your distro, or with the ROCm runfile (`deps=install amdgpu`).
- Firmware (PLDM bundle) listed: MI350 `01.26.01.03` or later (also `01.26.00.02`); MI300 `BKC12.0 (IFWI PRD1000A)` or later, `IFWI 00189939`; MI200 `01.26.01.03` or later, `01.25.06.08`; MI100 `01.26.00.04` or later and older bundles.
- Use a driver and firmware pair that the matrix lists.

## ROCm 10.1.0 core components

HIP 7.16.0, LLVM 24.0.0, ROCr Runtime 1.21.0, AMD SMI 27.1.0, rocminfo 1.0.0, RCCL 2.30.7, rocBLAS 5.7.0, hipBLASLt 1.4.1, MIOpen 3.6.1, Composable Kernel 1.3.0, hipFile 0.5.0, ROCm Compute Profiler 3.9.0, ROCprofiler-SDK 1.4.1.

## AI ecosystem validated with 10.1.0

| Framework    | Versions               | Python                          |
| ------------ | ---------------------- | ------------------------------- |
| PyTorch      | 2.14.0, 2.13.0, 2.12.0 | 3.10 to 3.14                    |
| JAX          | 0.11.1, 0.11.0, 0.10.2 | 3.12 to 3.14 (0.10.2 also 3.11) |
| vLLM         | 0.29.0                 | 3.14, requires PyTorch 2.13.0   |
| SGLang       | 0.5.18                 | 3.14, requires PyTorch 2.13.0   |
| ONNX Runtime | 1.29.0                 | 3.12                            |
| MIGraphX     | 2.18                   | 3.12                            |

TensorFlow 2.19.1 support was dropped in 10.1.0. The vLLM project's own image (`vllm/vllm-openai-rocm:v0.31.0`) is newer than the vLLM 0.29.0 that AMD validated with 10.1.0; see `containers-and-engines.md` for how to choose.

## Virtualization (summary)

SR-IOV needs the AMD GPU Virtualization Driver (GIM) 9.3.0.K. Passthrough and SR-IOV support depends on GPU series and host/guest OS; read the matrix before planning VMs. See `multi-gpu-and-partitioning.md`.
