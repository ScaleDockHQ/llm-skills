# Datacenter GPU lineup for LLM serving

> Verified against NVIDIA Data Center GPU Driver 580.178.04 release notes and NVIDIA product pages, 2026-10-11

NVIDIA-published figures. Sparse versus dense compute is not compared here; for LLM decode, memory capacity and bandwidth matter most.

| GPU                            | Memory       | Bandwidth    | Max TDP                 | Interconnect                               |
| ------------------------------ | ------------ | ------------ | ----------------------- | ------------------------------------------ |
| H100 SXM                       | 80 GB HBM3   | 3.35 TB/s    | up to 700 W             | NVLink 900 GB/s                            |
| H100 NVL (PCIe)                | 94 GB        | 3.9 TB/s     | 350-400 W               | NVLink bridge 600 GB/s, PCIe Gen5 128 GB/s |
| H200 SXM                       | 141 GB HBM3e | 4.8 TB/s     | up to 700 W             | NVLink 900 GB/s                            |
| H200 NVL (PCIe)                | 141 GB HBM3e | 4.8 TB/s     | up to 600 W             | 2- or 4-way NVLink bridge 900 GB/s per GPU |
| B200 SXM (HGX)                 | 180 GB HBM3e | up to 8 TB/s | configurable up to 1 kW | NVLink 1.8 TB/s                            |
| B300 SXM (HGX)                 | 288 GB HBM3e | up to 8 TB/s | see HGX B300 docs       | NVLink 1.8 TB/s                            |
| GB200 (per GPU in NVL systems) | 186 GB HBM3e | 8 TB/s       | see GB200 docs          | NVLink-C2C 900 GB/s CPU to GPU             |

HGX nodes: 8x H100 is 640 GB, 8x H200 is 1,128 GB, 8x B200 is 1,440 GB, 8x B300 is up to 2,304 GB of GPU memory. HGX H100/H200 use third-generation NVSwitch with 900 GB/s GPU-to-GPU; HGX B200/B300 use NVSwitch with 1,800 GB/s. MIG: H100 SXM up to 7 instances at 10 GB, H200 SXM up to 7 at 18 GB.

## Choosing

- Fit the model first (weights + KV + overhead in the node's total HBM, with tensor-parallel overhead), then pick by bandwidth. See `choosing-hardware`.
- Hopper (H100/H200) supports FP8; Blackwell adds FP4. Engine support for FP4 varies; check the engine skill.
- PCIe/NVL parts suit air-cooled racks; SXM HGX nodes give full NVSwitch bandwidth for large tensor-parallel models.
- Other data center parts exist (L4, L40S, A100, RTX PRO 6000 Blackwell Server Edition); take their specs from the current NVIDIA datasheet.

## Sources

- <https://resources.nvidia.com/en-us-gpu/h100-datasheet-24306>
- <https://www.nvidia.com/en-us/data-center/h200/>
- <https://docs.nvidia.com/enterprise-reference-architectures/hgx-ai-factory/latest/components.html>
- <https://docs.nvidia.com/enterprise-reference-architectures/hgx-ai-factory-h100-h200-b200/latest/components.html>
