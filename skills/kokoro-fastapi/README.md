# Kokoro-FastAPI

An agent skill for running and tuning [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI), the Dockerized FastAPI server for the Kokoro-82M text-to-speech model. It helps an agent pick the right image (CPU, NVIDIA, Blackwell, ROCm, Apple MPS), run it on loopback, call the OpenAI-compatible `/v1/audio/speech` endpoint, mix voices, use inline pause, voice and rate tags, SSML and captions, tune chunking, and connect it to LiteLLM, llama-swap or Open WebUI.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill kokoro-fastapi
```

## Rules

- **No auth in the server.** Publish on `127.0.0.1` and enforce keys at LiteLLM or a proxy.
- **Pin a release tag.** Upstream recommends it over `:latest`.
- **Leave dev routes off.** Debug, unload, tuner and local voice saving default to false.
- **Write audio to a file.** Responses are raw bytes; never print them.
- **Consent for tuned voices.** Use only voices you have permission to use.

## References

- [`references/install.md`](references/install.md): images per hardware, docker run, Compose, uv, Apple silicon.
- [`references/configuration.md`](references/configuration.md): environment variables, normalization, risky routes.
- [`references/api.md`](references/api.md): routes, request body, voices, tags, SSML, captions, phonemes.
- [`references/performance-memory.md`](references/performance-memory.md): chunking, latency, VRAM reclaim, concurrency.
- [`references/integrations.md`](references/integrations.md): OpenAI SDK, LiteLLM, Open WebUI, others.
- [`references/combos/llama-swap-litellm.md`](references/combos/llama-swap-litellm.md): container under llama-swap with LiteLLM.
- [`references/updating.md`](references/updating.md): releases, upgrade, rollback.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`templates/`](templates): Compose file, LiteLLM and llama-swap entries.
- [`scripts/speak.sh`](scripts/speak.sh): synthesise to a file (bash, curl, jq).

## Companion skills

- `speaches`: OpenAI-compatible STT and TTS server that can also run Kokoro.
- `self-hosted-genmedia`: choose and place speech servers.
- `litellm`, `llama-swap`: gateway and hot-swap.
- `f5-tts`, `chatterbox`: zero-shot voice cloning alternatives.

## License

MIT
