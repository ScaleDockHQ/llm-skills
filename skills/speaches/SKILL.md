---
name: speaches
description: Deploy and operate Speaches, the OpenAI-compatible speech server (faster-whisper STT, Kokoro and Piper TTS, Realtime API) with Docker or uv, dynamic model loading, API_KEY, VAD and the speaches-cli. Use for /v1/audio/transcriptions or /v1/audio/speech self-hosting, ghcr.io/speaches-ai/speaches latest-cuda, STT_MODEL_TTL, PRELOAD_MODELS, Systran/faster-whisper models, Kokoro-82M-v1.0-ONNX, or adding speech to LiteLLM or Open WebUI. Not for the faster-whisper library alone or whisper.cpp.
license: MIT
compatibility: Linux, macOS and Windows with Docker (amd64 and arm64 images; NVIDIA GPU via the cuda image) or Python with uv; curl and jq for the helper scripts. Image pulls, model downloads, services and any bind beyond loopback need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Speaches

Stand up one OpenAI-shaped service for speech-to-text and text-to-speech, with models downloaded and unloaded on demand, and put it behind a key or a gateway.

**Scope:** this one product: install, configure, download models, call the API, secure, update, troubleshoot. Choosing between STT servers belongs to `self-hosted-genmedia`; the library underneath is `faster-whisper`; a Kokoro-only TTS server is `kokoro-fastapi`. Facts below were verified on Speaches `master` and the `v0.9.0-rc.3` release (2026-10-11). There is no stable `v0.9.0` tag yet and `latest-*` images follow `master`, so confirm against the running server's `/docs`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i speaches
docker images --format '{{.Repository}}:{{.Tag}}' | grep -i speaches
nvidia-smi -L 2>/dev/null; docker info --format '{{json .Runtimes}}' 2>/dev/null | head -c 200
B="${SPEACHES_BASE_URL:-http://127.0.0.1:8000}"
curl -fsS "$B/health"                                  # public even when API_KEY is set; {"message":"OK"}
curl -fsS "$B/api/ps" ${SPEACHES_API_KEY:+-H "Authorization: Bearer $SPEACHES_API_KEY"} | jq .   # loaded models
curl -fsS "$B/v1/models" ${SPEACHES_API_KEY:+-H "Authorization: Bearer $SPEACHES_API_KEY"} | jq -r '.data[].id'   # downloaded models
```

## Decision flow

1. Not running: install with Docker (`references/install.md`). CUDA image on NVIDIA, CPU image elsewhere; arm64 images exist for both.
2. Choose and download models: `references/models.md`. Nothing works before at least one STT or TTS model is downloaded.
3. Call it: `references/api.md` (transcriptions, translations, speech, voices, model and load routes).
4. Tune idle unload, VAD, device and compute type: `references/configuration.md`.
5. Expose beyond localhost or share a host: set `API_KEY`, publish on `127.0.0.1`, disable the UI (`references/configuration.md`).
6. Wire into LiteLLM, llama-swap or Open WebUI: `references/integrations.md`, `references/combos/llama-swap-litellm.md`, `templates/`.
7. Live microphone use: `references/realtime.md`.
8. Upgrade: `references/updating.md`. Errors: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Image pulls (the CUDA image is large), model downloads, services and published ports need approval and an undo path (`docker rm -f speaches`).
- **Publish on loopback.** `docker run --publish 8000:8000` listens on every interface. Use `127.0.0.1:8000:8000`, and set `API_KEY` before anything else can reach it. `/health`, `/docs`, `/openapi.json` and the web UI stay public even with a key.
- **Keys live in files.** Put `API_KEY=...` in a `0600` env file passed with `--env-file`, never on the command line, and send clients the key from an environment variable.
- **Tell clients the model id.** The request `model` is the Hugging Face repo id (for example `Systran/faster-whisper-small`). The aliases `whisper-1`, `tts-1` and `tts-1-hd` map to defaults in `model_aliases.json`.
- **Download before use.** A request for a model that is not downloaded fails; `POST /v1/models/{id}` downloads it. Gated models need `HF_TOKEN` in the container environment.
- **VAD is on by default.** `_unstable_vad_filter` defaults to `True`, which deviates slightly from OpenAI behaviour; see `configuration.md` before relying on exact timestamps.
- **Prefer curl over speaches-cli.** The PyPI `speaches-cli` is version 0.1.0 from March 2025 and requires Python 3.12 exactly; the HTTP routes in `references/api.md` do the same jobs.
- **Verify upstream.** The project is pre-1.0 and fast-moving; check `/docs` on the running server and the repo's `src/speaches/config.py`.

## Workflows

- [ ] Choose CPU or CUDA image, create the env file with `API_KEY` -> `references/install.md`
- [ ] Start the container on `127.0.0.1:8000` with the cache volume -> `references/install.md`
- [ ] `GET /health`, then download a small STT model and transcribe a sample -> `references/models.md`, `scripts/transcribe.sh`
- [ ] Download a TTS model, list voices, synthesise a sentence -> `references/api.md`, `scripts/speak.sh`
- [ ] Set TTLs, preload models and decide on the UI -> `references/configuration.md`
- [ ] Add to LiteLLM and optionally llama-swap -> `references/integrations.md`, `references/combos/llama-swap-litellm.md`
- [ ] Update to a newer image tag -> `references/updating.md`
- [ ] Verify: `/health` is OK, `/api/ps` shows the model after a request, an API call without the key returns 403 when `API_KEY` is set, and the port is bound to loopback (`docker port speaches`).

## Reference index

- `references/install.md`: Docker run and Compose, CPU and CUDA images, CDI, uv install, cache volume.
- `references/configuration.md`: environment variables with defaults, nested whisper settings, TTLs, auth, CORS, VAD.
- `references/api.md`: transcription and translation fields, speech request body, voices, model management, `/api/ps`.
- `references/models.md`: STT and TTS model ids, registry browse, download, delete, aliases, preload.
- `references/realtime.md`: Realtime API over WebSocket, transcription-only mode, limits.
- `references/integrations.md`: OpenAI SDKs, LiteLLM, Open WebUI, llama-swap.
- `references/combos/llama-swap-litellm.md`: Speaches in a container under llama-swap with LiteLLM in front.
- `references/updating.md`: image tags, pinning, release status, rollback.
- `references/troubleshooting.md`: symptom to fix table.
- `templates/`: `compose.speaches.yaml`, `litellm-speaches.yaml`, `llama-swap-speaches.yaml`.
- `scripts/transcribe.sh`, `scripts/speak.sh`: call a running server (bash, curl, jq).

## Companion skills

- `faster-whisper`: the engine library, compute types and model conversion. Install: `npx skills add ScaleDockHQ/llm-skills --skill faster-whisper`.
- `kokoro-fastapi`: dedicated Kokoro TTS server with SSML and voice mixing. Install: `npx skills add ScaleDockHQ/llm-skills --skill kokoro-fastapi`.
- `whisper-cpp`: lean single-model Whisper server. Install: `npx skills add ScaleDockHQ/llm-skills --skill whisper-cpp`.
- `self-hosted-genmedia`: choose a speech stack and share a GPU with LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `litellm`: keys, budgets and routing in front. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llama-swap`: hot-swap speech containers with LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
