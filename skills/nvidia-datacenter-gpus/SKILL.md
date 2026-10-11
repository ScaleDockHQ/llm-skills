---
name: nvidia-datacenter-gpus
description: Choose and operate NVIDIA datacenter GPUs (H100, H200, B200, B300, GB200/GB300) for LLM serving on owned or rented servers. Use for HBM sizing, SXM vs PCIe/NVL, NVLink and NVSwitch, Fabric Manager, data center driver branches (R580 LTS), DCGM, MIG, nvidia-smi checks, "CUDA unknown error" after driver mismatch, or picking between Hopper and Blackwell. For desktops use nvidia-rtx-workstation or nvidia-dgx-spark.
license: MIT
compatibility: Linux servers with NVIDIA datacenter GPUs (x86_64 HGX or Grace arm64); bash, docker, curl and jq. Driver, Fabric Manager, MIG, power-limit and firmware changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA datacenter GPUs

Pick the right datacenter GPU generation for a model, install a matching driver and Fabric Manager stack, and verify the node before an engine runs on it.

**Scope:** the hardware platform (memory, interconnect, driver branch, DCGM, MIG). Engine flags belong to `vllm`, `sglang`, `tensorrt-llm`; Kubernetes GPU enablement to `nvidia-gpu-operator`; renting these GPUs to the cloud skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
nvidia-smi -L; nvidia-smi --query-gpu=index,name,driver_version,memory.total,power.limit --format=csv
nvidia-smi topo -m                                                  # NVLink (NV#) vs PCIe paths
nvidia-smi nvlink -s 2>/dev/null | head; nvidia-smi -q | grep -iE 'MIG Mode|Persistence|Fabric' | head
modinfo nvidia 2>/dev/null | grep -E '^(license|version)'           # open (MIT/GPL) vs proprietary flavor
systemctl is-active nvidia-fabricmanager 2>/dev/null; nv-fabricmanager -v 2>/dev/null
dcgmi discovery -l 2>/dev/null | head; docker run --rm --gpus all ubuntu nvidia-smi -L
```

## Decision flow

1. Picking a GPU for a model: memory first, bandwidth second (`references/gpu-lineup.md`, then `choosing-hardware` for sizing math).
2. Fresh node or mismatch: use a data center driver branch, same version for driver and Fabric Manager (`references/driver-and-fabric.md`).
3. Multi-GPU on one node: confirm NVLink and, on NVSwitch systems, Fabric Manager is running before tensor parallel (`references/driver-and-fabric.md`).
4. Splitting a GPU for several services: MIG (`references/mig-and-dcgm.md`).
5. Monitoring and health: DCGM (`references/mig-and-dcgm.md`).
6. Engine and image: `references/combos/engines-on-datacenter-gpus.md`.
7. Something broken: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Driver and Fabric Manager upgrades, MIG changes, power caps and VBIOS updates need approval and a rollback path.
- **Driver and Fabric Manager versions must match.** Check `nv-fabricmanager -v` against the driver.
- **Pin a supported branch.** Prefer a Long Term Support branch for production; check the lifecycle table.
- **Blackwell needs the open kernel modules.** Use the open flavor of the data center driver.
- **Memory is the sizing constraint.** Weights + KV + overhead must fit with headroom; do not trust marketing token rates.
- **No prices.** Rates change; compare provider pages.
- **Verify upstream.** Re-read NVIDIA's release notes and lifecycle table before quoting versions.

## Workflows

- [ ] Baseline: run Discover; record GPU, driver, Fabric Manager -> `references/driver-and-fabric.md`
- [ ] Choose GPU and node shape -> `references/gpu-lineup.md`
- [ ] Driver, Fabric Manager, persistence -> `references/driver-and-fabric.md`
- [ ] MIG and DCGM health -> `references/mig-and-dcgm.md`
- [ ] Pick engine and image -> `references/combos/engines-on-datacenter-gpus.md`
- [ ] Verify: every GPU listed, NVLink topology as expected, Fabric Manager active (NVSwitch systems), container sees the GPUs, DCGM diag passes.

## Reference index

- `references/gpu-lineup.md`: H100, H200, B200, B300, GB200 specs and form factors.
- `references/driver-and-fabric.md`: driver branches, open modules, Fabric Manager, VBIOS note.
- `references/mig-and-dcgm.md`: MIG partitioning, DCGM health and diagnostics.
- `references/troubleshooting.md`: symptom to fix.
- `references/combos/engines-on-datacenter-gpus.md`: engine matrix.

## Companion skills

- `choosing-hardware`: sizing math. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
- `vllm`, `sglang`, `tensorrt-llm`: engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill <name>`.
- `nvidia-gpu-operator`: Kubernetes. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-gpu-operator`.
- `llm-observability`: DCGM exporter and Grafana. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
- `nvidia-rtx-workstation`: desktop cards. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-rtx-workstation`.
