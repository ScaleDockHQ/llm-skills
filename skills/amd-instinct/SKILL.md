---
name: amd-instinct
description: Set up, verify and operate AMD Instinct GPUs (MI300X, MI325X, MI350X, MI355X, MI250, MI210) with ROCm 10.x for LLM inference. Use for amdgpu driver and ROCm install, gfx942/gfx950 targets, /dev/kfd and render group errors, amd-smi (rocm-smi removed), vllm/vllm-openai-rocm containers, RCCL multi-GPU, SPX/CPX partitioning, health checks, ROCm updates, or choosing which engine and image runs on Instinct. Not for Ryzen AI Max (use amd-strix-halo) or NVIDIA.
license: MIT
compatibility: Linux x86_64 servers with AMD Instinct GPUs (Ubuntu, RHEL, SLES, Debian per the ROCm compatibility matrix); bash, docker, curl and jq. Driver, ROCm, kernel-argument, firmware and partitioning changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# AMD Instinct

Take an Instinct server from bare OS to a verified ROCm stack that serves LLMs: matching driver and firmware, GPU access, a container or wheel for the engine, a multi-GPU check, and a safe update path.

**Scope:** the platform. Engine flags and recipes belong to the product skills (`vllm`, `sglang`, `llama-cpp`); sizing belongs to `choosing-hardware`; the gateway and exposure stack belongs to `self-hosted-llms`. The author did not run these steps on Instinct hardware; every step comes from AMD and engine docs read on the date stamped in each reference.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
grep -E '^(NAME|VERSION)=' /etc/os-release; uname -r; cat /proc/cmdline
lspci -nn | grep -i -E 'instinct|processing accel'          # which MI part, how many
ls -l /dev/kfd /dev/dri/renderD* 2>&1; id -nG               # device nodes and your groups
dkms status 2>/dev/null | grep -i amdgpu; modinfo amdgpu 2>/dev/null | grep -E '^(version|srcversion)'
command -v amd-smi && amd-smi version && amd-smi list      # driver, ROCm and per-GPU IDs
command -v rocminfo && rocminfo | grep -E 'Name:\s+gfx' | sort -u   # gfx target seen by the runtime
amd-smi partition 2>/dev/null                               # compute/memory partition state
amd-smi static --gpu 0 2>/dev/null | head -40
sudo dmesg -T | grep -i amdgpu | grep -i -E 'error|fail' | tail   # driver errors
docker --version; docker ps --format '{{.Names}}\t{{.Image}}'
```

## Decision flow

1. Identify the part and its LLVM target (`gfx942` for MI300X, MI325X and MI300A; `gfx950` for MI350X, MI355X and MI350P; `gfx90a` for MI200; `gfx908` for MI100). Compare OS, kernel, `amdgpu` driver and firmware with the matrix in `references/hardware-and-stack.md`. A mismatch is the first thing to fix.
2. Nothing installed, or versions drifted: install the driver, then ROCm (`references/install.md`). Prefer a container for the engine and keep only the driver (and optionally ROCm tools) on the host.
3. GPUs not visible in a container, or `Permission denied` on `/dev/kfd`: `references/troubleshooting.md` (groups, device flags, `--ipc=host`).
4. Pick an engine and image: `references/containers-and-engines.md`, then the product skill.
5. More than one GPU: run the fabric checks before the model (`references/multi-gpu-and-partitioning.md`) and apply the MI350 RCCL workaround when it applies.
6. Hardware acceptance or a flaky node: `references/health-and-validation.md`.
7. Monitoring: `references/monitoring.md`. Updating: `references/updating.md`.

## Rules

- **Ask before changing the system.** Driver and ROCm installs, kernel arguments, firmware (PLDM bundle), partition changes, GPU resets and reboots need approval and an undo path.
- **Match driver, firmware and ROCm to the compatibility matrix.** AMD lists supported `amdgpu` driver and firmware bundle versions per series; run an unlisted combination only on purpose.
- **`amd-smi`, not `rocm-smi`.** ROCm SMI is deprecated and no longer built or installed by the standard ROCm 10.1 build.
- **The container carries ROCm user space.** The host must provide the kernel driver and expose `/dev/kfd` and `/dev/dri`; the host ROCm version need not equal the image's.
- **Do not trust CUDA-shaped flags.** `--gpu-memory-utilization`, `NCCL_*` and `CUDA_VISIBLE_DEVICES` have ROCm counterparts (`HIP_VISIBLE_DEVICES`, RCCL); confirm in the engine log and in the engine skill.
- **Never print tokens.** Pass `HF_TOKEN` with `-e HF_TOKEN` (no value) or from a `0600` env file.
- **Verify upstream.** ROCm releases move monthly and engine images follow; re-read the release notes and compatibility matrix before pinning.

## Workflows

- [ ] Baseline: run Discover; record OS, kernel, driver, firmware, ROCm, gfx target -> `references/hardware-and-stack.md`
- [ ] Install or align driver and ROCm -> `references/install.md`
- [ ] Container run: devices, groups, shm, pinned image tag -> `references/containers-and-engines.md`
- [ ] Multi-GPU: topology, RCCL test, partition mode -> `references/multi-gpu-and-partitioning.md`
- [ ] Acceptance or health check before production -> `references/health-and-validation.md`
- [ ] Monitoring with `amd-smi` -> `references/monitoring.md`
- [ ] Update ROCm or driver -> `references/updating.md`
- [ ] Verify: `amd-smi list` shows every GPU, the container sees them (`rocminfo` inside lists the right `gfx` name), the engine log names its ROCm attention backend, `/v1/models` answers, and an RCCL all-reduce passes on multi-GPU hosts.

## Reference index

- `references/hardware-and-stack.md`: parts and LLVM targets, supported OS/kernel/driver/firmware, ROCm 10.1.0 components, framework and engine versions.
- `references/install.md`: driver, apt/dnf/zypper packages, pip wheels, runfile, groups and udev, verification.
- `references/containers-and-engines.md`: `docker run` flags, vLLM, SGLang and llama.cpp images and wheels on Instinct.
- `references/multi-gpu-and-partitioning.md`: topology, RCCL, `NCCL_PROTO` workaround, compute and memory partition modes, SR-IOV.
- `references/health-and-validation.md`: boot arguments, health checks, ROCm Validation Suite, TransferBench, RCCL tests.
- `references/monitoring.md`: `amd-smi` commands and what to alert on.
- `references/updating.md`: release cadence, upgrade order, rollback.
- `references/troubleshooting.md`: symptom to fix, including ROCm 10.1.0 known issues.

## Companion skills

- `vllm`, `sglang`, `llama-cpp`: engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill <name>`.
- `choosing-hardware`: sizing and engine-to-hardware fit. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
- `multi-node-inference`: multi-node serving. Install: `npx skills add ScaleDockHQ/llms-skills --skill multi-node-inference`.
- `llm-observability`: Prometheus and Grafana. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
- `self-hosted-llms`: gateway, exposure and catalog on top. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
