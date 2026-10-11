# DGX Station hardware and software stack

> Verified against DGX OS 7.6.0 and DGX Station Development Guide, 2026-10-11

DGX Station is sold by OEM partners (ASUS, Dell, GIGABYTE, HP, MSI, Supermicro and others); NVIDIA's product page lists "Order Now". NVIDIA also announced DGX Station for Windows for Q4 2026. Prices and lead times vary by partner and are not listed here.

## Hardware (NVIDIA specifications)

| Item           | Value                                                                                          |
| -------------- | ---------------------------------------------------------------------------------------------- |
| Superchip      | GB300 Grace Blackwell Ultra Desktop: 1x Blackwell Ultra GPU, 72-core Grace (Neoverse V2)       |
| GPU memory     | 252 GB HBM3e, 7.1 TB/s                                                                         |
| CPU memory     | 496 GB LPDDR5X (SOCAMM, ECC), 396 GB/s                                                         |
| Coherent total | up to 748 GB; NVLink-C2C 900 GB/s                                                              |
| AI compute     | up to 20 PFLOPS FP4 with sparsity (15 without)                                                 |
| Network        | ConnectX-8 SuperNIC, 2x QSFP112 (400 Gb/s per port), 1x 10 GbE RJ45, 1x 1 GbE RJ45 for the BMC |
| Storage        | 4x M.2: two PCIe Gen5 OS drives in software RAID 1, two PCIe Gen6 data drives                  |
| PCIe           | 1x Gen5 x16 and 2x Gen5 x16 (x8 electrical); optional RTX PRO Blackwell card (up to one)       |
| MIG            | up to 7 instances                                                                              |
| Power          | 1,600 W total system, 20 A circuit required                                                    |

Host display output comes from the add-in PCIe GPU; the BMC mini DisplayPort is for management only. Details vary by OEM, so confirm Wi-Fi, ports and RTX PRO options with the vendor.

## Software stack (DGX Station Development Guide)

- Ubuntu 24.04 server image with desktop packages ("Ubuntu with NVIDIA AI Developer Tools"), Linux 6.17 with patches, UEFI boot, Secure Boot and TPM on by default.
- Preinstalled: NVIDIA Container Toolkit, CUDA Toolkit, DCGM, DOCA-OFED, the `nvidia-open` kernel driver, NCCL, cuDNN, TensorRT, TensorRT-LLM, vLLM, SGLang, PyTorch, RAPIDS, Nsight tools.
- The guide names CUDA 13.1; the DGX OS 7 release notes list CUDA Toolkit 13.0 Update 3. Run `nvcc --version` and trust the box.

## DGX OS 7 release notes (updated Sep 14, 2026)

| Item                      | Value                                                                |
| ------------------------- | -------------------------------------------------------------------- |
| Minimum ISO for DGX GB300 | 7.2.3 (firmware 1.0.6)                                               |
| Latest release            | 7.6.0 (Sep 14, 2026), Ubuntu 24.04.5                                 |
| GPU driver, GB300         | 580.178.04                                                           |
| Kernel, GB300             | 7.0.0-1018-nvidia-64k (7.5.0 shipped 6.17.0-1014-nvidia-64k)         |
| NCCL / cuDNN / DCGM       | 2.31.2 / 9.24.0 (current table 9.26.0) / 4.6.1 (current table 4.7.0) |
| NVIDIA Container Toolkit  | 1.20.0                                                               |
| DOCA-OFED                 | 3.2.3 LTS                                                            |

The DGX OS 7 notes also say upgrades to DGX OS 8.x are currently unsupported on GB300. Package versions in the repositories can be newer than the ISO.

## Sources

- <https://www.nvidia.com/en-us/products/workstations/dgx-station/>
- <https://docs.nvidia.com/dgx/dgx-station-development-guide/porting/software-requirements.html>
- <https://docs.nvidia.com/dgx/dgx-os-7-user-guide/release_notes.html>
