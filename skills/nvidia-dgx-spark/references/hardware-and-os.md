# DGX Spark hardware and software stack

> Verified against DGX OS 7.5.0 (DGX Spark User Guide release notes, hardware and known-issues pages, last updated Sep 10, 2026), 2026-10-11

## Hardware

| Item                  | Value (NVIDIA hardware overview)                                       |
| --------------------- | ---------------------------------------------------------------------- |
| SoC                   | GB10 Grace Blackwell; 6,144 CUDA cores, 5th-gen Tensor Cores with FP4  |
| CPU                   | 20 Arm cores (10 Cortex-X925 + 10 Cortex-A725)                         |
| Memory                | 128 GB LPDDR5X unified, 273 GB/s (16 channels, 256 bit, 8533)          |
| Network               | 10 GbE, Wi-Fi 7, ConnectX-7 NIC with 2 QSFP ports, up to 200 Gb/s each |
| AI compute            | up to 1 PFLOP FP4 with sparsity (NVIDIA figure)                        |
| Model size claim      | up to about 200 billion parameters per node                            |
| Power                 | 240 W external supply required; GB10 TDP 140 W, 100 W for the rest     |
| Operating temperature | 5 to 30 degrees C                                                      |
| Size                  | 150 mm x 150 mm x 50.5 mm                                              |

Decode speed is bound by memory bandwidth, not compute. Two Sparks give 256 GB for models that need tensor or pipeline parallelism across nodes. Storage size (1 or 4 TB NVMe) varies by SKU.

## Current software stack (Founders Edition, release notes table)

| Component           | Version    |
| ------------------- | ---------- |
| DGX OS              | 7.5.0      |
| NVIDIA GPU driver   | 580.159.03 |
| CUDA Toolkit        | 13.0.2     |
| Canonical kernel    | 6.17       |
| UEFI                | 1.110.13   |
| Embedded Controller | 3.5.8      |
| SoC firmware        | 2.155.11   |

The table applies only to the Founders Edition; GB10 partner systems may update later. Compute capability is `sm_121` (build with `121a-real` or `121`). NVIDIA states the CUDA version is verified with the hardware at release time and that newer CUDA features arrive through NGC containers (PyTorch, vLLM, TensorRT-LLM), so engines run best from NGC or CUDA 13 images.

Notable changes: November 2025 added the 6.14 HWE kernel; January 2026 added ConnectX-7 hot plug (saves up to 18 W when unused); a regression with multiple connected Sparks after DGX OS 7.4.0 was fixed in February 2026; June 2026 added the NVIDIA Sync Cluster Assistant (three devices without a switch, four with one) and NCCL 2.30u1 support for a three-node ring; July 2026 improved OOM handling in the driver and made display reserved memory selectable (2 GB default, 4 GB) in the BIOS. Ubuntu Pro with 10-year Canonical support is included.

## Power and thermals

Use the supplied 240 W adapter and keep the unit within the operating range. NVIDIA documents no throttling thresholds; if tokens per second fall during long runs, record temperature and power with `nvidia-smi` while benchmarking before drawing conclusions.

## UEFI

Needs a keyboard physically attached (a Mac keyboard may need Esc only). Hold Esc or Del at boot. Useful settings: boot from USB (Boot Override), Secure Boot (default Enabled; disable or enroll the PXE loader for PXE), network stack for PXE, wireless and Bluetooth master switch (Advanced, IO Port Access).

## Sources

- <https://docs.nvidia.com/dgx/dgx-spark/hardware.html>
- <https://docs.nvidia.com/dgx/dgx-spark/release-notes.html>
- <https://docs.nvidia.com/dgx/dgx-spark/known-issues.html>
- <https://docs.nvidia.com/dgx/dgx-spark/uefi-settings.html>
