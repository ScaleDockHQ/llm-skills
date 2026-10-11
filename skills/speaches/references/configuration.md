# Speaches: configuration

> Verified against Speaches master `src/speaches/config.py`, `main.py`, `dependencies.py` and v0.9.0-rc.3 docs, 2026-10-11

Settings are a pydantic `BaseSettings` class: each field is read from the upper-cased environment variable. Nested settings use a double underscore. Hugging Face variables (`HF_HOME`, `HF_TOKEN`, `HF_HUB_OFFLINE`) also apply.

| Variable                                           | Default                       | Effect                                                                                                        |
| -------------------------------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `API_KEY`                                          | unset                         | when set, API routes require `Authorization: Bearer <key>`                                                    |
| `STT_MODEL_TTL`                                    | `300`                         | seconds idle before an STT model unloads; `-1` never, `0` right after each use                                |
| `TTS_MODEL_TTL`                                    | `300`                         | same for TTS models                                                                                           |
| `VAD_MODEL_TTL`                                    | `-1`                          | same for the VAD model (never unload by default)                                                              |
| `LOG_LEVEL`                                        | `debug`                       | `debug`, `info`, `warning`, `error`, `critical`                                                               |
| `UVICORN_HOST`, `UVICORN_PORT`                     | `0.0.0.0`, `8000`             | bind address and port (inside a container the host is the publish mapping)                                    |
| `ALLOW_ORIGINS`                                    | unset (no CORS middleware)    | JSON list, for example `'["http://localhost:3000"]'`                                                          |
| `ENABLE_UI`                                        | `true`                        | Gradio UI mounted at the root path; set `false` on shared hosts                                               |
| `WHISPER__INFERENCE_DEVICE`                        | `auto`                        | `cpu`, `cuda` or `auto`                                                                                       |
| `WHISPER__DEVICE_INDEX`                            | `0`                           | GPU index or list                                                                                             |
| `WHISPER__COMPUTE_TYPE`                            | `default`                     | `int8`, `int8_float16`, `int8_bfloat16`, `int8_float32`, `int16`, `float16`, `bfloat16`, `float32`, `default` |
| `WHISPER__CPU_THREADS`                             | `0`                           | CPU threads                                                                                                   |
| `WHISPER__NUM_WORKERS`                             | `1`                           | parallel decodes (more memory)                                                                                |
| `PRELOAD_MODELS`                                   | `[]`                          | JSON list of model ids to download at startup; the process exits if any download fails                        |
| `CHAT_COMPLETION_BASE_URL`                         | `http://localhost:11434/v1`   | LLM used by the audio chat completions and Realtime conversation mode                                         |
| `CHAT_COMPLETION_API_KEY`                          | `cant-be-empty`               | key for that LLM; keep real keys in the env file                                                              |
| `LOOPBACK_HOST_URL`                                | unset                         | URL the Gradio app uses to reach the API when it differs from the user-facing URL                             |
| `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME` | unset, `speaches`             | enables OpenTelemetry export; `compose.observability.yaml` is upstream's example                              |
| `SPEACHES_LOG_LEVEL`                               | `INFO` (read via `os.getenv`) | `DEBUG` adds debug detail to error bodies                                                                     |

The VAD default for speech recognition is a field named `_unstable_vad_filter` (`True`). Its docstring says it deviates from the OpenAI spec and may change; the transcription route applies VAD with `min_silence_duration_ms=160, max_speech_duration_s=30` (`routers/stt.py`). Expect timestamps to reflect speech segments rather than raw audio offsets.

## Passing settings in Docker

```bash
docker run ... \
  --env-file ~/.config/speaches.env \
  -e STT_MODEL_TTL=900 -e LOG_LEVEL=info -e ENABLE_UI=false \
  -e 'PRELOAD_MODELS=["Systran/faster-whisper-small"]' \
  -e WHISPER__COMPUTE_TYPE=int8_float16 \
  ghcr.io/speaches-ai/speaches:latest-cuda
```

Quote JSON values so the shell keeps them intact.

## Authentication details

- `API_KEY` protects the chat, STT, models, `/api/ps`, speech, speech-embedding, VAD, diarization and Realtime RTC routers. `/health` is public. The docs state `/docs`, `/openapi.json` and the web UI stay public too.
- Missing or wrong key returns **403** with a `WWW-Authenticate: Bearer` header (not 401).
- The Realtime WebSocket router authenticates inside the handler; it accepts `Authorization: Bearer`, `X-API-Key`, or an `api_key` query parameter (`realtime.md`). Avoid the query-parameter form where URLs are logged.
- There is one shared key, not per-user keys or budgets. Put LiteLLM in front when you need those (`integrations.md`).

## Hardening checklist

- Publish the container port on `127.0.0.1` and terminate TLS in a reverse proxy.
- Set `API_KEY`, `ENABLE_UI=false` and a restrictive `ALLOW_ORIGINS` (or leave it unset).
- `DELETE /v1/models/{id}` removes any model repo from the cache, supported or not (a TODO in the source); the key is the only guard.
