# Memory and coherency on DGX Station

> Verified against DGX OS 7.6.0 and DGX Station Development Guide, 2026-10-11

## Two pools, one address space

HBM3e (252 GB, 7.1 TB/s) is on the GPU; LPDDR5X (496 GB, 396 GB/s) is on the Grace CPU. They share a coherent address space over NVLink-C2C. The CPU can cache GB300 memory, but GB300 access to CPU memory is not cached. Crossing the boundary is limited to NVLink-C2C bandwidth.

## CDMM is the default

From the Development Guide: with the R610 or later driver the memory path runs in Coherent Driver-based Memory Management (CDMM). The NVIDIA driver manages GPU memory; CPU memory stays under the Linux kernel; `malloc` stays in CPU memory. It is enabled with the kernel module parameter `NVreg_CoherentGPUMemoryMode=driver`. Legacy NUMA mode (`numa` or removing the parameter) is documented as not recommended, and in it `malloc` may land in GPU memory.

```bash
grep -i CoherentGPUMemoryMode /proc/driver/nvidia/params   # read-only check
numactl -H
```

The DGX OS release notes list driver 580.178.04, while the guide cites R610; confirm the mode on the actual machine before assuming either.

## Sizing

- Put weights and the hot KV cache in HBM: budget weights + KV + activations + overhead under 252 GB, and keep headroom. Use the `choosing-hardware` skill for the arithmetic.
- LPDDR5X is for overflow (offloaded layers, cold KV, CPU work). NVIDIA advises UVM only for ease of programming or when the working set exceeds HBM, and explicit allocation otherwise.
- Models up to roughly 1T parameters are NVIDIA's headline (with quantisation, using the full 748 GB). Expect much lower decode speed for whatever spills.
- `nvidia-smi --query-gpu` memory fields can report N/A on unified-memory systems (NVIDIA vLLM playbook note); use plain `nvidia-smi` and `free -h`.
- If memory pressure appears within capacity, NVIDIA's workaround is `sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'`. Ask first.

## Sources

- <https://docs.nvidia.com/dgx/dgx-station-development-guide/coherency.html>
- <https://build.nvidia.com/station/vllm/troubleshooting>
