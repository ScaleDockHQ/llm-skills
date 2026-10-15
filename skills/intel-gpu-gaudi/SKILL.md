---
name: intel-gpu-gaudi
description: Set up, verify and operate Intel accelerators for LLM inference, Gaudi 2 and 3 (Gaudi software 1.24.x, habana container runtime, vllm-gaudi plugin) and Intel GPUs (Arc, Arc Pro B-series, Data Center GPU with vLLM XPU, llama.cpp SYCL, OpenVINO). Use for hl-smi, habana runtime errors, vault.habana.ai images, vLLM on Gaudi or XPU, oneAPI and Level Zero setup, llm-scaler on Arc Pro B60/B70, or whether IPEX, IPEX-LLM or the HabanaAI vLLM fork are still usable (archived or end of life). Not for AMD or NVIDIA hardware.
license: MIT
compatibility: Linux hosts with Intel Gaudi 2/3 (Ubuntu 22.04/24.04, RHEL) or Intel Arc/Data Center GPUs; bash, docker, curl and jq. Driver, firmware, runtime, package and container installs need the user's explicit approval. The author did not run these steps on Intel hardware.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Intel GPU and Gaudi

Pick the right Intel path, check the host, and serve a model: Gaudi through the Gaudi software stack and the vllm-gaudi plugin, Intel GPUs through vLLM XPU, llama.cpp SYCL or OpenVINO.

**Scope:** the platform. Engine flags belong to `vllm` (install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`) and `llama-cpp`; sizing across hardware to `choosing-hardware`. Nothing here was run on Intel hardware; each reference states its sources and date.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
grep -E '^(NAME|VERSION)=' /etc/os-release; uname -r; free -h
lspci -nn | grep -i -E 'habana|gaudi|intel.*(vga|display|accel)'
# Gaudi
command -v hl-smi && hl-smi                       # each accelerator visible
dpkg -l | grep -i habana | awk '{print $2, $3}'   # firmware-tools, graph, rdma-core, thunk, container-runtime
docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -o habana
docker images --format '{{.Repository}}:{{.Tag}}' | grep -i -E 'habana|vllm|llm-scaler'
# Intel GPU
ls -l /dev/dri/ ; id -nG | tr ' ' '\n' | grep -E '^(render|video)$'
command -v sycl-ls && sycl-ls                     # after: source /opt/intel/oneapi/setvars.sh
command -v clinfo && clinfo -l; command -v xpu-smi && xpu-smi discovery
```

## Decision flow

1. Which device? Gaudi 2/3 (`hl-smi` works) goes to `references/gaudi.md`. Arc, Arc Pro or Data Center GPU (`/dev/dri`, `sycl-ls`) goes to `references/intel-gpu.md`.
2. Gaudi serving: use the vllm-gaudi plugin through the prebuilt containers. The HabanaAI vLLM fork reached end of life; do not start new work on it.
3. Intel GPU serving: vLLM XPU or `intel/llm-scaler-vllm` for batch serving on Arc Pro; llama.cpp SYCL for GGUF and single users; OpenVINO Model Server when the model is OpenVINO format.
4. Anything that mentions IPEX or IPEX-LLM: both are archived; read `references/status.md` before using them.
5. Errors: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Drivers, firmware, kernel arguments, Docker runtime registration and package installs need approval and an undo path.
- **Archived is not supported.** `intel/ipex-llm` and `intel/intel-extension-for-pytorch` are archived: no fixes, no patches, and Intel notes known security issues. Do not recommend them for new deployments; point to upstream PyTorch XPU, vLLM, llama.cpp or OpenVINO.
- **Match versions.** A vllm-gaudi plugin release is tied to a Gaudi software version and a vLLM version; take the combination from the release notes, not from memory.
- **Gaudi containers need the habana runtime.** `--runtime=habana`, `HABANA_VISIBLE_DEVICES`, `--cap-add=sys_nice`, and `--ipc=host` for multi-card runs.
- **Disable mmap on shared hosts.** llama.cpp mmap loading can leak data across tenants (Intel's own warning); use `--no-mmap`.
- **Never print tokens.** Pass `HF_TOKEN` with `-e HF_TOKEN`, not a literal value.
- **Verify upstream.** Image tags, plugin versions and driver guidance change monthly.

## Workflows

- [ ] Baseline: run Discover, record OS, kernel, device, driver or Gaudi software version
- [ ] Gaudi: driver and runtime check, pull the vault image, run vllm-gaudi -> `references/gaudi.md`
- [ ] Intel GPU: driver, render group, oneAPI check, engine choice -> `references/intel-gpu.md`
- [ ] Legacy stack found (IPEX, IPEX-LLM, vLLM fork): plan migration -> `references/status.md`
- [ ] Verify: `hl-smi` or `sycl-ls` lists every device, the server logs the device it uses, one chat request returns, and device memory is below the limit while serving

## Reference index

- `references/gaudi.md`: Gaudi software 1.24.2, runtime registration, vault images, vllm-gaudi quickstart, requirements.
- `references/intel-gpu.md`: drivers, vLLM XPU wheels and image, llm-scaler, llama.cpp SYCL, OpenVINO Model Server.
- `references/status.md`: what is archived, end of life or current.
- `references/troubleshooting.md`: symptom to fix.

## Companion skills

- `vllm`: flags and serving. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `llama-cpp`: GGUF serving and builds. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `choosing-hardware`: compare Intel with other hardware. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
- `self-hosted-llms`: gateway and exposure on top. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
