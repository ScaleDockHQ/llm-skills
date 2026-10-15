---
name: invokeai
description: Install, run and operate InvokeAI, the node-based creative engine and web UI for Stable Diffusion, SDXL, FLUX, Z-Image, Qwen-Image and Wan video, with its REST API and queue. Use for the Invoke launcher, invokeai-web, invokeai.yaml settings, INVOKEAI_ROOT, port 9090, ghcr.io/invoke-ai/invokeai images, Model Manager installs, low-VRAM and partial loading, multi-user mode, enqueue_batch graphs, custom node packs, or CUDA out-of-memory. Not for ComfyUI, sd-server or diffusers scripts.
license: MIT
compatibility: Windows 10+, macOS 14+ (Apple silicon) and Linux; NVIDIA, AMD (Linux/ROCm), Intel Arc or CPU; Python 3.11-3.12 with uv for manual installs, Docker optional, curl and jq for the API checks. Installs, model downloads, custom nodes, external API keys and any bind beyond loopback need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# InvokeAI

Get a working InvokeAI install that fits its GPU, is reachable only where intended, and can be driven over its HTTP API.

**Scope:** this one product: install (launcher, `uv`, Docker), `invokeai.yaml`, Model Manager, memory settings, multi-user mode, the queue API, custom nodes, update, troubleshoot. Choosing between InvokeAI, ComfyUI and diffusers, licences and the wider media stack belong to `self-hosted-genmedia`. Version facts were verified on v6.14.2 (stable, 2026-09-27); `v7.0.0-alpha.2` is a pre-release and its docs differ (see `references/updating.md`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
command -v invokeai-web uv docker; ls -d ~/invokeai ~/invokeai/invokeai.yaml 2>/dev/null
echo "INVOKEAI_ROOT=${INVOKEAI_ROOT:-unset}"
pip show invokeai 2>/dev/null | sed -n 1,2p
nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used --format=csv 2>/dev/null
# Running server (default 127.0.0.1:9090); /docs is the Swagger UI
curl -fsS 127.0.0.1:9090/api/v1/app/version 2>/dev/null | jq .
curl -fsS 127.0.0.1:9090/api/v1/auth/status 2>/dev/null | jq .     # exists only in multi-user mode
curl -fsS 127.0.0.1:9090/api/v1/queue/default/status 2>/dev/null | jq .
ps -eo args | grep -E '[i]nvokeai-web'; docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -i invokeai
grep -E '^(host|port|multiuser|enable_partial_loading|max_cache|device_working_mem_gb|generation_devices)' ~/invokeai/invokeai.yaml 2>/dev/null
df -h ~ | tail -1; du -sh ~/invokeai/models 2>/dev/null
```

## Decision flow

1. A person will use the UI on a desktop: the official Invoke Launcher (`references/install.md`).
2. Headless Linux server, or scripted installs: manual `uv` install with the right torch backend, or the Docker image (`references/install.md`).
3. Settings, root directory, binding and TLS: `references/configuration.md`. The default bind is `127.0.0.1`; keep it unless a gateway or proxy with auth sits in front.
4. Several people share it: multi-user mode (`references/configuration.md`).
5. Models: Model Manager, HF repo IDs, starter models, external API models (`references/models-and-nodes.md`).
6. Programs submit jobs: enqueue a graph over HTTP (`references/api.md`). There is no OpenAI-shaped `/v1/images/generations` route.
7. Out of memory or slow: `references/memory-and-performance.md`.
8. Upgrading, pinning or moving to v7 alpha: `references/updating.md`. Errors: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, image pulls, multi-GB model downloads, custom nodes, external provider keys and any bind beyond `127.0.0.1` need approval and an undo path.
- **Single-user mode has no authentication.** With `multiuser: false` every API call runs as an administrator. Do not publish the port; use loopback, a tunnel, multi-user mode, or an authenticating proxy.
- **Custom nodes are arbitrary Python.** The Custom Node Manager loads a pack into the running process with no restart; install only packs the user trusts, and restrict with `allow_nodes` or `deny_nodes` when exposed.
- **Secrets stay out of output.** Hugging Face and marketplace tokens, `external_*_api_key` values and JWTs live in `invokeai.yaml`, `api_keys.yaml` (`0600`) or environment variables, never in echoed commands or logs.
- **Pin versions.** `latest` container tags follow `main`; use the release tag (`6.14.2-cuda`).
- **Keep `unsafe_disable_picklescan` off.** It allows arbitrary code in pickled model files.
- **Verify upstream.** Setting names and routes move; confirm with `/openapi.json` and the installed version's docs.

## Workflows

- [ ] Choose the install path and check GPU, driver and disk -> `references/install.md`
- [ ] Install, start on loopback, open `http://127.0.0.1:9090` -> `references/install.md`
- [ ] Set root, bind, memory and multi-user options in `invokeai.yaml` -> `references/configuration.md`, `references/memory-and-performance.md`
- [ ] Install a starter or Hugging Face model; add LoRAs, nodes or external providers if needed -> `references/models-and-nodes.md`
- [ ] Drive a generation from a script -> `references/api.md`
- [ ] Update with a database backup -> `references/updating.md`
- [ ] Verify: `/api/v1/app/version` answers, one generation completes in the queue, the image downloads from `/api/v1/images/i/{name}/full`, and the log shows the GPU in use.

## Reference index

- `references/install.md`: hardware, launcher, manual `uv` install per backend, Docker images and compose, Python and driver rules.
- `references/configuration.md`: root lookup, `invokeai.yaml`, environment variables, host and port, CORS, TLS, proxies, multi-user mode, logging.
- `references/models-and-nodes.md`: Model Manager sources, tokens, gated models, external providers, custom nodes.
- `references/api.md`: Swagger, `enqueue_batch`, polling, images, auth headers, security notes.
- `references/memory-and-performance.md`: partial loading, cache and working memory, multi-GPU, allocator, Windows pitfalls.
- `references/updating.md`: launcher, `uv`, Docker updates, backups, v7 alpha notes.
- `references/troubleshooting.md`: symptom to fix table.

## Companion skills

- `self-hosted-genmedia`: choose between InvokeAI, ComfyUI, sd-server and diffusers; memory planning next to LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `comfyui`: node-graph engine with a different HTTP API. Install: `npx skills add ScaleDockHQ/llm-skills --skill comfyui`.
- `diffusers`: Python library underneath many Invoke models. Install: `npx skills add ScaleDockHQ/llm-skills --skill diffusers`.
- `hugging-face`: tokens, gated repos and cache. Install: `npx skills add ScaleDockHQ/llm-skills --skill hugging-face`.
- `caddy`: reverse proxy with auth in front. Install: `npx skills add ScaleDockHQ/llm-skills --skill caddy`.
