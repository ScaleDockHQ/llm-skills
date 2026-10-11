# Speaches

An agent skill for deploying and operating [Speaches](https://github.com/speaches-ai/speaches), the OpenAI-compatible speech server: faster-whisper speech-to-text, Kokoro and Piper text-to-speech, streaming, dynamic model loading and a Realtime API. It helps an agent pick the CPU or CUDA image, run it on loopback with an API key, download models, call `/v1/audio/transcriptions` and `/v1/audio/speech`, tune idle unload, and put it behind LiteLLM, llama-swap or Open WebUI.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill speaches
```

## Rules

- **Publish on loopback.** Upstream examples bind every interface; use `127.0.0.1:8000:8000` and set `API_KEY` (auth failures return 403).
- **Keys live in `0600` files.** Pass `--env-file`, never inline secrets.
- **Download before use.** Requests need a downloaded Hugging Face model id; `POST /v1/models/<id>` fetches it.
- **Pre-1.0 project.** `latest-*` images follow `master`; pin tags or digests and re-read `/docs`.
- **Prefer curl to `speaches-cli`.** The PyPI CLI is old and needs Python 3.12.

## References

- [`references/install.md`](references/install.md): Docker, Compose, CPU and CUDA images, uv.
- [`references/configuration.md`](references/configuration.md): environment variables, TTLs, auth, hardening.
- [`references/api.md`](references/api.md): transcription, speech, models and `/api/ps` routes.
- [`references/models.md`](references/models.md): model ids, registry, downloads, preload.
- [`references/realtime.md`](references/realtime.md): Realtime WebSocket API and limits.
- [`references/integrations.md`](references/integrations.md): SDKs, LiteLLM, Open WebUI, llama-swap.
- [`references/combos/llama-swap-litellm.md`](references/combos/llama-swap-litellm.md): container under llama-swap with LiteLLM in front.
- [`references/updating.md`](references/updating.md): releases, tags, pin and rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/`](templates): Compose file, LiteLLM and llama-swap entries.
- [`scripts/`](scripts): `transcribe.sh` and `speak.sh` (bash, curl, jq).

## Companion skills

- `faster-whisper`: the engine library underneath.
- `kokoro-fastapi`: dedicated Kokoro TTS server.
- `whisper-cpp`: lean single-model Whisper server.
- `self-hosted-genmedia`: choose and place speech servers.
- `litellm`, `llama-swap`: gateway and hot-swap.

## License

MIT
