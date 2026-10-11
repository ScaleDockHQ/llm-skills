---
name: koboldcpp
description: Install, run and tune KoboldCpp, the single-file llama.cpp-based GGUF server with the KoboldAI Lite UI, OpenAI, Ollama and Anthropic-style APIs plus image, speech, music and MCP. Use for koboldcpp.exe or koboldcpp-linux-x64, --usecuda/--usevulkan/--gpulayers, .kcpps configs, --jinja, mmproj vision, SD, Whisper, TTS, admin/router mode, --password, Docker or systemd, upgrades. Fixes OOM, wrong chat template, slow prompt processing. Not for choosing an engine (choosing-inference-engine) or llama-server (llama-cpp).
license: MIT
compatibility: Windows, Linux x64 or macOS Apple Silicon (prebuilt binaries), also source builds, Termux and Docker; bash, curl and jq for the checks. Installs, services, exposure, remote tunnels and updates need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# KoboldCpp

Gets a KoboldCpp server running with the right backend and GPU offload, a correct chat template, an API
that clients can reach, and a repeatable config. Verified against KoboldCpp v1.122.1 (2026-10-11).

**Scope:** KoboldCpp only: install, serve, tune, scale out, update, troubleshoot. Picking an engine, GGUF
quantization, gateways and agent clients belong to the sibling skills at the end.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# What is installed (binary names vary by platform)
ls -l koboldcpp* 2>/dev/null; command -v koboldcpp
./koboldcpp-linux-x64 --version 2>/dev/null          # or koboldcpp.exe --version
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -i koboldcpp || true

# Hardware
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv 2>/dev/null
vulkaninfo --summary 2>/dev/null | head -20
uname -m; free -h | head -2; nproc

# Running instance (default port 5001)
ss -ltnp 2>/dev/null | grep -E ':5001\b' || true
curl -s -m 3 http://127.0.0.1:5001/api/extra/version | jq .
curl -s -m 3 http://127.0.0.1:5001/v1/models | jq '.data[].id'
curl -s -m 3 http://127.0.0.1:5001/api/extra/perf | jq '{idle,queue,last_eval_speed,last_process_speed}'
```

`--help` on the installed binary is the source of truth for flags; `--analyze file.gguf` prints a model's
metadata and tensor types.

## Decision flow

1. **Is KoboldCpp the right tool?** It fits single-user chat, roleplay and story writing, one binary on a
   laptop or gaming PC, mixed text, image, speech and music from one server, and CPU or Vulkan on AMD and
   Intel. For many concurrent users or large-scale throughput choose vLLM or SGLang
   (`choosing-inference-engine`).
2. **No binary yet** -> `references/install.md`: pick `koboldcpp-linux-x64`, `-nocuda`, `-oldpc`,
   `koboldcpp-mac-arm64` or the Windows exe; build from source for other platforms; Docker only for cloud GPUs.
3. **Model chosen?** GGUF only. Sizing, mmproj, LoRA and quant choice: `references/models-and-formats.md`.
4. **Pick the backend**: `--usecuda` (NVIDIA), `--usevulkan` (AMD, Intel, NVIDIA), `--usecpu`, Metal on macOS.
   Leave `--gpulayers` at the default `-1` (autofit) first; lower it only if load fails.
5. **Write the launch command or `.kcpps`** from `references/serve-config.md` and `templates/`. Always set
   `--contextsize`, `--port`, `--host` and, if reachable beyond loopback, `--password`.
6. **Chat template**: the default `AutoGuess` adapter usually works; for tools and reasoning add `--jinja`
   (`references/features.md`).
7. **Start and verify**: `/api/extra/version`, `/v1/models`, one chat completion, one streamed request.
8. **Tune** prompt processing, KV and context (`references/performance-tuning.md`).
9. **Several models or remote use**: admin and router mode, or llama-swap/LiteLLM in front
   (`references/integrations.md`).
10. **Persist, upgrade, break**: `templates/`, `references/updating.md`, `references/troubleshooting.md`.

## Quick start

```bash
# Linux x64, NVIDIA. Download from the official GitHub releases page only.
curl -fLo koboldcpp-linux-x64 https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-linux-x64
chmod +x koboldcpp-linux-x64
./koboldcpp-linux-x64 --model /models/model.gguf --usecuda --contextsize 16384 \
  --host 127.0.0.1 --port 5001 --jinja

curl -s http://127.0.0.1:5001/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"koboldcpp","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq '.choices[0].message'
```

Prefer a pinned release tag in the URL over `latest` for anything that must be reproducible.

## Rules

- **Ask before changing the system.** Installs, services, firewall rules, exposure, `--remotetunnel` and
  updates need approval and an undo path.
- **Official downloads only.** The GitHub releases page of `LostRuins/koboldcpp`. The README warns that
  `koboldcpp.com` is a malicious fake site; the community site is `koboldcpp.net`.
- **Secrets never touch output.** `--password` and `--adminpassword` can come from `KCPP_PASSWORD` and
  `KCPP_ADMINPASSWORD`; keep them in environment variables or `0600` files, never on a command line you show.
- **Bind to loopback or a private network.** `--host` unset listens on every routable interface. `--password`
  covers text endpoints only; image endpoints are not secured. Put a reverse proxy in front for exposure.
- **Verify upstream.** Flags are renamed and removed between releases (`--flashattention` is now a no-op,
  flash attention is default). Run `--help` on the installed binary.
- **One model set per process.** For several models use admin/router mode or a router such as llama-swap.
- **Measure before and after** every tuning change, with the version recorded.
- **Untrusted configs.** `--onready` runs a shell command; do not load `.kcpps` files from strangers, and
  leave `--allow-config-onready` off unless you wrote the config.

## Facts that surprise people (v1.122.1)

- Default port is 5001; default `--contextsize` 16384; `--gpulayers` defaults to `-1` (autofit), `0` is CPU only.
- `--batchsize` defaults to 512; flash attention is on by default, disable with `--noflashattention`.
- `--jinja` affects only `/v1/chat/completions`; tool calls go through jinja only with `--jinja_tools`.
- `--multiuser` queues requests; real parallel decoding needs `--parallelrequests N` (experimental, text only).
- Context shifting and fast-forward reuse the prompt cache; `--smartcache` keeps KV snapshots in RAM.
- The request `model` field is not used to select a model unless router mode is on.
- Docker image `koboldai/koboldcpp` is documented as experts only; prebuilt binaries are the supported path.
- `/api` serves interactive API docs; `/lcpp` the llama.cpp web UI; `/sdui` and `/musicui` the media UIs.

## Workflows

### Serve a text model on one machine

- [ ] Run discovery; pick the binary (`references/install.md`).
- [ ] Check the fit and pick the quant (`references/models-and-formats.md`).
- [ ] Launch with explicit `--contextsize`, backend and bind; export to a `.kcpps` with `--exportconfig`.
- [ ] Run the smoke tests in Decision flow step 7; save speeds from `/api/extra/perf`.
- [ ] Persist as systemd or compose (`templates/`).

### Add vision, images, speech or embeddings

- [ ] `--mmproj` for vision; `--sdmodel` for images; `--whispermodel`, `--ttsmodel`, `--embeddingsmodel`
      (`references/features.md`). Test each endpoint with the curl lines there.

### Swap between several models

- [ ] Admin mode: `--admin --admindir <dir of .kcpps files>` plus `--adminpassword`; add `--routermode`
      for per-request swapping (`references/integrations.md`).

### Upgrade

- [ ] Read the release notes, download the new binary beside the old one, run the smoke tests, then switch
      (`references/updating.md`).

### Debug a failure

- [ ] Capture the exact error and launch flags, then match `references/troubleshooting.md`; add `--debugmode`.

## Reference index

- `references/install.md`: binaries per platform, source builds, Termux, Docker, cloud GPUs, download safety.
- `references/serve-config.md`: flags by group, `.kcpps` files, env vars, deprecated flags.
- `references/models-and-formats.md`: GGUF, quants, mmproj, LoRA, draft models, conversion, memory budget.
- `references/features.md`: jinja and tools, MCP, vision, reasoning, image, video, speech, music, embeddings, agent.
- `references/api.md`: endpoints, auth, streaming, admin routes.
- `references/performance-tuning.md`: backends, offload, batch, KV quantization, MoE, speculative decoding, RPC.
- `references/integrations.md`: llama-swap, LiteLLM, Open WebUI and others, admin/router mode, reverse proxy.
- `references/observability.md`: perf endpoint, logs, health checks.
- `references/updating.md`: upgrade and rollback.
- `references/troubleshooting.md`: error or symptom to cause to fix.
- `templates/`: `koboldcpp.service`, `docker-compose.yml`, `config.kcpps`.

## Companion skills

- `choosing-inference-engine`: KoboldCpp vs vLLM vs llama.cpp vs SGLang. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `llama-cpp`: the upstream engine and `llama-server`. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`.
- `gguf-quantization`: make or pick GGUF quants. Install: `npx skills add ScaleDockHQ/llms-skills --skill gguf-quantization`.
- `llama-swap`: on-demand model swapping in front of KoboldCpp. Install: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.
- `litellm` and `llm-gateway`: keys, routing, fallbacks. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `comfyui`: richer image workflows than the built-in SD server. Install: `npx skills add ScaleDockHQ/llms-skills --skill comfyui`.
- `whisper-cpp`: standalone speech-to-text server. Install: `npx skills add ScaleDockHQ/llms-skills --skill whisper-cpp`.
- `tool-calling-parsers`: model-level tool-call formats. Install: `npx skills add ScaleDockHQ/llms-skills --skill tool-calling-parsers`.
