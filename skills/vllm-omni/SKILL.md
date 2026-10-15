---
name: vllm-omni
description: Install and serve vLLM-Omni, vLLM's omni-modality extension for image, video, speech and audio generation plus Qwen-Omni style chat (`vllm serve MODEL --omni`, vllm/vllm-omni). Use for Qwen-Image, Z-Image, Wan2.2, LTX, Qwen3-TTS or Qwen3-Omni serving, /v1/images/generations, /v1/videos, /v1/audio/speech, stage configs, offload, parallelism, quantization, OOM or version-mismatch errors. Not for text-only vLLM (use vllm).
license: MIT
compatibility: Linux only, Python 3.12, NVIDIA (CC 7.0+), AMD ROCm or Intel XPU GPUs, uv or Docker, curl and jq. Installs, containers, model downloads, bind or exposure beyond loopback and sleep or wakeup calls need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# vLLM-Omni

Serves diffusion image and video models, TTS and audio generators and omni (text, image, audio, video in and out)
models behind OpenAI-style HTTP routes, using the vLLM engine. Verified against vLLM-Omni v0.30.0 (2026-10-11).

**Scope:** vLLM-Omni only: install, serve, tune, call, update, troubleshoot. Text-only LLM serving is the `vllm`
skill. Choosing between image engines is `self-hosted-genmedia`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
command -v vllm && vllm --version
pip list 2>/dev/null | grep -Ei '^(vllm|vllm-omni|torch|diffusers)\b' || true
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -Ei 'vllm-omni' || true
python3 --version; uname -m
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv 2>/dev/null
rocm-smi --showproductname 2>/dev/null | head -5
df -h "${HF_HOME:-$HOME/.cache/huggingface}" | tail -1; free -h | head -2
ss -ltnp 2>/dev/null | grep -E ':(8091|8000)\b' || true
curl -s -m 3 http://127.0.0.1:8091/health -o /dev/null -w 'health %{http_code}\n'
curl -s -m 3 http://127.0.0.1:8091/v1/models | jq '.data[].id'
```

## Decision flow

1. **No install yet** -> `references/install.md`. Linux and Python 3.12 only. vLLM and vLLM-Omni must share the
   same major.minor version (a mismatch warns on import).
2. **Pick the model and check it is supported** -> `references/models-and-api.md`. Each server hosts exactly one
   model, and an endpoint works only if that model supports the task.
3. **Does it fit?** Diffusion DiTs are large. Offload, tensor or sequence parallelism, quantization and sleep mode
   are in `references/performance-memory.md`. Multi-stage omni models set `gpu_memory_utilization` per stage.
4. **Serve** with `vllm serve MODEL --omni --host 127.0.0.1 --port 8091`. Add a model's deploy config or
   recipe flags when its guide gives them (`references/serving-and-stages.md`).
5. **Verify**: `/health`, `/v1/models`, then one small request on the task endpoint (`references/models-and-api.md`).
6. **Expose** only behind authentication (`--api-key` or a gateway), and tell the user what is reachable.

## Rules

- **Ask before changing the system.** Installs, Docker runs, model downloads (tens of GB), bind changes and
  exposure need approval and an undo path.
- **Bind loopback.** The vLLM server binds all interfaces by default. Use `--host 127.0.0.1` and, when exposing,
  `--api-key` read from a `0600` file plus HTTPS at a proxy. There is no per-user quota or rate limit.
- **Secrets never touch output.** `HF_TOKEN` and API keys come from environment variables or `0600` files.
- **Versions come from upstream.** Match vLLM and vLLM-Omni, pin both, and re-read the model's own guide:
  support differs per model, task and GPU vendor.
- **Long jobs.** Large image and video models take minutes: use `POST /v1/videos` (async) not `/v1/videos/sync`,
  and long client timeouts.
- **Not every route works.** Unsupported tasks return an OpenAI-style error; do not assume feature parity.

## Workflows

- [ ] Fresh environment, install vLLM then vLLM-Omni, same version -> `references/install.md`
- [ ] Choose a supported model, check VRAM -> `references/models-and-api.md`, `references/performance-memory.md`
- [ ] Serve on loopback, wait for `/health` -> `references/serving-and-stages.md`
- [ ] One request per task endpoint -> `references/models-and-api.md`
- [ ] Tune memory and speed, one flag at a time -> `references/performance-memory.md`
- [ ] Update with matching versions -> `references/updating.md`
- [ ] Verify: `/v1/models` lists the model, one image (or video job) completes and downloads, no OOM in the log.

## Reference index

- `references/install.md`: requirements, uv install per vendor, pre-built wheels versus source, Docker images, version pairing.
- `references/models-and-api.md`: supported model families, endpoint table, request fields and examples, auth.
- `references/serving-and-stages.md`: `vllm serve --omni` flags, deploy configs, multi-stage launch, execution modes, API frontends.
- `references/performance-memory.md`: offload, parallelism, cache backends, LoRA, quantization, sleep mode, memory fractions.
- `references/updating.md`: version pairing, upgrade and rollback.
- `references/troubleshooting.md`: symptom to fix table.

## Companion skills

- `vllm`: the text-only engine this builds on. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `self-hosted-genmedia`: choose between vLLM-Omni, ComfyUI, sd-server, diffusers and InvokeAI. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `comfyui`: node UI that can call vLLM-Omni through a custom node. Install: `npx skills add ScaleDockHQ/llm-skills --skill comfyui`.
- `hugging-face`: tokens, gated repos and cache. Install: `npx skills add ScaleDockHQ/llm-skills --skill hugging-face`.
- `litellm`: gateway in front of OpenAI-style routes. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
