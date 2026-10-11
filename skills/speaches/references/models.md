# Speaches: models

> Verified against Speaches master docs (usage/model-discovery, speech-to-text, text-to-speech), `model_aliases.json`, `routers/models.py`, speaches-cli 0.1.0, 2026-10-11

Speaches loads models by Hugging Face repo id. Two groups exist: STT models (CTranslate2 Whisper conversions that faster-whisper can read) and TTS models (Kokoro ONNX and Piper). Download first, then call.

## Browse

```bash
B=http://127.0.0.1:8000
curl -sS "$B/v1/registry?task=automatic-speech-recognition" | jq -r '.data[].id' | head -30
curl -sS "$B/v1/registry?task=text-to-speech" | jq -r '.data[].id'
curl -sS "$B/v1/models" | jq -r '.data[].id'                   # already downloaded
```

Add `-H "Authorization: Bearer $SPEACHES_API_KEY"` when a key is set.

## Download and delete

```bash
curl -sS -X POST "$B/v1/models/Systran/faster-distil-whisper-small.en"     # 200 downloaded, 201 already there
curl -sS -X POST "$B/v1/models/speaches-ai/Kokoro-82M-v1.0-ONNX"
curl -sS -X DELETE "$B/v1/models/Systran/faster-distil-whisper-small.en"   # ask first
```

Equivalent CLI from upstream docs, run on the host and not inside the container: `uvx speaches-cli model download <id>`, `uvx speaches-cli registry ls --task automatic-speech-recognition`, `uvx speaches-cli model ls`. Set `SPEACHES_BASE_URL` for the CLI. The PyPI package is version 0.1.0 from 2025-03-24 and needs Python 3.12; if it fails, use the curl calls above.

Gated or private repos return 401 on download: pass `HF_TOKEN` in the container environment (from the env file), not in the URL.

## Ids used in upstream docs

| Use                | Model id                                                                                               |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| small English STT  | `Systran/faster-distil-whisper-small.en`                                                               |
| multilingual STT   | `Systran/faster-whisper-small`, `Systran/faster-whisper-large-v3`                                      |
| fast large STT     | `deepdml/faster-whisper-large-v3-turbo-ct2` (Realtime docs)                                            |
| Open WebUI example | `Systran/faster-distil-whisper-large-v3`                                                               |
| TTS (Kokoro, ONNX) | `speaches-ai/Kokoro-82M-v1.0-ONNX`, voice `af_heart`                                                   |
| TTS (Piper)        | `rhasspy/piper-voices` (named in the `PRELOAD_MODELS` docstring)                                       |
| Realtime defaults  | STT `Systran/faster-distil-whisper-small.en`, TTS `speaches-ai/Kokoro-82M-v1.0-ONNX`, voice `af_heart` |

Aliases in `model_aliases.json`: `tts-1` and `tts-1-hd` to `speaches-ai/Kokoro-82M-v1.0-ONNX`, `whisper-1` to `Systran/faster-whisper-large-v3`. Whatever you ask for must be downloaded.

Model weights have their own licences (`Systran` Whisper conversions list `mit`, `hexgrad/Kokoro-82M` lists `apache-2.0` on the Hub on 2026-10-11); check cards before commercial use.

## Preload

```bash
-e 'PRELOAD_MODELS=["Systran/faster-whisper-small","speaches-ai/Kokoro-82M-v1.0-ONNX"]'
```

Models download sequentially at startup; the application exits if any is missing from the registry or fails to download. Useful to fail fast on a node that lacks weights; avoid on slow links.

## Idle unload and warm models

Models unload after `STT_MODEL_TTL` / `TTS_MODEL_TTL` seconds idle (default 300). For latency-sensitive use set `-1` and warm with `POST /api/ps/{id}`. Memory sizing for co-residency with an LLM belongs to `self-hosted-genmedia`.

## Cache

Weights live in the Hugging Face hub cache inside the container (`/home/ubuntu/.cache/huggingface/hub`); mount a named volume so they survive container recreation (`install.md`). For offline hosts set `HF_HUB_OFFLINE=1` after downloading.
