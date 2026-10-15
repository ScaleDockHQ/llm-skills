---
name: nccl-rdma-networking
description: NCCL over InfiniBand, RoCE and GPUDirect RDMA for multi-node GPU inference and training, verifying the fabric before tuning NCCL. Use to diagnose NET/Socket instead of NET/IB/GDRDMA, slow or hung cross-node tensor parallelism, ibv_create_qp or ibv_modify_qp failures, wrong NCCL_IB_HCA, NCCL_SOCKET_IFNAME or GID index, nccl-tests busbw, ACS, IOMMU, nvidia-peermem. Not Apple RDMA (exo skill).
license: MIT
compatibility: Commands assume Linux with NVIDIA GPUs, bash and the rdma-core, perftest and nccl-tests tools where named. Most checks need no root; module loads, sysctl, limits and BIOS/ACS changes need the user's explicit approval and a reboot plan.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NCCL and RDMA networking

A multi-node GPU cluster where NCCL provably uses the fast fabric (`NET/IB/GDRDMA` over InfiniBand or RoCE), with a test ladder from NIC to engine so each layer is proven before the next.

**Scope:** NVIDIA GPUs, NCCL, RDMA fabrics (InfiniBand, RoCE), GPUDirect RDMA, nccl-tests and perftest. Not engine flags (see `vllm`, `sglang`, `tensorrt-llm`, `multi-node-inference`) and not Apple RDMA over Thunderbolt (see `exo`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, no root needed unless stated. `scripts/nccl-net-check.sh` runs the safe ones.

```bash
nvidia-smi topo -m                                  # GPU/NIC distances: NV#, PIX, PXB, PHB, SYS
nvidia-smi topo -p2p n                              # NVLink peer matrix
ibstat 2>/dev/null || ibstatus 2>/dev/null          # State Active, Rate, link layer
rdma link show 2>/dev/null; ip -br link | grep -Ei 'ib|mlx|eth|en'
lsmod | grep -E 'nvidia_peermem|nvidia-peermem|mlx5_core|ib_core'
ulimit -l                                           # want unlimited for RDMA registration
cat /proc/cmdline | tr ' ' '\n' | grep -i iommu; dmesg 2>/dev/null | grep -iE 'iommu|dmar' | head -3
env | cut -d= -f1 | grep '^NCCL_' || true           # names only
python3 -c 'import torch;print(torch.cuda.nccl.version())' 2>/dev/null
ls /dev/infiniband 2>/dev/null; command -v ib_write_bw all_reduce_perf
gh api repos/NVIDIA/nccl/releases/latest --jq .tag_name
```

Ask only what discovery cannot show: fabric (InfiniBand or RoCE), switch vendor and congestion settings, NIC model, nodes and GPUs per node, bare metal vs VM vs container vs Kubernetes, which engine runs on top.

## Decision flow

1. **NCCL log says `NET/Socket` or training is slow across nodes:** walk the ladder bottom-up. -> `references/diagnostics.md`
2. **NIC or port not Active, Rate low, SM missing:** fabric layer. -> `references/fabric-and-gpudirect.md`
3. **GPUDirect RDMA not used:** `nvidia-peermem` or DMA-BUF, ACS, IOMMU, topology. -> `references/fabric-and-gpudirect.md`
4. **Wrong interface, HCA, GID index, hang at init:** -> `references/env-vars.md`, then `references/troubleshooting.md`
5. **Containers or Kubernetes:** IPC_LOCK, /dev/shm, devices, host network. -> `references/containers-and-engines.md`
6. **Fabric is proven, NCCL still below expectation:** tuning. -> `references/performance-tuning.md`
7. **New NCCL or driver:** -> `references/updating.md`

## Rules

- **Prove bottom-up.** NIC link, then `ib_write_bw`, then GPU-memory `ib_write_bw`, then nccl-tests, then the engine. Never tune NCCL variables before the lower layers pass.
- **Ask before changing the system.** `modprobe`, `sysctl`, `limits.conf`, ACS changes, IOMMU or BIOS settings and driver updates need approval, a rollback and usually a reboot.
- **Set as little as possible.** NCCL auto-detects topology; upstream discourages broad tuning variables in production. Pin only `NCCL_SOCKET_IFNAME` and `NCCL_IB_HCA` (with `=` for exact names) when detection picks wrong.
- **Do not set `NCCL_IB_GID_INDEX` on NCCL 2.21+.** The GID index is selected dynamically; older versions need `show_gids`.
- **Never use `NCCL_DEBUG=ATTN` site-wide.** Versions before 2.32 do not know it and drop to no logging; use `NCCL_DEBUG=WARN NCCL_DEBUG_LEVELS=ATTN`.
- **NCCL traffic is not encrypted by default.** Keep bootstrap and RDMA on a private network segment; an OpenSSL build can encrypt only NCCL's TCP socket traffic, not IB or RoCE.
- **Same versions everywhere.** NCCL, drivers and OFED/DOCA on every node; frameworks may bundle their own NCCL.
- **Secrets never touch output.** Nothing here needs keys; do not print job env dumps that may include tokens (`env | cut -d= -f1`).
- **Verify upstream.** Variables and defaults come from the NCCL user guide for the installed version.

## Workflows

### Prove the fabric

- [ ] Run `scripts/nccl-net-check.sh` on each node -> `references/diagnostics.md`.
- [ ] `ib_write_bw` host memory, then `--use_cuda=<gpu>` between two nodes.
- [ ] Build nccl-tests; run `all_reduce_perf` single node, then two nodes with `NCCL_DEBUG=INFO`; confirm `NET/IB` and `GDRDMA`.

### Make an engine use it

- [ ] Set `NCCL_SOCKET_IFNAME` (bootstrap) and `NCCL_IB_HCA`; add `IPC_LOCK`, `/dev/shm`, RDMA devices to containers -> `references/containers-and-engines.md`.
- [ ] Launch with `NCCL_DEBUG=INFO`; grep for `NET/IB` and `GDRDMA`, not `NET/Socket`.

### Diagnose a hang or slowdown

- [ ] `NCCL_DEBUG=INFO NCCL_DEBUG_SUBSYS=INIT,NET`; match the error to `references/troubleshooting.md`.
- [ ] `rdma statistic`, `ethtool -S`, `perfquery` while the test runs.

## Reference index

| File                                   | Read when                                                     |
| -------------------------------------- | ------------------------------------------------------------- |
| `references/diagnostics.md`            | The test ladder, nccl-tests, reading busbw and NCCL logs      |
| `references/fabric-and-gpudirect.md`   | InfiniBand vs RoCE checks, peermem or DMA-BUF, ACS, IOMMU     |
| `references/env-vars.md`               | The NCCL variables that matter, values, defaults, config file |
| `references/containers-and-engines.md` | Docker, Kubernetes, vLLM, SGLang, TensorRT-LLM specifics      |
| `references/performance-tuning.md`     | Rails, QPs, algo, channels, NVLS, what not to touch           |
| `references/install.md`                | NCCL, nccl-tests, perftest, rdma-core, bundled NCCL           |
| `references/updating.md`               | Version alignment, upgrades, rollback                         |
| `references/troubleshooting.md`        | Symptom to cause to fix                                       |

Script: `scripts/nccl-net-check.sh` (read-only node check). Template: `templates/nccl.conf`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `multi-node-inference`: parallelism strategy across nodes.
- `vllm`, `sglang`, `tensorrt-llm`: engines that use NCCL.
- `disaggregated-serving`: KV transfer over RDMA between prefill and decode.
- `choosing-hardware`: NIC and fabric sizing.
- `exo`: Apple RDMA over Thunderbolt, a different stack.
