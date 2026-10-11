---
name: sglang-diffusion
description: Install and serve SGLang Diffusion, SGLang's image and video generation runtime (`sglang generate`, `sglang serve`, `sglang[diffusion]`, multimodal_gen). Use for FLUX, Qwen-Image, Z-Image, Wan2.x, LTX or HunyuanVideo serving, /v1/images/generations and /v1/videos, offload, SP, TP and CFG parallelism, Cache-DiT, Prometheus metrics or OOM errors. Not for text LLM serving (use sglang) or ComfyUI.
license: MIT
compatibility: Linux with NVIDIA GPUs (also AMD ROCm, Intel XPU, Ascend, Moore Threads, Apple MPS), Python 3.10+ with uv, or Docker, curl and jq. Installs, containers, model downloads, bind or exposure beyond loopback and LoRA or control calls need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# SGLang Diffusion

Runs diffusion image and video models with the SGLang stack: one-off `sglang generate` jobs or a persistent
`sglang serve` HTTP server with OpenAI-style image and video routes. Verified against SGLang v0.5.21 (2026-10-11).

**Scope:** the diffusion runtime only: install, serve, tune, call, update, troubleshoot. Text LLM serving is the
`sglang` skill. Choosing an image engine is `self-hosted-genmedia`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
command -v sglang && pip show sglang 2>/dev/null | sed -n '1,2p'
pip list 2>/dev/null | grep -Ei '^(sglang|sgl-kernel|diffusers|torch|cache-dit)\b' || true
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -i sglang || true
python3 --version; uname -m
nvidia-smi --query-gpu=index,name,memory.total,memory.used,driver_version --format=csv 2>/dev/null
rocm-smi --showproductname 2>/dev/null | head -5
df -h "${HF_HOME:-$HOME/.cache/huggingface}" | tail -1; free -h | head -2
ss -ltnp 2>/dev/null | grep -E ':(30000|30010)\b' || true
curl -s -m 3 http://127.0.0.1:30000/health -o /dev/null -w 'health %{http_code}\n'
curl -s -m 3 http://127.0.0.1:30000/v1/models | jq '.data[] | {id, task_type, supported_task_types, num_gpus}'
```

## Decision flow

1. **No install yet** -> `references/install.md`: `uv pip install "sglang[diffusion]" --prerelease=allow` or Docker.
2. **Pick a model** from the registry-backed list in `references/models-and-api.md` and open its cookbook for the
   launch recipe; a model outside the registry may need `--model-id` or an overlay repo.
3. **Does it fit?** Use `--performance-mode auto` first. Then offload, parallelism, quantization
   (`references/performance-memory.md`). Check the least-free GPU, not the average.
4. **Serve**: `sglang serve --model-path M --port 30010` (binds `127.0.0.1` by default). Wait for `/health` to be 200.
5. **Verify** with `GET /v1/models`, then one image or video request (`references/models-and-api.md`).
6. **Exposure**: the diffusion server has no API key option (the docs' `Authorization` headers are examples) and CORS
   allows every origin. Put it behind an authenticating gateway. Details in `references/serving-and-ops.md`.

## Rules

- **Ask before changing the system.** Installs, Docker runs, model downloads (tens of GB), bind changes and exposure
  need approval and an undo path.
- **Loopback and a gateway.** The default bind is `127.0.0.1`. Keep it, or add TLS and authentication in front. No
  built-in auth or rate limit; LoRA and other control routes are open to any caller that can reach the port.
- **Secrets never touch output.** `HF_TOKEN` and S3 keys live in environment variables or `0600` files.
- **`--help` is the source of truth.** The docs say `sglang generate --help` and `sglang serve --help` list every flag; flags move between releases.
- **One lever at a time.** Measure with a fixed prompt, seed and size; lossy options (caches, `--quality high`,
  quantization) change output.
- **Long jobs.** Video takes minutes; use client timeouts and poll `/v1/videos`.

## Workflows

- [ ] Install in a fresh venv or pull a pinned image -> `references/install.md`
- [ ] Pick a model and a recipe, check VRAM -> `references/models-and-api.md`, `references/performance-memory.md`
- [ ] One `sglang generate` smoke test, then `sglang serve` on loopback -> `references/serving-and-ops.md`
- [ ] One request per task, poll video jobs -> `references/models-and-api.md`
- [ ] Add metrics, health probes, a gateway -> `references/serving-and-ops.md`
- [ ] Update with a pinned version -> `references/updating.md`
- [ ] Verify: `/health` 200, `/v1/models` lists the model, an output file decodes, no OOM in the log.

## Reference index

- `references/install.md`: pip or uv, source, Docker tags, ROCm, XPU, NPU, MUSA and MPS notes.
- `references/models-and-api.md`: model families, endpoints, request fields, LoRA routes, ComfyUI plugin.
- `references/performance-memory.md`: performance modes, offload, parallelism, caches, quantization, batching, quality tiers.
- `references/serving-and-ops.md`: serve flags, config files, health, metrics, logging, storage, disaggregation, security.
- `references/updating.md`: pinning and upgrades.
- `references/troubleshooting.md`: symptom to fix table.

## Companion skills

- `sglang`: the LLM runtime in the same project. Install: `npx skills add ScaleDockHQ/llms-skills --skill sglang`.
- `self-hosted-genmedia`: choose between SGLang Diffusion, vLLM-Omni, ComfyUI, sd-server and diffusers. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-genmedia`.
- `comfyui`: node UI; SGLang ships a plugin for it. Install: `npx skills add ScaleDockHQ/llms-skills --skill comfyui`.
- `hugging-face`: tokens, gated repos and cache. Install: `npx skills add ScaleDockHQ/llms-skills --skill hugging-face`.
- `caddy`: TLS and auth in front. Install: `npx skills add ScaleDockHQ/llms-skills --skill caddy`.
