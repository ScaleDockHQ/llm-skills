# Pipeline A: Open WebUI Voice Mode with whisper.cpp and Kokoro

> Verified against Open WebUI v0.12.0 (docs: voice-mode, audio STT/TTS, env-configuration; routers/audio at main), whisper.cpp v1.9.5 (see the `whisper-cpp` skill), Kokoro-FastAPI v0.9.0 (README, docs/configuration.md, router source at the tag) and Ollama v0.40.3, 2026-10-11

```text
browser mic --> Open WebUI --> whisper-server  :8081  /v1/audio/transcriptions
                          --> LLM (Ollama :11434 or LiteLLM :4000)
                          --> Kokoro-FastAPI   :8880  /v1/audio/speech --> browser speaker
```

In Standard Voice Mode (the default), what you say is transcribed on the server with the admin's STT engine, the reply streams from the chat model, and each sentence is sent to the TTS engine as soon as it is complete.

## 1. STT: whisper-server

Build, model choice and flags are in the `whisper-cpp` skill. Mount it at the OpenAI path so Open WebUI's `{base_url}/audio/transcriptions` request lands on it:

```bash
whisper-server --host 127.0.0.1 --port 8081 \
  -m ~/models/whisper/ggml-large-v3-turbo.bin -l auto --convert \
  --request-path /v1/audio --inference-path /transcriptions
```

Open WebUI's source posts multipart with `model`, optional `language` and `file`, to `{base_url}/audio/transcriptions`. whisper-server accepts the `file` and `language` fields and ignores `model`; it has no `/v1/models` and no auth check. `--convert` needs ffmpeg for browser-recorded webm/ogg. Health: `GET /v1/audio/health`.

```bash
curl -fsS http://127.0.0.1:8081/v1/audio/health
curl -fsS http://127.0.0.1:8081/v1/audio/transcriptions -F file=@sample.wav -F model=whisper-1 | jq -r .text
```

## 2. TTS: Kokoro-FastAPI

Upstream publishes CPU, NVIDIA (`cu126`, and `latest-cu128` for RTX 50/Blackwell), AMD ROCm (experimental) images and a native Apple Silicon script. Pin a release tag (latest release v0.9.0, 2026-09-10) instead of `:latest`:

```bash
docker run -d --name kokoro --restart unless-stopped -p 127.0.0.1:8880:8880 \
  ghcr.io/remsky/kokoro-fastapi-cpu:v0.9.0
# NVIDIA: add --gpus all and use ghcr.io/remsky/kokoro-fastapi-gpu:v0.9.0
```

The `cpu:v0.9.0`, `gpu:v0.9.0` and `gpu:latest-cu128` manifests were confirmed on ghcr.io (HTTP 200) on the writing date; images were not pulled or run. Settings are environment variables (`DEFAULT_VOICE`, `API_LOG_LEVEL`, `WEB_CONCURRENCY`; see upstream `docs/configuration.md`). Inference is synchronous, so one process serves one request at a time.

API (router source at v0.9.0): `POST /v1/audio/speech`, `GET /v1/audio/voices`, `GET /v1/models`, `GET /health`. The default response format list is `mp3, opus, aac, flac, wav, pcm`. OpenAI voice names map to Kokoro voices (for example `alloy` to `am_adam`, `echo` to `af_bella`); direct names such as `af_bella` also work.

```bash
curl -fsS http://127.0.0.1:8880/health
curl -fsS http://127.0.0.1:8880/v1/audio/speech -H 'Content-Type: application/json' \
  -d '{"model":"kokoro","input":"Voice check, one two three.","voice":"af_bella","response_format":"wav"}' \
  --output /tmp/kokoro-test.wav && file /tmp/kokoro-test.wav
```

Listening tests are yours: play the file and judge it. Voices and languages: English (US/GB), Spanish, French, Hindi, Italian, Japanese, Brazilian Portuguese and Mandarin per the README; check `/v1/audio/voices` for what your build serves.

## 3. Open WebUI settings

Admin Panel > Settings > Audio, or environment variables on the container (all are persistent config: after first start the Admin Panel value wins). Reachability: Open WebUI's backend calls these URLs, so with the host-network container from `ollama-open-webui-tailscale` use `127.0.0.1`; in a bridge network use `host.docker.internal` and publish the audio ports where the container can reach them.

```text
AUDIO_STT_ENGINE=openai
AUDIO_STT_OPENAI_API_BASE_URL=http://127.0.0.1:8081/v1
AUDIO_STT_MODEL=whisper-1                 # ignored by whisper-server, required by the form
AUDIO_STT_OPENAI_API_KEY=not-needed

AUDIO_TTS_ENGINE=openai
AUDIO_TTS_OPENAI_API_BASE_URL=http://127.0.0.1:8880/v1
AUDIO_TTS_OPENAI_API_KEY=not-needed
AUDIO_TTS_MODEL=kokoro
AUDIO_TTS_VOICE=af_bella
```

Notes from the docs and source:

- `AUDIO_STT_ENGINE` empty means built-in local Whisper inside the standard image; `openai` means any OpenAI-compatible endpoint. The `:slim` image has no local Whisper or local TTS, so it needs these external engines.
- `AUDIO_TTS_ENGINE` empty means no backend TTS (browser voices only). Kokoro-FastAPI's own integration guide in the Open WebUI docs sets engine OpenAI, base URL `http://localhost:8880/v1` (or `host.docker.internal`), key `not-needed`.
- A "Web API" speech-to-text setting is browser-only and Voice Mode refuses it ("Call feature is not supported when using Web STT engine").
- Response Splitting (Admin > Audio) controls how much is spoken at once: Punctuation (default), Paragraphs, None. Punctuation gives the earliest first audio.
- Voice Mode adds a voice-oriented system prompt (short, conversational answers) unless disabled (`ENABLE_VOICE_MODE_PROMPT`).
- Browsers allow the microphone only on HTTPS or `localhost`; opening the UI by LAN IP breaks it. Use Tailscale Serve (`ollama-open-webui-tailscale`).
- Realtime call mode (OpenAI-compatible Realtime API, WebSocket under `/api/`) is a separate admin option; this stack uses Standard mode.

## 4. Test the whole chain

1. Smoke-test whisper, Kokoro and the LLM alone (commands above and in `ollama`).
2. In Open WebUI, pick one model, leave the box empty and click Voice mode; allow the microphone; speak, pause about two seconds, listen.
3. If a step fails, `docker logs open-webui | tail -50` shows the failing audio URL and status.

## Optional: LiteLLM in front

whisper.cpp behind llama-swap and LiteLLM with `mode: audio_transcription` is in the `whisper-cpp` skill (`combos/llama-swap-litellm.md`); Kokoro as a LiteLLM speech model is in `self-hosted-genmedia`. Then point both Open WebUI base URLs at LiteLLM (`/v1`) with a virtual key entered in the Admin Panel.
