---
name: nvidia-rtx-workstation
description: Choose, size and run NVIDIA RTX PRO Blackwell workstation GPUs (6000 96 GB, 5000, 4500, 4000; Max-Q) and RTX desktop cards for local LLM inference on Linux. Use for RTX PRO 6000, Max-Q vs 600 W, nvidia-open driver "No devices were found", sm_120 builds, multi-GPU PCIe without NVLink, MIG on RTX PRO, power and cooling in a tower, or picking engine and VRAM per model. For DGX Station use nvidia-dgx-station.
license: MIT
compatibility: Linux x86_64 workstation with an RTX PRO Blackwell or RTX Blackwell GPU; bash, docker, curl and jq. Driver installs, kernel-module switches, MIG changes, power limits and BIOS changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA RTX workstation GPUs

Pick the right RTX PRO card, install the correct driver stack, and get stable multi-GPU local inference on a tower workstation.

**Scope:** the platform (cards, driver, CUDA, power, multi-GPU, MIG). Engine flags belong to `vllm`, `llama-cpp`, `ollama`, `sglang`, `exllamav3`. Arithmetic for VRAM sizing is in `choosing-hardware`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
lspci -nn | grep -i nvidia                                                       # cards seen on PCIe
nvidia-smi --query-gpu=index,name,memory.total,power.limit,pcie.link.gen.current,pcie.link.width.current,compute_cap --format=csv
nvidia-smi topo -m                                                               # PCIe/NVLink topology between GPUs
cat /proc/driver/nvidia/version; modinfo nvidia 2>/dev/null | grep -E '^(license|version)'   # "Dual MIT/GPL" = open modules
nvcc --version 2>/dev/null | tail -1; docker --version; nvidia-smi -q | grep -iE 'MIG Mode|Persistence'
```

## Decision flow

1. Choosing a card: `references/cards.md`. VRAM and bandwidth decide model size and decode speed; power and slot width decide how many fit.
2. `nvidia-smi` shows no devices or the GPU is "unsupported": Blackwell needs the open kernel modules (`references/driver-and-cuda.md`).
3. Build or image fails with unknown arch: compute capability 12.0, `sm_120`; use CUDA 12.8 or newer or a Blackwell image (`references/driver-and-cuda.md`).
4. More than one card: PCIe topology, power, thermals, tensor-parallel caveats (`references/multi-gpu-power-cooling.md`).
5. Sharing one big card between services: MIG (`references/multi-gpu-power-cooling.md`).
6. Engine choice and image: `references/combos/engines-on-rtx-pro.md`.

## Rules

- **Ask before changing the system.** Driver or module swaps, MIG mode, power limits and BIOS settings need approval and an undo path.
- **Blackwell requires `nvidia-open`.** The proprietary kernel modules do not support Blackwell.
- **Do not guess VRAM fit.** Compute weights + KV + overhead, then leave headroom.
- **Mind the PSU and slot.** The 6000 Workstation Edition is a 600 W card; the Max-Q is 300 W. Check connector, PSU and airflow before buying more cards.
- **Pin versions.** Engines and PyTorch wheels lag new architectures; confirm sm_120 support.
- **Verify upstream.** Specs and driver branches change; re-read NVIDIA pages.

## Workflows

- [ ] Baseline: run Discover; record cards, driver, CUDA -> `references/driver-and-cuda.md`
- [ ] Card and VRAM choice -> `references/cards.md`
- [ ] Driver on open modules, persistence mode -> `references/driver-and-cuda.md`
- [ ] Multi-GPU layout, power and cooling -> `references/multi-gpu-power-cooling.md`
- [ ] Pick engine and image -> `references/combos/engines-on-rtx-pro.md`
- [ ] Verify: `nvidia-smi` lists every card at the expected PCIe gen and width, a container sees the GPUs, a model loads with VRAM headroom, power draw stays within the PSU budget under load.

## Reference index

- `references/cards.md`: RTX PRO Blackwell lineup, memory, bandwidth, power.
- `references/driver-and-cuda.md`: open modules, driver branches, CUDA, sm_120.
- `references/multi-gpu-power-cooling.md`: PCIe topology, tensor parallel, power limits, MIG.
- `references/troubleshooting.md`: symptom to fix.
- `references/combos/engines-on-rtx-pro.md`: engine matrix.

## Companion skills

- `choosing-hardware`: VRAM sizing math. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
- `vllm`, `llama-cpp`, `ollama`, `sglang`, `exllamav3`: engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill <name>`.
- `nvidia-dgx-station`: GB300 desktop. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-station`.
- `llm-observability`: DCGM and Grafana. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
