# NCCL and RDMA Networking Skill

An agent skill for making multi-node NVIDIA GPU clusters actually use their fabric. It covers a bottom-up test ladder (NIC link, `ib_write_bw` in host and GPU memory, nccl-tests, then the engine), InfiniBand and RoCE checks, GPUDirect RDMA with `nvidia-peermem` or DMA-BUF, ACS and IOMMU pitfalls, the NCCL environment variables that matter, container and Kubernetes requirements for vLLM and friends, tuning, updates and troubleshooting. It ships a read-only per-node check script. Every command is read-only first.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill nccl-rdma-networking
```

## Rules

- **Prove bottom-up** before tuning NCCL.
- **Ask before changing the system**: modules, sysctl, limits, ACS, IOMMU, drivers.
- **Set as little as possible**; pin interfaces and HCAs only when detection is wrong.
- **No `NCCL_IB_GID_INDEX` on NCCL 2.21+.**
- **NCCL traffic is not encrypted**; use a private network.
- **Secrets never touch output.**

## References

- [`references/diagnostics.md`](references/diagnostics.md): test ladder and log reading.
- [`references/fabric-and-gpudirect.md`](references/fabric-and-gpudirect.md): fabric, peermem, ACS, IOMMU.
- [`references/env-vars.md`](references/env-vars.md): NCCL variables.
- [`references/containers-and-engines.md`](references/containers-and-engines.md): containers and engines.
- [`references/performance-tuning.md`](references/performance-tuning.md): tuning.
- [`references/install.md`](references/install.md): installs.
- [`references/updating.md`](references/updating.md): updates.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

Script: [`scripts/nccl-net-check.sh`](scripts/nccl-net-check.sh). Template: [`templates/nccl.conf`](templates/nccl.conf).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

`multi-node-inference`, `vllm`, `sglang`, `tensorrt-llm`, `disaggregated-serving`, `choosing-hardware`, `exo`.

## License

MIT
