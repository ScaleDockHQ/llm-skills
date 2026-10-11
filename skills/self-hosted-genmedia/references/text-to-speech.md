# Text-to-speech servers: Kokoro-FastAPI and Speaches

> Verified against Kokoro-FastAPI v0.9.0, Speaches v0.9.0-rc.3 (master) and LiteLLM v1.105.0, 2026-10-11

## What it is and when to choose it

Both serve the OpenAI `POST /v1/audio/speech` shape (`model`, `input`, `voice`, `response_format`, `speed`) and return audio bytes.

| Server                                                                  | Engine                                                                        | Port | Fit                                                                                                  |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ---- | ---------------------------------------------------------------------------------------------------- |
| [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI) (Apache-2.0) | [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) (Apache-2.0), PyTorch | 8880 | TTS only; rich voice features (voice mixing, aliases, inline multi-speaker tags, captions, phonemes) |
| [Speaches](https://github.com/speaches-ai/speaches) (MIT)               | Kokoro (ONNX) and Piper                                                       | 8000 | STT and TTS in one OpenAI-compatible container, models by HF id with TTL unload                      |

Pick Kokoro-FastAPI for the best Kokoro feature set. Pick Speaches if you already run it for STT and want one container. No other TTS servers are covered here; their OpenAI compatibility wasn't verified.

Kokoro is small (82M parameters) and can run on CPU, so it's a natural **co-resident** service next to LLMs rather than something to swap.

## Install

**Kokoro-FastAPI (Docker):**

| Image                                                         | Platforms    | Notes                                                                                   |
| ------------------------------------------------------------- | ------------ | --------------------------------------------------------------------------------------- |
| `ghcr.io/remsky/kokoro-fastapi-cpu:latest`                    | amd64, arm64 | CPU                                                                                     |
| `ghcr.io/remsky/kokoro-fastapi-gpu:latest` (= `latest-cu126`) | amd64, arm64 | README: GTX 900 through RTX 40 on amd64; the arm64 variant ships cu129 for Jetson/GH200 |
| `ghcr.io/remsky/kokoro-fastapi-gpu:latest-cu128`              | amd64        | RTX 50-series / Blackwell                                                               |
| `ghcr.io/remsky/kokoro-fastapi-rocm:latest`                   | amd64        | experimental                                                                            |

```bash
docker run --rm --detach --name kokoro --gpus all \
  -p 127.0.0.1:8880:8880 \
  ghcr.io/remsky/kokoro-fastapi-gpu:latest
```

DGX Spark (arm64 Blackwell) isn't named in the README. Whether the arm64 GPU image runs on GB10 is **(unverified)**: try it and check the logs for a CUDA device, and fall back to `kokoro-fastapi-cpu:latest` (arm64), which is a reasonable default for a co-resident TTS service anyway.

**Speaches:** same container as STT (see `speech-to-text.md`), then download a TTS model:

```bash
uvx speaches-cli model download speaches-ai/Kokoro-82M-v1.0-ONNX
```

## Minimal working config/command

Kokoro-FastAPI smoke test, writing audio to a file:

```bash
curl -sS http://127.0.0.1:8880/v1/audio/voices | jq -r '.voices[].id' | head
curl -sS http://127.0.0.1:8880/v1/audio/speech -H 'Content-Type: application/json' \
  -d '{"model":"kokoro","input":"Hello from the self-hosted stack.","voice":"af_heart","response_format":"mp3"}' \
  -o hello.mp3
file hello.mp3
```

`response_format`: `mp3`, `wav`, `opus`, `flac`, `aac`, `pcm`. Weighted voice blends like `"af_bella(2)+af_sky(1)"` are accepted as `voice`, and `/v1/audio/voices/combine` returns the combined voice pack as a `.pt` file.

Speaches:

```bash
curl -sS http://127.0.0.1:8000/v1/audio/speech \
  -H "Authorization: Bearer $SPEACHES_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"speaches-ai/Kokoro-82M-v1.0-ONNX","voice":"af_heart","input":"Hello","response_format":"wav"}' \
  -o hello.wav
```

## How it plugs into the stack

- **Format in:** JSON. **Out:** raw audio bytes (not base64). Always use `-o file` in curl.
- **Health:** Kokoro-FastAPI `GET /health` returns `{"status":"healthy"}`; Speaches `GET /health`. Both make good llama-swap `checkEndpoint`s.
- **Auth:**
  - Kokoro-FastAPI has no API-key setting; bind to loopback (`-p 127.0.0.1:...`) and enforce keys at LiteLLM.
  - Speaches supports `API_KEY` (Bearer).
- **CORS:** Kokoro-FastAPI defaults `CORS_ORIGINS` to `["*"]`; narrow it if the port is reachable beyond localhost. `ENABLE_DEBUG_ENDPOINTS` defaults to `false`; keep it that way.
- **llama-swap:** routes `v1/audio/speech` and `v1/audio/voices`. The `model` in the request selects the llama-swap entry. Kokoro-FastAPI expects `model: "kokoro"`, so set `useModelName: kokoro` if your llama-swap id differs.
- **LiteLLM:**

  ```yaml
  - model_name: tts
    litellm_params:
      model: openai/tts # llama-swap model id after the prefix
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/LLAMA_SWAP_KEY
    model_info:
      mode: audio_speech
      health_check_voice: af_heart
  ```

  LiteLLM's health check needs `health_check_voice` for `audio_speech` models.

## Operating

- Kokoro-FastAPI warms the model at startup using `DEFAULT_VOICE` (default `af_heart`), so the first request after start isn't cold.
- Speaches unloads TTS models after `TTS_MODEL_TTL` seconds (default 300).
- Environment variables for Kokoro-FastAPI are the uppercased field names of `api/src/core/config.py`. In compose, `environment:` wins over `env_file`, and some variables (`USE_GPU`, `DOWNLOAD_MODEL`, ...) are pinned in the compose file.
- Long inputs are chunked server-side (`TARGET_MIN_TOKENS`, `TARGET_MAX_TOKENS`, `ABSOLUTE_MAX_TOKENS`); very long texts still take a while. Stream (`"stream": true` with the OpenAI client) or split text for interactive use.

## Tuning knobs worth knowing

| Variable                 | Default            | Effect                                        |
| ------------------------ | ------------------ | --------------------------------------------- |
| `HOST` / `PORT`          | `0.0.0.0` / `8880` | bind address inside the container             |
| `USE_GPU`                | `true`             | use the GPU if available                      |
| `DEFAULT_VOICE`          | `af_heart`         | voice when a request omits one; warm-up voice |
| `CORS_ORIGINS`           | `["*"]`            | allowed browser origins                       |
| `API_LOG_LEVEL`          | —                  | logging level                                 |
| Speaches `TTS_MODEL_TTL` | `300`              | idle unload seconds (`-1` never)              |

## Known pitfalls

- Publishing `-p 8880:8880` without `127.0.0.1:` exposes an unauthenticated TTS API on every interface.
- The `-cu128` Kokoro tag is amd64-only. On arm64, use `:latest` (GPU) or the CPU image.
- `/dev/tune` voice tuning: upstream says to tune only voices you have permission to use. Consent and impersonation rules apply to any voice-cloning-like feature.
- Kokoro takes the language code from the first letter of the voice name (`af_...`, `bf_...`). A voice whose language doesn't match the text gives odd pronunciation; `DEFAULT_VOICE_CODE` overrides the code for every speaker.

## Official links

- Kokoro-FastAPI: https://github.com/remsky/Kokoro-FastAPI
- Kokoro-FastAPI configuration: https://github.com/remsky/Kokoro-FastAPI/blob/master/docs/configuration.md
- Kokoro-82M model card: https://huggingface.co/hexgrad/Kokoro-82M
- Speaches TTS: https://speaches.ai/usage/text-to-speech/
- LiteLLM speech: https://docs.litellm.ai/docs/text_to_speech
