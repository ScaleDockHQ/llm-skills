# DCGM on unified-memory GPUs (DGX Spark GB10)

> Verified against dcgm-exporter 4.8.4 docs and NVIDIA DGX Spark known-issues documentation, 2026-10-11

- DGX Spark shares system DRAM between CPU and GPU; there is no dedicated framebuffer.
- NVIDIA documents that `nvidia-smi` reports "Memory-Usage: Not Supported" on these iGPU platforms while per-process GPU memory is listed. This is expected.
- `cudaMemGetInfo` underestimates allocatable memory (it ignores pages the OS could reclaim to swap); engines whose memory planner uses it can under-size KV cache.
- Whether DCGM `DCGM_FI_DEV_FB_*` and the `DCGM_FI_PROF_*` fields return meaningful values on GB10 is unverified here; test on the box (`scripts/check.sh`) and treat missing or implausible values as unsupported, not as zero.
- Trusted memory headroom: node_exporter `node_memory_MemAvailable_bytes` and `node_memory_SwapFree_bytes`, or sparkDash `sparkdash_memory_available_bytes`.
- For a DGX Spark fleet view with engine probes and RoCE, use the `sparkdash` skill; DCGM remains useful for discrete GPUs elsewhere in the fleet.

## Official links

- DGX Spark known issues: https://docs.nvidia.com/dgx/dgx-spark/known-issues.html
