# faster-whisper: integrations

> Verified against faster-whisper v1.2.1 README "Community integrations", Speaches master and its docs, 2026-10-11

faster-whisper is a library: it has no HTTP server, CLI or diarization. These projects build on it. The names come from the upstream README; this skill has not verified their versions.

| Need                                   | Project                                                                                                                 | Notes                                                                    |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| OpenAI-compatible HTTP STT (+ TTS)     | [Speaches](https://github.com/speaches-ai/speaches)                                                                     | the `speaches` skill; streaming, dynamic model loading, Realtime API     |
| Word alignment and speaker diarization | [WhisperX](https://github.com/m-bain/whisperX)                                                                          | wav2vec2 alignment on top of faster-whisper; separate install and models |
| openai/whisper-compatible CLI          | [whisper-ctranslate2](https://github.com/Softcatala/whisper-ctranslate2)                                                | drop-in command line                                                     |
| Diarization pipeline                   | [whisper-diarization](https://github.com/MahmoudAshraf97/whisper-diarization)                                           | faster-whisper plus NVIDIA NeMo                                          |
| Near-live transcription                | [WhisperLive](https://github.com/collabora/WhisperLive), [Whisper-Streaming](https://github.com/ufal/whisper_streaming) | streaming policies on top of the library                                 |
| OpenAI/Home Assistant-style API        | [Whisper-FastAPI](https://github.com/heimoshuiyu/whisper-fastapi)                                                       | simple script; check licence and maintenance before use                  |

## Serving over HTTP

Prefer Speaches over a hand-written server: it already handles model loading and unloading, VAD defaults, `multipart/form-data` uploads and the OpenAI response formats. Install with the `speaches` skill (`npx skills add ScaleDockHQ/llms-skills --skill speaches`).

If you must embed faster-whisper in your own service:

- Load the model once at process start, not per request.
- Consume `segments` inside the request handler (it is a generator), and cap upload size and duration.
- One `WhisperModel` serves one decode at a time per worker; use `num_workers` or more processes for concurrency.
- Bind to loopback and put authentication in front; uploads are untrusted input.

## Evaluation helper

F5-TTS lists faster-whisper (pinned `faster_whisper==0.10.1` in its `eval` extra) as an ASR tool for evaluation; do not mix that old pin into an environment that needs v1.x.
