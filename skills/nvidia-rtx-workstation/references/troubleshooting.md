# Troubleshooting RTX workstation GPUs

> Verified against NVIDIA RTX PRO Blackwell datasheets, CUDA Toolkit 13.4 Update 1 and driver 580 README, 2026-10-11

| Symptom                                            | Cause                                  | Fix                                                                                          |
| -------------------------------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------- |
| `nvidia-smi`: No devices were found                | Proprietary kernel module on Blackwell | Install the open flavor, reboot (`driver-and-cuda.md`)                                       |
| "no kernel image is available" or PTX JIT slowness | Binary built without sm_120            | Rebuild with CUDA 12.8+ and arch 120, or use a newer image/wheel                             |
| GPU runs at PCIe x8 or gen 3                       | Slot, riser or BIOS                    | `nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.width.current`, reseat, BIOS         |
| Container sees no GPU                              | Toolkit missing                        | NVIDIA Container Toolkit, `--gpus all`                                                       |
| Tensor parallel slower than one card               | PCIe-only link                         | Pipeline parallel, one model per card, measure with nccl-tests                               |
| Throttling or shutdowns under load                 | PSU, 16-pin cable or airflow           | Check cable seating, PSU rating, cap power with `nvidia-smi -pl`                             |
| Out of memory with free-looking VRAM               | KV cache, graphs, other processes      | `nvidia-smi --query-compute-apps=pid,used_memory --format=csv`; lower context or utilisation |

## Sources

- <https://download.nvidia.com/XFree86/Linux-x86_64/580.159.03/README/kernel_open.html>
- <https://docs.nvidia.com/cuda/archive/12.8.2/blackwell-compatibility-guide/index.html>
