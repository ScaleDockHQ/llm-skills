# Troubleshooting datacenter GPUs

> Verified against NVIDIA Data Center GPU Driver 580.178.04 release notes and NVIDIA product pages, 2026-10-11

| Symptom                                               | Cause                                              | Fix                                                                          |
| ----------------------------------------------------- | -------------------------------------------------- | ---------------------------------------------------------------------------- |
| CUDA init error on HGX node, `nvidia-smi` shows GPUs  | Fabric Manager not running or mismatched           | Start `nvidia-fabricmanager`; match version to the driver                    |
| Driver fails to load on Hopper after upgrade          | Subrevision 3 with VBIOS older than 96.00.68.00.xx | Update VBIOS per vendor before driver 580.178.04                             |
| `nvidia-smi` fails after closed to open module switch | Known R580 upgrade issue                           | Remove old driver packages, install open driver and matching toolkit, reboot |
| Blackwell GPU not found                               | Proprietary kernel modules                         | Use the open flavor                                                          |
| DCGM refuses to start                                 | DCGM older than 4.3.x                              | Upgrade DCGM                                                                 |
| Tensor parallel slow on PCIe GPUs                     | No NVLink bridge                                   | `nvidia-smi topo -m`; use pipeline parallel or fewer GPUs                    |
| Container sees no GPU                                 | Toolkit missing                                    | NVIDIA Container Toolkit, `--gpus all`                                       |
| MIG device not visible in container                   | Using full-GPU index                               | Use MIG UUIDs from `nvidia-smi -L`                                           |

## Sources

- <https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580-178-04/index.html>
