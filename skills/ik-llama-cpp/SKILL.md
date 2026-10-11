---
name: ik-llama-cpp
description: Builds, serves and tunes ik_llama.cpp, the llama.cpp fork with faster CPU and hybrid CPU/GPU MoE inference, IQK/trellis quants and split-mode graph. Use for ik_llama.cpp, ik-llama-cpp, ikawrakow, IQ4_KS, IQ2_KT, IQ4_KSS, -rtr, -fmoe, -ot, --n-cpu-moe, --fit, -sm graph, -mla, -ser, ghcr.io/ikawrakow/ik-llama-cpp, DeepSeek/GLM/Qwen MoE with experts in RAM. Mainline llama.cpp goes to llama-cpp.
license: MIT
compatibility: Linux, Windows or macOS with a C++ toolchain and CMake; fully supported backends are CPU (AVX2/ARM_NEON or better) and NVIDIA CUDA (Turing or newer); curl and jq. Building, installing, services and exposing a port need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# ik_llama.cpp

Run GGUF models with ik_llama.cpp (Iwan Kawrakow's llama.cpp fork, MIT): extra SOTA quant types, faster CPU prompt processing, hybrid CPU/GPU inference for huge MoE models, graph split mode for multi-GPU, and an OpenAI-compatible `llama-server`.

**Scope:** this one product: build or pull, serve, tune, scale out, update, troubleshoot. Mainline llama.cpp belongs to `llama-cpp`; choosing between engines belongs to `choosing-inference-engine`. The fork last synced with upstream llama.cpp in August 2024, so flags and quants differ from mainline and some mainline GGUFs behave differently.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
uname -sm; nproc; free -g 2>/dev/null | sed -n 1,2p          # RAM and cores decide MoE offload plans
lscpu 2>/dev/null | grep -E 'Model name|Flags' | grep -oE 'Model name.*|avx2|avx512[a-z_0-9]*|avx_vnni|amx[a-z_0-9]*' | sort -u
nvidia-smi --query-gpu=index,name,compute_cap,memory.total,memory.used --format=csv 2>&1
nvidia-smi topo -p2p r 2>/dev/null | head -12                 # P2P matters for -sm graph
cmake --version | head -1; command -v nvcc && nvcc --version | tail -1
ls ~/ik_llama.cpp/build/bin/llama-server 2>&1; git -C ~/ik_llama.cpp rev-parse --short HEAD 2>&1
~/ik_llama.cpp/build/bin/llama-server --version 2>&1 | head -3
docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | grep -i ik-llama
ss -ltnp 2>/dev/null | grep -E ':8080\b|:9292\b'
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/health
```

## Decision flow

1. **Is this the right engine?** Choose ik_llama.cpp for CPU-only or hybrid CPU/GPU inference of large MoE models (experts in RAM, attention on GPU), for its IQK/trellis quants (`IQ4_KS`, `IQ2_KL`, `IQ3_KT`...), or for multi-GPU `-sm graph`. Use `llama-cpp` for the broadest backend support (Metal, ROCm, Vulkan), `vllm`/`sglang` for high concurrency.
2. **Which backend?** Only CPU (AVX2 or better, ARM_NEON) and CUDA (Turing or newer) are fully functional. ROCm, Vulkan, Metal, old NVIDIA and AVX-only CPUs are unsupported upstream; do not file issues for them. Say so before the user invests in building there.
3. **Install path** (`references/install.md`): prebuilt `ghcr.io/ikawrakow/ik-llama-cpp` images (`cpu-*`, `cu12-*`) or a CMake build. There are no tagged releases, so pin a commit SHA.
4. **Which quant?** Prefer an IQK quant from a publisher that targets ik_llama.cpp. Avoid Unsloth `_XL` files that contain f16 tensors and mainline GGUFs of quant types ik does not know (`references/models-and-formats.md`).
5. **Fit the model.** Dense and fits in VRAM: `-ngl 999`. MoE bigger than VRAM: `-ngl 999` plus `--cpu-moe`, `--n-cpu-moe N` or `-ot` for expert tensors, or `--fit` (`references/parallelism-multinode.md`). Do **not** use `-rtr` when experts are partly on CPU and a GPU does prompt processing.
6. **Serve** `llama-server` on loopback with `--jinja`, `-a` alias and `--api-key` from a file or env (`references/serve-config.md`).
7. **Tune** KV cache type, Hadamard, batch sizes, speculative decoding, MTP (`references/performance-tuning.md`), and run a quality check after changing quants or cache types.
8. **Broken?** `references/troubleshooting.md`, then `llama-server --help` of your build and upstream issues.

## Rules

- **Ask before changing the system.** Builds, installs, services, firewall rules and exposure need approval and an undo path. CUDA builds are heavy: set `-j` to what the RAM allows.
- **Secrets never touch output.** Keep `--api-key` values and Hugging Face tokens in `0600` files or env vars, never in logged command lines. Use `--api-key-file FNAME` (listed in the server README; confirm in `llama-server --help`) instead of `--api-key KEY`, which shows in `ps`.
- **Loopback by default.** `--host` defaults to `127.0.0.1`; `0.0.0.0` only behind a firewall or proxy. Upstream says never expose the server to the Internet.
- **No `-rtr` on hybrid MoE.** It repacks all RAM tensors to row-interleaved types, many with no CUDA kernel, so matmuls stay on CPU and prompt processing slows.
- **The README flags the backends.** Do not promise ROCm, Vulkan or Metal performance.
- **Pin and record the commit.** There are no releases; record `git rev-parse HEAD` or the image digest before updating, and keep the previous binary.
- **Verify upstream.** Flags move fast. Confirm with `llama-server --help` from the build you run; this skill was verified against main at `89bba35c` on 2026-10-11.
- **Quality gate** after any quant, KV cache type, `-ser` or speculative change.

## Workflows

- [ ] Install: image or CMake (CPU, CUDA, AVX-512 flags) -> `references/install.md`
- [ ] Get a GGUF: Hugging Face download, split files, imatrix quants -> `references/models-and-formats.md`
- [ ] Serve: core flags and a first command -> `references/serve-config.md`, `templates/`
- [ ] Smoke test: `/health`, `/v1/models`, one chat completion -> `references/api.md`
- [ ] Hybrid CPU/GPU, multi-GPU, RPC -> `references/parallelism-multinode.md`
- [ ] Tools, reasoning, vision, structured output, LoRA -> `references/features.md`
- [ ] Throughput and memory -> `references/performance-tuning.md`
- [ ] llama-swap, LiteLLM, clients -> `references/integrations.md`, `references/combos/llama-swap.md`
- [ ] Metrics, slots, logs -> `references/observability.md`
- [ ] Update or roll back -> `references/updating.md`
- [ ] Verify: `/health` is 200, a chat completion returns text, startup log shows the expected offload and `nvidia-smi` shows expected VRAM.

## Quick smoke test

```bash
# KEY comes from a 0600 file or env var; never echo it
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H "Authorization: Bearer $IK_LLAMA_API_KEY" -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

Drop the header if the server runs without `--api-key` on loopback.

## Reference index

- `references/install.md`: prebuilt images, CMake for CPU, CUDA and AVX-512, Windows, Docker bake.
- `references/serve-config.md`: `llama-server` flags, defaults and env vars worth knowing.
- `references/models-and-formats.md`: IQK, trellis and legacy quants, imatrix, compatibility, split GGUFs.
- `references/parallelism-multinode.md`: `--fit`, `-ot`, `--cpu-moe`, `-sm graph`, `-ts`, RPC.
- `references/features.md`: jinja, tool calls, reasoning, vision, speculative, MTP, LoRA, prompt cache.
- `references/api.md`: endpoints including `/v1/responses`, slots and LoRA adapters.
- `references/performance-tuning.md`: KV cache quant, Hadamard, `-fmoe`, `-ser`, `-mla`, batch sizes.
- `references/integrations.md`: llama-swap, LiteLLM, OpenAI clients, Open WebUI, containers.
- `references/observability.md`: health, `--metrics`, slots, logging.
- `references/updating.md`: pin, rebuild, roll back.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/llama-swap.md`: the upstream `swap` image and a config.
- `templates/`: `docker-compose.yml`, `ik-llama.service`, `llama-swap.yaml`.

## Companion skills

- `llama-cpp`: mainline llama.cpp and GGUF basics. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `choosing-inference-engine`: compare engines. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `llama-swap`: model swapping in front of `llama-server`. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.
- `litellm`: gateway and keys. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `self-hosted-llms`: the end-to-end stack. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `model-quantization`: choosing a quantization. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
