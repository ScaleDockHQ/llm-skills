# Speaches: Realtime API

> Verified against Speaches master docs/usage/realtime-api.md and `main.py`, 2026-10-11

Speaches implements an OpenAI Realtime-compatible WebSocket at `/v1/realtime`, plus a static realtime console at the same path in a browser.

## Modes

- **Conversation** (default): speech in, STT, an LLM from `CHAT_COMPLETION_BASE_URL`, TTS out. The URL `model` is the conversation model.
- **Transcription only**: `?intent=transcription&model=<stt-model>`; response generation is disabled. Extra parameters: `language` (ISO-639-1), `transcription_model`.

```text
wss://host/v1/realtime?model=deepdml/faster-whisper-large-v3-turbo-ct2&intent=transcription&language=en
```

## Auth

`Authorization: Bearer <key>`, `X-API-Key: <key>`, or `api_key=<key>` in the query string. No `OpenAI-Beta: realtime=v1` header is needed. The query-string form puts the key in URLs and logs; prefer headers.

## Defaults and requirements

- Default STT `Systran/faster-distil-whisper-small.en`, TTS `speaches-ai/Kokoro-82M-v1.0-ONNX`, voice `af_heart`. Defaults must be downloaded or the session fails (`models.md`).
- Upstream warns real-time performance needs CUDA for STT and TTS and an LLM with high tokens per second and low time to first token.
- Use a headset: TTS audio picked up by the microphone is transcribed and loops.

## Limits (upstream)

- Client events `response.cancel` and `conversation.item.truncate` are not supported; interruption handling is unfinished.
- `conversation.item.create` with `input_audio` content is not supported.
- Changing the transcription model with `session.update` applies only to new audio buffers.
- Image input and speech-to-speech models are listed as future work.

## Smoke test

```bash
# websocat is a third-party tool; only use it if installed
websocat -H "Authorization: Bearer $SPEACHES_API_KEY" "ws://127.0.0.1:8000/v1/realtime?intent=transcription&model=Systran/faster-distil-whisper-small.en"
```

Then send `input_audio_buffer.append` events with base64 PCM per the OpenAI Realtime spec. This skill did not run a live Realtime session; treat the event flow as documentation-derived.
