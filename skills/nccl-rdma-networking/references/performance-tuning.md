# NCCL performance tuning

> Verified against NCCL v2.32.3 and nccl-tests v2.21.1 (docs.nvidia.com/deeplearning/nccl), 2026-10-11

Source: NCCL user guide (Performance and tuning; env). Upstream: NCCL is tuned for a wide range of systems and re-tuned each release; most variables below are for edge cases.

Order of work:

1. Fabric proven (see `diagnostics.md`); `ib_write_bw` at line rate; GPU-memory path matches host path.
2. nccl-tests large-message busbw near expectation for the NIC count and NVLink. If `nvbandwidth` (build with `-DMULTINODE=1` for multinode tests) and `ib_write_bw` look right but NCCL is slow, then consider the knobs.
3. One change at a time, measured with nccl-tests and the real workload.

Knobs:

- **Rails:** `NCCL_CROSS_NIC` (0 for rail-optimized networks with slow inter-rail links, 1 if all NICs share a switch; default 2). `NCCL_IB_HCA` to use exactly the intended NICs.
- **RoCE:** `NCCL_IB_QPS_PER_CONNECTION` above 1; `NCCL_IB_TC` per vendor guidance; fix congestion control first.
- **Channels and CTAs:** `NCCL_MIN_CTAS`/`NCCL_MAX_CTAS` trade GPU resources for throughput (relevant when collectives overlap with compute; fewer CTAs help inference kernels).
- **Buffers:** `NCCL_BUFFSIZE` larger can help high-latency networks at the cost of GPU memory; smaller may help some PCIe topologies.
- **Algorithm and protocol:** `NCCL_ALGO`, `NCCL_PROTO` for diagnosis, not production defaults.
- **NVLS:** default on Hopper+ NVSwitch systems; toggle `NCCL_NVLS_ENABLE` only to isolate problems.
- **CPU affinity:** keep ranks on the NUMA node closest to their GPU and NIC; `NCCL_IGNORE_CPU_AFFINITY` exists but does not change placement.
- **Inference note:** small decode-time all-reduces are latency-bound; bandwidth tuning matters little there. Check latency (`ib_write_lat`, small-size rows of nccl-tests) and CUDA-graph use in the engine.

Record: NCCL version, driver, OFED, topology (`nvidia-smi topo -m`), variables set, nccl-tests commands and busbw at 128M and 8G.
