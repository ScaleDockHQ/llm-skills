---
name: comfyui
description: Install, run headless and operate ComfyUI, the node-graph engine for image, video and audio diffusion models (FLUX, SDXL, Wan, LTX), with its HTTP API, custom nodes and model folders. Use for python main.py --listen/--port, workflow_api.json, /prompt and /history, comfy-cli, ComfyUI-Manager, extra_model_paths.yaml, --lowvram/--reserve-vram, "Torch not compiled with CUDA", missing nodes, 403 origin errors, or putting ComfyUI behind llama-swap. Not for sd-server.
license: MIT
compatibility: Linux, macOS (Apple silicon) and Windows; NVIDIA, AMD, Intel or CPU; Python 3.13 recommended; git, curl and jq for the discovery and API commands. Installs, custom nodes, exposure beyond loopback and large model downloads need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# ComfyUI

Get a working, memory-safe ComfyUI server that other programs can drive over HTTP, and keep it updatable.

**Scope:** this one product: install, serve headless, API and workflow JSON, custom nodes, model folders, memory flags, update, troubleshoot. Choosing between image servers, licences and the full media stack belong to `self-hosted-genmedia`. Version facts below were verified on ComfyUI v0.39.0 (2026-10-11).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
# Checkout, Python, torch and GPU
ls -d ~/ComfyUI ~/comfy/ComfyUI 2>/dev/null; command -v comfy && comfy --version 2>&1 | head -2
git -C ~/ComfyUI describe --tags --always 2>/dev/null
python3 --version; nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null
python3 -c 'import torch;print(torch.__version__, torch.cuda.is_available())' 2>&1 | tail -1
# Running server (adjust host/port)
curl -fsS 127.0.0.1:8188/system_stats | jq '{v:.system.comfyui_version, dev:[.devices[]|{name,vram_total,vram_free}]}'
curl -fsS 127.0.0.1:8188/queue | jq '{running:(.queue_running|length), pending:(.queue_pending|length)}'
ps -eo args | grep -E '[m]ain.py.*(--port|--listen)'
df -h ~ | tail -1; du -sh ~/ComfyUI/models/* 2>/dev/null
```

## Decision flow

1. Interactive use on a workstation, no server needs: the desktop app or the portable build is enough (`references/install.md`).
2. Headless or scripted on Linux or macOS: manual install in a venv, or `comfy install` (`references/install.md`).
3. Other programs submit jobs: use the HTTP API with an API-format workflow (`references/api.md`, `scripts/comfy-run.sh`).
4. Clients need an OpenAI `/v1/images/generations` shape: ComfyUI has none. Wrap it, or use `self-hosted-genmedia` to pick sd-server instead.
5. Shared GPU or low memory: memory flags and `/free` (`references/performance-memory.md`).
6. Models live elsewhere or are shared with another tool: `extra_model_paths.yaml` (`references/models.md`).
7. A workflow needs extra nodes: weigh the risk first (`references/custom-nodes.md`).
8. Behind llama-swap, LiteLLM or a reverse proxy: `references/integrations.md`, `references/combos/llama-swap-litellm.md`.
9. Upgrading or rolling back: `references/updating.md`. Something broke: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, services, new custom nodes, Manager settings and any bind beyond `127.0.0.1` need approval and an undo path.
- **Loopback only.** ComfyUI core has no authentication. `--listen` with no value binds all interfaces (`0.0.0.0,::`). Put a reverse proxy or gateway with keys in front of anything non-local.
- **Custom nodes are arbitrary Python** with the server's privileges. On a server start with `--disable-all-custom-nodes` and whitelist what the workflow needs.
- **Use API-format workflows.** `POST /prompt` rejects the UI save format. Export with File, Export (API).
- **Secrets stay out of output.** Partner-node and model-site tokens come from environment variables (`COMFY_API_KEY`, `CIVITAI_API_TOKEN`, `HF_API_TOKEN`) or `0600` files, never from commands you echo.
- **Verify upstream.** Flags and routes move every release; check `python main.py --help` on the installed checkout (`references/updating.md`).

## Workflows

- [ ] Install: pick desktop, portable, comfy-cli or manual -> `references/install.md`
- [ ] First start headless: `python main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch`, see `references/serve-configuration.md`; copy `templates/comfyui.service` for a user service
- [ ] Add models to the right folders, or point at an existing tree -> `references/models.md`, `templates/extra_model_paths.yaml`
- [ ] Run a workflow from a script: export API JSON, then `scripts/comfy-run.sh workflow_api.json` -> `references/api.md`
- [ ] Add custom nodes (optional, risky) -> `references/custom-nodes.md`
- [ ] Share the GPU with LLMs -> `references/performance-memory.md`
- [ ] Front it with llama-swap and LiteLLM -> `references/combos/llama-swap-litellm.md`
- [ ] Update -> `references/updating.md`
- [ ] Verify: `/system_stats` answers, a workflow POSTed to `/prompt` finishes in `/history/{id}` with an output file that `file` recognises, and memory returns after `POST /free`.

## Reference index

- `references/install.md`: install paths per OS and GPU, comfy-cli, Python and torch requirements, containers.
- `references/serve-configuration.md`: launch flags, binding, TLS, CORS, directories, offline mode, service unit.
- `references/api.md`: routes, API-format workflows, job lifecycle, websocket messages, uploads, memory release.
- `references/models.md`: model folders, `extra_model_paths.yaml`, downloading, which folder holds which file.
- `references/custom-nodes.md`: Manager install and security levels, comfy-cli node commands, whitelisting.
- `references/performance-memory.md`: VRAM and RAM flags, dynamic VRAM, caching, sharing a GPU.
- `references/integrations.md`: reverse proxy and Origin check, auth gap, OpenAI wrapper outline, gateway notes.
- `references/updating.md`: git, comfy-cli and portable updates, version switching, release process.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/llama-swap-litellm.md`: ComfyUI through `/comfyui/` in llama-swap, with LiteLLM in front.
- `templates/`: `comfyui.service`, `extra_model_paths.yaml`, `llama-swap-comfyui.yaml`, `litellm-comfyui.yaml`.
- `scripts/comfy-run.sh`: submit an API-format workflow, poll, download outputs.

## Companion skills

- `self-hosted-genmedia`: choose between ComfyUI, sd-server and speech servers, memory planning next to LLMs and licences. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-genmedia`.
- `llama-swap`: hot-swap ComfyUI with LLMs on one GPU. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.
- `litellm`: keys, budgets and routing in front. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `hugging-face`: fetch model weights and manage the cache. Install: `npx skills add ScaleDockHQ/llms-skills --skill hugging-face`.
- `nvidia-dgx-spark`: arm64 unified-memory platform notes. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-spark`.
