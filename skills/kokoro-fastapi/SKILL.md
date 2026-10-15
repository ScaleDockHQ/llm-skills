---
name: kokoro-fastapi
description: Run and tune Kokoro-FastAPI, the Dockerized FastAPI server for the Kokoro-82M text-to-speech model with an OpenAI-compatible /v1/audio/speech endpoint, voice mixing, streaming, captions, SSML and a web player. Use for ghcr.io/remsky/kokoro-fastapi-gpu or -cpu, port 8880, af_heart voices, response_format pcm, [voice:] tags, DEFAULT_VOICE, ENABLE_* flags, or adding Kokoro TTS to LiteLLM, llama-swap or Open WebUI. Not for Speaches (use speaches) or voice cloning (use f5-tts or chatterbox).
license: MIT
compatibility: Linux, Windows and macOS with Docker (cpu image on any host; NVIDIA GPU image on amd64 and arm64; experimental ROCm on amd64) or uv for native runs including Apple MPS. curl and jq for the helper scripts. Image pulls, services and any bind beyond loopback need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Kokoro-FastAPI

Stand up a small, fast, OpenAI-shaped text-to-speech server for Kokoro-82M on the user's hardware and connect clients and gateways to it.

**Scope:** this one product: run, configure, call, secure, update, troubleshoot. Choosing a TTS stack belongs to `self-hosted-genmedia`; Speaches can also serve Kokoro (ONNX) alongside STT. Facts below were verified on Kokoro-FastAPI v0.9.0 (2026-09-10) and its master docs on 2026-10-11; `GET /docs` on the running server is the final word.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i kokoro
nvidia-smi -L 2>/dev/null; uname -sm
B="${KOKORO_BASE_URL:-http://127.0.0.1:8880}"
curl -fsS "$B/health"                                         # {"status":"healthy"}
curl -fsS "$B/v1/models" | jq -r '.data[].id'
curl -fsS "$B/v1/audio/voices" | jq -r '.default_voice, (.voices[].id)' | head -20
```

## Decision flow

1. Not running: pick the image (`references/install.md`). NVIDIA `gpu` image, `cpu` image everywhere else; Blackwell (RTX 50) needs the `-cu128` tag on amd64; Apple silicon runs the CPU image in Docker or natively with MPS via `./start-gpu_mac.sh`.
2. Configure with environment variables (`references/configuration.md`): default voice, token chunking, which dev routes are on, CORS.
3. Call it (`references/api.md`): `/v1/audio/speech`, voices and blends, streaming, inline tags, SSML, captions, phonemes.
4. Latency, throughput and VRAM: `references/performance-memory.md`.
5. Behind LiteLLM, llama-swap or Open WebUI: `references/integrations.md`, `references/combos/llama-swap-litellm.md`, `templates/`.
6. Upgrade: `references/updating.md`. Errors: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Image pulls, services and published ports need approval and an undo path (`docker rm -f kokoro`).
- **Publish on loopback.** Upstream's `docker run -p 8880:8880` binds every interface and there is **no API key setting**; use `-p 127.0.0.1:8880:8880` and enforce keys at LiteLLM or a reverse proxy.
- **Keep the risky routes off.** `ENABLE_DEBUG_ENDPOINTS`, `ALLOW_DEV_UNLOAD`, `ENABLE_INNO_TUNER` and `ALLOW_LOCAL_VOICE_SAVING` default to false; leave them off on shared hosts. Narrow `CORS_ORIGINS` (default `["*"]`).
- **Pin the image.** Upstream says `:latest` exists but to pin a release tag for stable use (for example `v0.9.0`).
- **Write audio to a file.** Responses are raw audio bytes (mp3 by default, streamed). Use `curl -o`, never print them.
- **Voice name sets the language.** The first letter of the voice (`af_`, `bf_`, `jf_`...) selects the language pipeline; `lang_code` or `DEFAULT_VOICE_CODE` overrides it.
- **Consent for tuned voices.** `/dev/tune` builds a voice from a reference clip; use only voices you have permission to use.
- **Verify upstream.** Dev routes and flags change often (see `/docs` and `docs/configuration.md`).

## Workflows

- [ ] Choose the image tag for the hardware and pin a release -> `references/install.md`
- [ ] Run on `127.0.0.1:8880`, wait for `/health` -> `references/install.md`
- [ ] Synthesise a test sentence to a file with `scripts/speak.sh` -> `references/api.md`
- [ ] List voices, try a blend, set `DEFAULT_VOICE` -> `references/api.md`, `references/configuration.md`
- [ ] Tune chunking and concurrency for the workload -> `references/performance-memory.md`
- [ ] Add to LiteLLM (and llama-swap if sharing a GPU) -> `references/integrations.md`
- [ ] Update to a new release tag -> `references/updating.md`
- [ ] Verify: `/health` is healthy, the output file is real audio (`file out.mp3`), the port is on loopback (`docker port kokoro`), and dev routes return 403.

## Reference index

- `references/install.md`: image tags per hardware, `docker run`, Compose, uv runs, Apple silicon.
- `references/configuration.md`: every environment variable with defaults, normalization options, logging.
- `references/api.md`: routes, request body, voices and blends, aliases, inline tags, SSML, captions, phonemes, dialogue.
- `references/performance-memory.md`: chunking, streaming latency, throughput figures, unload and reload.
- `references/integrations.md`: OpenAI SDK, LiteLLM, Open WebUI, Home Assistant and others.
- `references/combos/llama-swap-litellm.md`: container under llama-swap with LiteLLM in front.
- `references/updating.md`: release cadence, tags, upgrade and rollback.
- `references/troubleshooting.md`: symptom to fix table (GPU, ROCm, models, voices).
- `templates/`: `compose.kokoro.yaml`, `litellm-kokoro.yaml`, `llama-swap-kokoro.yaml`.
- `scripts/speak.sh`: synthesise text to a file through a running server (bash, curl, jq).

## Companion skills

- `speaches`: OpenAI-compatible STT and TTS server that can also run Kokoro. Install: `npx skills add ScaleDockHQ/llm-skills --skill speaches`.
- `self-hosted-genmedia`: choose a TTS stack and place it next to LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `litellm`: keys, budgets and routing in front (Kokoro-FastAPI has no auth). Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llama-swap`: hot-swap the container with LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `f5-tts`, `chatterbox`: zero-shot voice cloning TTS when Kokoro's fixed voices are not enough. Install: `npx skills add ScaleDockHQ/llm-skills --skill f5-tts`.
