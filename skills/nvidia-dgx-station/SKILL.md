---
name: nvidia-dgx-station
description: Set up, size and operate NVIDIA DGX Station (GB300 Grace Blackwell Ultra, 252 GB HBM3e plus 496 GB LPDDR5X, DGX OS, ConnectX-8) for LLM inference and fine-tuning, single or two nodes. Use for DGX Station, GB300 desktop, CDMM vs NUMA coherent memory, BMC and Redfish, 1600 W power, two-station QSFP RoCE, wrong-GPU selection with an RTX PRO card, or which engine and image runs on it. Not for DGX Spark or datacenter racks.
license: MIT
compatibility: DGX Station GB300 from NVIDIA OEM partners (DGX OS on Ubuntu 24.04, arm64, CUDA 13); bash, ssh, docker, curl and jq. Firmware, driver, kernel-module parameters, GRUB and netplan changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA DGX Station

Take a DGX Station GB300 from first boot to a stable inference host: known-good software, a memory plan across HBM and LPDDR5X, correct GPU selection, BMC access, optional two-station fabric and updates.

**Scope:** the platform. Engine flags belong to the product skills (`vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`). The small desktop box is `nvidia-dgx-spark`. Gateway, exposure and catalog belong to `self-hosted-llms`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
uname -m; grep -E '^(NAME|VERSION)=' /etc/os-release; uname -r               # aarch64, DGX OS, kernel
nvidia-smi -L; nvidia-smi --query-gpu=index,name,driver_version --format=csv  # GB300 plus optional RTX PRO card
nvidia-smi topo -m                                                            # which index is the GB300
cat /proc/driver/nvidia/params 2>/dev/null | grep -i CoherentGPUMemoryMode    # CDMM (driver) vs numa
nvcc --version 2>/dev/null | tail -1; docker --version; dcgmi discovery -l 2>/dev/null | head
free -h; numactl -H 2>/dev/null | grep -E 'available|size'                    # memory seen by the OS
ibdev2netdev 2>/dev/null; docker ps --format '{{.Names}}\t{{.Image}}'
```

## Decision flow

1. Fresh or unknown state: compare with `references/hardware-and-os.md`; update through the repository OTA path (`references/updating.md`).
2. More than one GPU in `nvidia-smi -L`: identify the GB300 index and pin it in every container (`--gpus '"device=N"'`). See `references/troubleshooting.md`.
3. Planning a model: weights in HBM (252 GB), overflow in LPDDR5X (496 GB, much slower). `references/memory-and-coherency.md`.
4. Choosing an engine or image: `references/combos/engines-on-station.md`, then the product skill. Images must be arm64 and CUDA 13 capable.
5. Two stations: cable per rail, MTU 9000, RoCEv2, validate before NCCL (`references/two-station-fabric.md`).
6. Remote or fleet management: BMC web UI and Redfish (`references/bmc-and-power.md`).
7. Anything failing: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Firmware and OS updates, kernel-module parameters, GRUB/ACS edits, netplan and services need approval and an undo path.
- **Do not reinstall the driver, CUDA or Docker on DGX OS.** They ship with it; verify instead.
- **Pin the GB300.** With an extra RTX PRO card installed, default GPU selection can pick the wrong device.
- **Keep CDMM, the default.** NVIDIA documents legacy NUMA mode as not recommended.
- **Budget HBM first.** Treat LPDDR5X as overflow, not as fast memory; UVM everywhere is slow.
- **Mind power.** NVIDIA lists 1,600 W total system power and a 20 A circuit.
- **Verify upstream.** Versions, tags and playbooks change; re-read NVIDIA's pages before quoting numbers.

## Workflows

- [ ] Baseline: run Discover; record DGX OS, driver, CUDA, kernel, GPU index -> `references/hardware-and-os.md`
- [ ] Memory plan: HBM vs LPDDR5X budget, CDMM check -> `references/memory-and-coherency.md`
- [ ] Pick engine and image -> `references/combos/engines-on-station.md`
- [ ] Out-of-band access and power -> `references/bmc-and-power.md`
- [ ] Second station: cabling, RoCE, GDR validation -> `references/two-station-fabric.md`
- [ ] Update -> `references/updating.md`
- [ ] Verify: `nvidia-smi` shows the GB300 and the pinned container sees only it, the model fits HBM with headroom, `ibdev2netdev` shows Up on both rails (two-station), BMC reachable.

## Reference index

- `references/hardware-and-os.md`: specs, supported OS, current software stack.
- `references/memory-and-coherency.md`: CDMM vs NUMA, HBM vs LPDDR5X, sizing.
- `references/bmc-and-power.md`: BMC, Redfish, DCGM, secure boot, power.
- `references/two-station-fabric.md`: two-station ConnectX-8 bring-up.
- `references/updating.md`: OTA updates, DGX OS 7 vs 8, recovery.
- `references/troubleshooting.md`: symptom to fix.
- `references/combos/engines-on-station.md`: engine and image matrix.

## Companion skills

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`: engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill <name>`.
- `nvidia-dgx-spark`: the small GB10 box. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-spark`.
- `self-hosted-llms`: gateway, exposure and catalog. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `llm-observability`: Prometheus, Grafana and DCGM. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
