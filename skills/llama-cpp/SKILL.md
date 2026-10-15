---
name: llama-cpp
description: Install, serve, tune and update llama.cpp (llama-server, llama-cli, llama-bench, llama-quantize) for GGUF models on Metal, CUDA, Vulkan, ROCm/HIP, SYCL or CPU. Use for -hf downloads, bNNNN builds, ghcr.io/ggml-org images, router mode, --jinja tool calls, mmproj vision, RPC multi-node, DGX Spark, Strix Halo, unknown model architecture errors, proxy EOF 502s. Not for Ollama or LM Studio.
license: MIT
compatibility: macOS, Linux (x64, arm64) and Windows; needs curl and jq for the discovery and benchmark commands. Installs, services, network exposure and large downloads need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# llama.cpp

Get a working, tuned and updatable `llama-server` (OpenAI- and Anthropic-compatible) for GGUF models on the user's hardware, and keep it healthy.

**Scope:** this one product: install, serve, tune, scale out (RPC), update, troubleshoot. Choosing between engines belongs to `choosing-inference-engine`.

Work through the steps in order. Load a reference only when a step names it. Flags below were verified on master build b11556 and the v0.6.0 release (2026-10-11). Builds move several times a day: confirm with `llama-server --help` on the installed binary.

## Discover first

Read-only; nothing here prints secrets.

```bash
# Installed binaries and build number (bNNNN)
command -v llama-server llama-cli llama-bench llama-quantize llama 2>/dev/null
llama-server --version 2>&1 | head -3
# Backends and devices the binary can see
llama-server --list-devices 2>&1 | head -20
# Hardware
uname -sm; nvidia-smi -L 2>/dev/null; rocminfo 2>/dev/null | grep -m3 gfx; vulkaninfo --summary 2>/dev/null | grep -m3 deviceName
sysctl -n machdep.cpu.brand_string hw.memsize 2>/dev/null; free -g 2>/dev/null | head -2
# Already running?
ss -ltnp 2>/dev/null | grep -E ':(9931|8080)\b'; curl -s http://127.0.0.1:9931/health
# Model cache used by -hf
llama-server --cache-list 2>&1 | head
```

## Decision flow

1. No binary: pick the install route for the platform in `references/install.md` (brew, winget, release archive, Docker image, or CMake build). Prefer a prebuilt package; build from source only for an unsupported backend or arch.
2. Apple silicon: Metal is on by default, `references/combos/apple-metal.md`. AMD Ryzen AI Max (Strix Halo): `references/combos/strix-halo-vulkan.md`. NVIDIA DGX Spark/GB10 and other arm64 CUDA: `references/install.md` (Docker `server-cuda13`).
3. Model choice: pick a GGUF and quant with `references/models-and-formats.md`; use `-hf <user>/<repo>[:quant]` to download.
4. Several models or swap-on-demand: built-in router mode, or llama-swap in front (`references/combos/llama-swap-router.md`). Never use both to swap the same models.
5. Does not fit in memory or too slow: `references/performance-tuning.md` (fit, KV types, MoE offload, batch sizes), then `references/parallelism-multinode.md` (multi-GPU, RPC).
6. Tools, reasoning, JSON, vision, embeddings, rerank, speculative decoding: `references/features.md`.
7. Failing: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules, `--host 0.0.0.0` and compiling on a host that is serving need approval and an undo path.
- **Secrets never touch output.** Use `--api-key-file` (a `0600` file) or `LLAMA_API_KEY`, and `HF_TOKEN` from the environment. `--api-key KEY` shows in `ps`.
- **Always pass `--host` and `--port` explicitly.** The default port is 9931 on master (since b11521); v0.6.0 and older used 8080. `/health` is public, so it proves nothing about auth.
- **Loopback by default.** Bind `127.0.0.1` unless a gateway or reverse proxy (see `llm-gateway`) fronts it. `--agent`, `--tools`, `--ui-mcp-proxy`, `--mcp-servers-*` are experimental and unsafe on untrusted networks. The RPC server is unauthenticated: private links only.
- **Pin what you run.** Record the build (`bNNNN`) or image digest; tags like `server-cuda13` move with every build.
- **Smoke-test after every update:** `/health`, one chat completion, one tool call, one reasoning request. Templates and parsers change often.
- **Verify upstream.** Flags and defaults change; `llama-server --help` is the authority for the installed binary. Do not copy flags from older blog posts (for example `--draft-max` was removed in favour of `--spec-draft-n-max`).

## Workflows

- [ ] Install -> `references/install.md`
- [ ] First serve and flags -> `references/serve-config.md`; run as a service with `templates/llama-server.service`, `templates/llama-server.launchd.plist` or `templates/docker-compose.yml`
- [ ] Choose model, quant, convert or quantize -> `references/models-and-formats.md`
- [ ] Tune speed and memory -> `references/performance-tuning.md`; measure with `llama-bench -m model.gguf -ngl 99 -fa on` (engine only) or `scripts/bench.sh` (end-to-end HTTP)
- [ ] Features: tools, reasoning, schema, vision, embeddings, speculative -> `references/features.md`
- [ ] API clients -> `references/api.md`; gateways, UIs, Kubernetes -> `references/integrations.md`
- [ ] Multi-GPU and RPC -> `references/parallelism-multinode.md`
- [ ] Metrics and logs -> `references/observability.md`
- [ ] Update -> `references/updating.md`
- [ ] Verify: `curl -s http://127.0.0.1:PORT/health` returns 200, `/v1/models` lists the alias, a chat completion returns text, and the startup log shows the expected backend (`ggml_cuda_init`, `ggml_vulkan`, Metal) with layers offloaded.

## Minimal serve

```bash
llama-server -hf ggml-org/gemma-3-4b-it-GGUF:Q4_K_M -c 32768 -ngl all -fa on \
  --host 127.0.0.1 --port 9931 -a local-model --api-key-file ~/.config/llama-server/keys
curl -s http://127.0.0.1:9931/health
```

Docker (NVIDIA, CUDA 13, amd64 and arm64):

```bash
docker run --rm --gpus all -p 127.0.0.1:8081:8080 -v /srv/models/gguf:/models:ro \
  ghcr.io/ggml-org/llama.cpp:server-cuda13 -m /models/model-Q4_K_M.gguf -a small \
  -c 32768 -ngl all -fa on -np 4 --host 0.0.0.0 --port 8080
```

## Reference index

- `references/install.md`: Homebrew, winget, conda, Nix, llama.app installer, release archives, Docker images, CMake builds per backend, aarch64/Blackwell/DGX Spark.
- `references/serve-config.md`: llama-server flags, `LLAMA_ARG_*` env vars, router mode and presets, auth, TLS, services.
- `references/models-and-formats.md`: GGUF, quant types, `-hf`, conversion, `llama-quantize`, imatrix, perplexity/KLD, LoRA.
- `references/parallelism-multinode.md`: split modes, tensor split, MoE CPU offload, RPC server across hosts.
- `references/features.md`: `--jinja` tools, reasoning, grammars and JSON schema, multimodal, embeddings and rerank, speculative decoding, slots, prompt cache.
- `references/api.md`: endpoints and request examples (OpenAI, Anthropic, native).
- `references/performance-tuning.md`: fit, context and slots, KV cache types, batch sizes, per-backend env vars, benchmarking.
- `references/integrations.md`: llama-swap, LiteLLM, OpenAI clients, Web UI, Kubernetes, editors.
- `references/observability.md`: `/metrics`, `/props`, `/slots`, logs.
- `references/updating.md`: update paths per install route, version pinning, rollback, smoke tests.
- `references/troubleshooting.md`: symptoms and fixes.
- `references/combos/apple-metal.md`, `references/combos/strix-halo-vulkan.md`, `references/combos/llama-swap-router.md`: verified combinations.
- `templates/`: systemd unit, launchd plist, docker-compose, Kubernetes manifest, router preset INI.
- `scripts/bench.sh`: end-to-end HTTP benchmark (shared canonical copy).

## Companion skills

- `choosing-inference-engine`: llama.cpp versus vLLM, SGLang, TensorRT-LLM. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-inference-engine`.
- `model-quantization`: GGUF versus AWQ/GPTQ/FP8 decisions. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `llm-gateway`: LiteLLM or another gateway in front of `llama-server`. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `local-llms`: laptop and desktop workflow (llama.cpp, Ollama, LM Studio). Install: `npx skills add ScaleDockHQ/llm-skills --skill local-llms`.
- `self-hosted-llms`: running engines on owned GPU servers. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `llama-swap`: model swapping proxy (planned). Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `nvidia-dgx-spark` and `amd-strix-halo`: platform notes (planned). Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`.
- `speculative-decoding` and `multi-node-inference`: cross-engine techniques (planned). Install: `npx skills add ScaleDockHQ/llm-skills --skill speculative-decoding`.
- `ollama`, `lm-studio`, `vllm`, `tailscale`, `cloudflare-tunnel`: neighbours. Install with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.
