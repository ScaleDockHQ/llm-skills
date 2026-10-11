# Speaches: HTTP API

> Verified against Speaches master (`routers/stt.py`, `speech.py`, `models.py`, `misc.py`, `vad.py`, docs/usage) and v0.9.0-rc.3, 2026-10-11

Set `B=http://127.0.0.1:8000` and, when `API_KEY` is configured, `AUTH=(-H "Authorization: Bearer $SPEACHES_API_KEY")`. The interactive reference is `$B/docs` (public) and the schema `$B/openapi.json`.

## Routes

| Method and path                              | Purpose                                                                        |
| -------------------------------------------- | ------------------------------------------------------------------------------ |
| `GET /health`                                | liveness, `{"message":"OK"}`; no key needed                                    |
| `POST /v1/audio/transcriptions`              | speech to text (multipart)                                                     |
| `POST /v1/audio/translations`                | speech to English text (multipart)                                             |
| `POST /v1/audio/speech`                      | text to speech (JSON), returns raw audio bytes                                 |
| `POST /v1/audio/speech/timestamps`           | VAD speech segments for an uploaded file                                       |
| `GET /v1/audio/voices`                       | voices of the **downloaded** TTS models                                        |
| `GET /v1/audio/models`                       | downloaded TTS models                                                          |
| `GET /v1/models`, `GET /v1/models/{id}`      | downloaded models, optional `?task=` filter                                    |
| `POST /v1/models/{id}`                       | download a model (200 downloaded, 201 already present, 401 gated, 404 unknown) |
| `DELETE /v1/models/{id}`                     | delete a model from the cache                                                  |
| `GET /v1/registry?task=...`                  | models available to download                                                   |
| `GET /api/ps`                                | models loaded in memory                                                        |
| `POST /api/ps/{id}`, `DELETE /api/ps/{id}`   | load into / unload from memory (201, 409 already loaded, 404 unsupported)      |
| `/v1/realtime` (WebSocket), chat completions | see `realtime.md`                                                              |

Model ids contain slashes; the routes accept them as paths (`/v1/models/Systran/faster-whisper-small`).

## Transcriptions

```bash
curl -sS "$B/v1/audio/transcriptions" "${AUTH[@]}" \
  -F file=@audio.wav -F model=Systran/faster-whisper-small -F language=nl \
  -F response_format=verbose_json -F 'timestamp_granularities[]=word' | jq .
```

Form fields: `file` (required), `model` (required), `language`, `prompt`, `response_format` (`json` default, `text`, `verbose_json`, `srt`, `vtt`), `temperature` (default `0.0`), `timestamp_granularities[]` (only meaningful with `verbose_json`), `stream` (`true` streams SSE as audio is transcribed), and two non-standard fields `hotwords` and `without_timestamps` (default `true`). Translations take the same fields except `language`.

Pitfalls:

- `without_timestamps` defaults to `true`; send `-F without_timestamps=false` if you need segment times in `verbose_json`.
- Word timestamps require `timestamp_granularities[]=word` **and** `response_format=verbose_json`.
- `whisper-1` is an alias for `Systran/faster-whisper-large-v3`.

## Speech

```bash
curl -sS "$B/v1/audio/speech" "${AUTH[@]}" -H 'Content-Type: application/json' \
  -d '{"model":"speaches-ai/Kokoro-82M-v1.0-ONNX","voice":"af_heart","input":"Hello world","response_format":"wav","speed":1.0}' \
  -o hello.wav && file hello.wav
```

Body fields: `model`, `input`, `voice` (all required), `response_format` (`pcm`, `mp3`, `wav`, `flac`, `opus`, `aac`; the default is set in source, so pass it explicitly), `speed` (default `1.0`; supported range differs per model), `stream_format` (`audio` or `sse`), `sample_rate` (resample output). The response is audio bytes; always write with `-o`. `tts-1` and `tts-1-hd` alias to `speaches-ai/Kokoro-82M-v1.0-ONNX`.

List voices after downloading a TTS model: `curl -sS "$B/v1/audio/voices" "${AUTH[@]}" | jq -r '.voices[].name'` (field names come from the model's voice objects; inspect one entry first).

## Model memory

```bash
curl -sS "$B/api/ps" "${AUTH[@]}" | jq .                       # {"models":[...]}
curl -sS -X POST   "$B/api/ps/Systran/faster-whisper-small" "${AUTH[@]}"   # preload into memory
curl -sS -X DELETE "$B/api/ps/Systran/faster-whisper-small" "${AUTH[@]}"   # unload now
```

`/api/ps` is tagged experimental in the source. A model that is not downloaded cannot be loaded.

## OpenAI SDKs

```python
from openai import OpenAI
client = OpenAI(base_url="http://127.0.0.1:8000/v1", api_key="<key or any non-empty placeholder>")
with open("audio.wav", "rb") as f:
    print(client.audio.transcriptions.create(model="Systran/faster-whisper-small", file=f).text)
```

SDKs require a non-empty key even when the server has none. Set the key from an environment variable (`OPENAI_API_KEY`), never in code.

## Errors

Custom errors return JSON with `detail`, `hint`, `suggested_fixes` and `error_id`. Auth failures are HTTP 403. See `troubleshooting.md`.
