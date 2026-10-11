# whisper.cpp: server HTTP API

> Verified against whisper.cpp v1.9.5 (examples/server/server.cpp at the tag), 2026-10-11

Everything here is read from `server.cpp`; the README documents only part of it. Routes and the `--request-path`/`--inference-path` mapping are in `serve-configuration.md`. Examples use the default `/inference` route.

## POST /inference

Multipart form (`curl -F`). The only required field is `file`. The server copies its launch defaults, then overrides them with any field present.

```bash
curl -fsS http://127.0.0.1:8080/inference \
  -F file=@samples/jfk.wav \
  -F response_format=json \
  -F language=auto \
  -F temperature=0.0 \
  -F temperature_inc=0.2
```

### Fields read at v1.9.5

| Field                                                                                                                                                        | Notes                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| `file`                                                                                                                                                       | required; audio bytes. Non-WAV needs the server started with `--convert` and ffmpeg  |
| `response_format`                                                                                                                                            | `json` (default), `text`, `srt`, `vtt`, `verbose_json`; any other value gives `json` |
| `language`, `detect_language`                                                                                                                                | code such as `nl`, or `auto`                                                         |
| `translate`                                                                                                                                                  | translate to English (multilingual model)                                            |
| `prompt`, `carry_initial_prompt`                                                                                                                             | initial prompt                                                                       |
| `temperature`, `temperature_inc`                                                                                                                             | sampling temperature and fallback increment                                          |
| `best_of`, `beam_size`                                                                                                                                       | decoding strategy (`beam_size > 1` selects beam search)                              |
| `offset_t`, `offset_n`, `duration`                                                                                                                           | start offset (ms), segment offset, duration (ms)                                     |
| `max_context`, `max_len`, `split_on_word`, `audio_ctx`                                                                                                       | context and segment controls                                                         |
| `word_thold`, `entropy_thold`, `logprob_thold`, `no_speech_thold`                                                                                            | thresholds                                                                           |
| `no_timestamps`, `token_timestamps`                                                                                                                          | timestamp controls; word times in `verbose_json` need `token_timestamps`             |
| `diarize`, `tinydiarize`                                                                                                                                     | stereo diarization; tinydiarize model needed                                         |
| `suppress_non_speech`, `suppress_nst`                                                                                                                        | token suppression                                                                    |
| `vad`, `vad_threshold`, `vad_min_speech_duration_ms`, `vad_min_silence_duration_ms`, `vad_max_speech_duration_s`, `vad_speech_pad_ms`, `vad_samples_overlap` | per-request VAD (the server must have `-vm` set)                                     |
| `no_language_probabilities`                                                                                                                                  | skip the language-probability pass in `verbose_json`                                 |
| `debug_mode`                                                                                                                                                 | verbose server log                                                                   |

A `model` field exists only on `/load`. Sending `-F model=whisper-1` to `/inference`, as OpenAI clients do, is accepted and **ignored**: the loaded model answers.

### Responses

- `json`: `{"text": "..."}`, `application/json`.
- `text`: plain text, content type `text/html; charset=utf-8`.
- `srt`, `vtt`: subtitle bodies (`vtt` is `text/vtt`).
- `verbose_json`, shaped to resemble OpenAI's: `task`, `language` (full name, such as `english`), `duration` (seconds), `text`, `segments[]` (`id`, `text`, `start`, `end`, `tokens`, `words[]`, `temperature`, `avg_logprob`, `no_speech_prob`), plus `detected_language`, `detected_language_probability` and `language_probabilities` unless `no_language_probabilities` is set. The source marks `compression_ratio` as not implemented, and it is absent. Word `start`/`end` appear only with `token_timestamps` and timestamps on.

Errors are JSON `{"error": "..."}`: `400` missing `file`, or unreadable audio (`failed to read audio data`, `failed to read WAV file`); `500` ffmpeg failure or an inference error; `499` when the client disconnected during decoding. A plain HTTP 200 therefore means a transcript, but check the status in scripts (`curl -f`).

### OpenAI compatibility, honestly

With `--request-path /v1/audio --inference-path /transcriptions` a client such as the `openai` SDK's `audio.transcriptions.create` reaches the server and gets `{"text": ...}` for `response_format=json`. Gaps against the real API:

- no `/v1/models`, no auth check (any `Authorization` header is ignored), no `timestamp_granularities[]` (use `token_timestamps` and `verbose_json` instead);
- `model` is ignored, `language` must be a code or `auto`;
- `text` is served as `text/html`.

If you need an exact OpenAI surface or `/v1/models`, front it with llama-swap, which proxies `/v1/audio/transcriptions` and picks the upstream from the `model` form field (see `combos/llama-swap-litellm.md`) or use Speaches (`self-hosted-genmedia`).

## POST /load

```bash
curl -fsS http://127.0.0.1:8080/load -F model=/models/whisper/ggml-small-q5_1.bin
```

`model` is a path **on the server host**. Success returns the text `Load was successful!`; a missing field or file returns `400`. The old model is freed first and if loading fails the process exits. Not a good fit for a networked deployment: whoever reaches the port can make it read any path.

## GET /health

`200 {"status":"ok"}` when serving, `503 {"status":"loading model"}` during `/load`. Use it for readiness checks and llama-swap's `checkEndpoint`.

## Streaming

No streaming transcription over HTTP in `whisper-server`. For live microphone input use `whisper-stream` (SDL2 build) or the `whisper-command` example (`install.md`).
