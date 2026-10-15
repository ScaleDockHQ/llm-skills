---
name: nvidia-dgx-spark
description: Set up, size, network and operate NVIDIA DGX Spark (GB10 Grace Blackwell, 128 GB unified memory, DGX OS) for LLM inference, single or dual node over ConnectX-7. Use for DGX Spark, GB10, sm_121, DGX OS updates, unified memory OOM freezes, nvidia-smi Memory-Usage Not Supported, QSFP/netplan/NCCL clustering, NVIDIA Sync, DGX Dashboard, exec format error, or choosing which engine (vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama) and image tag runs on Spark.
license: MIT
compatibility: DGX Spark Founders Edition (DGX OS, arm64, CUDA 13) and GB10 partner systems; bash, ssh, docker, curl and jq. Updates, netplan changes, firmware, drop_caches and service installs need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA DGX Spark

Get a DGX Spark (or two) from first boot to a stable inference host: right software versions, memory plan, memory safety, cluster link, remote access and updates.

**Scope:** the platform. Engine flags and recipes belong to the product skills (`vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`); the full gateway and exposure stack belongs to `self-hosted-llms`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
uname -m; cat /etc/os-release | grep -E '^(NAME|VERSION)='; uname -r           # aarch64, DGX OS, kernel
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader               # GB10 and driver
nvcc --version 2>/dev/null | tail -1; docker --version
free -h; swapon --show; grep -E 'MemAvailable|SwapFree|HugePages_Total' /proc/meminfo
docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi >/dev/null && echo gpu-in-container-ok
ibdev2netdev 2>/dev/null                                                       # ConnectX-7 mapping and link state
systemctl is-active earlyoom docker; docker ps --format '{{.Names}}\t{{.Image}}'
```

## Decision flow

1. Fresh box or unknown state: compare with the known-good versions in `references/hardware-and-os.md`; update through DGX Dashboard (`references/updating.md`).
2. Choosing an engine or image: `references/combos/engines-on-spark.md`, then the product skill. An amd64-only image fails with `exec format error`; use arm64 or multi-arch tags built for CUDA 13 and `sm_121`.
3. Planning a model: budget weights + KV + overhead + headroom against 128 GB shared memory (`references/memory.md`). Prefer one node when it fits.
4. Freeze or OOM: install earlyoom and cap background jobs first (`references/memory.md`), then `references/troubleshooting.md`.
5. Two nodes: cable, netplan, SSH, NCCL test (`references/networking.md`, `references/combos/dual-node-cluster.md`).
6. Remote access: NVIDIA Sync, dashboard tunnel, Tailscale (`references/combos/remote-access.md`).
7. Host prep (Docker group, toolkit, service user, disks): `references/host-setup.md`.
8. Monitoring: `references/monitoring.md`.

## Rules

- **Ask before changing the system.** OS and firmware updates, netplan, services, `drop_caches` and package installs need approval and an undo path.
- **Do not reinstall the driver, CUDA or Docker on DGX OS.** They ship with it; verify instead.
- **`nvidia-smi` memory is not truth here.** It prints `Memory-Usage: Not Supported` on this iGPU (expected). Use `free -h` and `/proc/meminfo`.
- **Memory fractions are shares of the whole machine.** `--gpu-memory-utilization 0.90` style values starve the OS on unified memory.
- **Never build engines from source while serving.** A build can freeze the box.
- **Same images and paths on both nodes.** Compare image IDs, not tags.
- **Use the supplied 240 W power adapter.** Another adapter can reduce performance, block boot or cause shutdowns.
- **Verify upstream.** Versions, tags and playbook steps change monthly; re-read NVIDIA's release notes and playbooks.

## Workflows

- [ ] Baseline: run Discover; record DGX OS, driver, CUDA, kernel -> `references/hardware-and-os.md`
- [ ] Memory safety: earlyoom with `-s 100`, capped background jobs -> `references/memory.md`
- [ ] Host prep and service user -> `references/host-setup.md`
- [ ] Pick engine and image -> `references/combos/engines-on-spark.md`
- [ ] Second node: cable, netplan, SSH, NCCL test -> `references/networking.md`
- [ ] Remote access -> `references/combos/remote-access.md`
- [ ] Update (Dashboard, `apt`, `fwupdmgr`) -> `references/updating.md`
- [ ] Verify: GPU works in a container, `MemAvailable` has headroom with the model loaded, `ibdev2netdev` shows `Up`, NCCL `all_gather_perf` passes between nodes, earlyoom is active.

## Reference index

- `references/hardware-and-os.md`: specs, current DGX OS stack, power, UEFI, display memory.
- `references/memory.md`: unified memory behaviour, budget formula, earlyoom, capped jobs, drop_caches.
- `references/networking.md`: QSFP, interface names, netplan, SSH, NCCL, cluster sizes.
- `references/host-setup.md`: Docker, NVIDIA Container Toolkit, service user, disk layout, root-owned files.
- `references/monitoring.md`: DGX Dashboard, sparkDash, metrics that work on unified memory.
- `references/updating.md`: OS, firmware, recovery.
- `references/troubleshooting.md`: symptom to fix.
- `references/combos/engines-on-spark.md`: engine and image matrix.
- `references/combos/dual-node-cluster.md`: end-to-end two-node recipe and image drift.
- `references/combos/remote-access.md`: NVIDIA Sync, SSH tunnel, Tailscale.
- `templates/`: netplan, earlyoom defaults.

## Companion skills

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`: engines. Install: `npx skills add ScaleDockHQ/llm-skills --skill <name>`.
- `llama-swap`: model swapping on one or two nodes. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `self-hosted-llms`: gateway, exposure and catalog on top. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `llm-observability`: Prometheus, Grafana and DCGM. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
