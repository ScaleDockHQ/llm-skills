---
name: stable-diffusion-cpp
description: Install, run and serve stable-diffusion.cpp, the ggml C/C++ engine for image and video diffusion (SD, SDXL, FLUX, Qwen-Image, Z-Image, Wan) with sd-cli and the sd-server HTTP API. Use for sd-cli/sd-server flags, GGUF conversion and quantization, --offload-to-cpu/--vae-tiling/--diffusion-fa, OpenAI /v1/images/generations, /sdcpp/v1/img_gen jobs, black or NaN images, ghcr.io/leejet/stable-diffusion.cpp images, or sd-server behind llama-swap and LiteLLM. Not for ComfyUI or diffusers.
license: MIT
compatibility: Linux, macOS (Metal) and Windows; CPU, CUDA, Vulkan, ROCm, SYCL; curl and jq for the API commands, cmake and a C++ toolchain for source builds. Installs, builds, large model downloads and binding beyond loopback need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# stable-diffusion.cpp

Get a working, memory-safe `sd-cli` or `sd-server` for image or video diffusion with no Python stack, and keep it updatable.

**Scope:** this one product: install or build, weights and GGUF, `sd-server` and its three APIs, memory tuning, update, troubleshoot, and its llama-swap plus LiteLLM combo. Choosing between ComfyUI, sd.cpp and diffusers, licences and the wider media stack belong to `self-hosted-genmedia`. Version facts were verified on master-956-1b0ba10 (2026-10-11); the project warns that "API and command-line option may change frequently".

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
# Binaries, version, devices
command -v sd-cli sd-server; sd-server --help 2>&1 | head -2   # first line prints the commit
sd-server --list-devices 2>/dev/null                           # names accepted by --backend
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null
# Running server (default 127.0.0.1:1234)
curl -fsS 127.0.0.1:1234/v1/models | jq .
curl -fsS 127.0.0.1:1234/sdcpp/v1/capabilities | jq '{model, supported_modes}'
ps -eo args | grep -E '[s]d-server'
docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -i stable-diffusion
df -h ~ | tail -1; ls -lh ~/models/sd 2>/dev/null
```

## Decision flow

1. No binary yet: pick a release zip, a container image or a CMake build (`references/install.md`). Linux has no prebuilt CUDA or arm64 zip, so NVIDIA Linux and DGX Spark use the image or a build.
2. Weights: single checkpoint (`-m`) or split diffusion model, VAE and text encoder; GGUF to save memory (`references/models-and-weights.md`).
3. One-off image or video: `sd-cli` (`references/models-and-weights.md` has a first command).
4. Programs need an endpoint: `sd-server` (`references/serve-and-api.md`). OpenAI clients use `/v1/images/generations`; long or video jobs use the async `/sdcpp/v1/*` API.
5. Out of memory or slow: `references/performance-memory.md`.
6. Shared GPU with LLMs: llama-swap swaps it like an LLM (`references/combos/llama-swap-litellm.md`).
7. Upgrading: `references/updating.md`. Black images, load errors, 524s: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, builds, services, image pulls, model downloads and any bind beyond `127.0.0.1` need approval and an undo path.
- **Loopback only.** `sd-server` has no authentication and defaults to `127.0.0.1:1234`. `--listen-ip 0.0.0.0` exposes the UI and API; put a proxy with keys in front (`llm-gateway`, `litellm`).
- **The server is one model, one process.** The model is fixed at start; switching means a restart (or llama-swap).
- **LoRA is structured on the server.** `<lora:...>` prompt tags work in `sd-cli` but are intentionally unsupported by every server API; send the `lora` array (`references/serve-and-api.md`).
- **Match component files to the architecture.** A wrong text encoder or VAE fails at load or gives garbage; read the model's page under upstream `docs/`.
- **Pin versions.** Release and image tags named `master-*` move; record the commit that works.
- **Secrets stay out of output.** Hugging Face tokens come from `HF_TOKEN` or a `0600` file, never from echoed commands.
- **Verify upstream.** Flags change often; check `sd-server --help` on the installed build.

## Workflows

- [ ] Install a build -> `references/install.md`
- [ ] Download weights, optionally convert to GGUF -> `references/models-and-weights.md`
- [ ] Smoke test with `sd-cli`: fixed seed, small size, then open the PNG
- [ ] Start `sd-server` on loopback and call `/v1/models` -> `references/serve-and-api.md`
- [ ] Generate through OpenAI or native API and decode the base64 result -> `references/serve-and-api.md`
- [ ] Fit memory (flash attention, VAE tiling, offload) -> `references/performance-memory.md`
- [ ] Put it behind llama-swap and LiteLLM -> `references/combos/llama-swap-litellm.md`
- [ ] Update and regression-check with one fixed-seed image -> `references/updating.md`
- [ ] Verify: the server answers `/v1/models` only after the model loaded, one generation returns an image that `file` recognises, and VRAM returns after the process stops.

## Reference index

- `references/install.md`: release zips, container images and tags, CMake backends, DGX Spark, macOS.
- `references/models-and-weights.md`: supported families, component files, GGUF convert and `--type`, LoRA, first `sd-cli` commands.
- `references/serve-and-api.md`: `sd-server` flags, OpenAI, WebUI and native APIs, job polling, `sd_cpp_extra_args`, timeouts.
- `references/performance-memory.md`: flash attention, VAE tiling, params backend, offload, multi-GPU, caching modes.
- `references/updating.md`: rebuild or re-pull, pin, regression check, config drift.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/llama-swap-litellm.md`: native, container and llama-swap entries, LiteLLM image route, Cloudflare limits.

## Companion skills

- `self-hosted-genmedia`: choose between ComfyUI, sd-server and speech servers; memory planning next to LLMs. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-genmedia`.
- `comfyui`: node-graph workflows and a richer API. Install: `npx skills add ScaleDockHQ/llms-skills --skill comfyui`.
- `llama-swap`: hot-swap sd-server with LLMs. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.
- `litellm`: keys, budgets and routing in front. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `hugging-face`: fetch weights and manage the cache. Install: `npx skills add ScaleDockHQ/llms-skills --skill hugging-face`.
- `nvidia-dgx-spark`: arm64 unified-memory notes. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-spark`.
