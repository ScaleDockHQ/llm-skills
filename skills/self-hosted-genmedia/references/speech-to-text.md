# Speech-to-text servers: whisper.cpp, Speaches, vLLM

> Verified against whisper.cpp v1.9.5, Speaches v0.9.0-rc.3 (master), vLLM docs (speech_to_text) and LiteLLM v1.105.0, 2026-10-11

## What it is and when to choose it

All three expose Whisper-family transcription over HTTP. They differ in OpenAI compatibility and in how they manage models:

| Server                                                                        | Endpoint                                                              | Models                                                               | Fit                                                            |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------- |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) `whisper-server` (MIT) | `/inference` by default; can be mounted at `/v1/audio/transcriptions` | one ggml model per process (`-m`), hot-swappable via `/load`         | smallest footprint, C++ only, easy llama-swap entry            |
| [Speaches](https://github.com/speaches-ai/speaches) (MIT)                     | `/v1/audio/transcriptions`, `/v1/audio/translations` (plus TTS)       | faster-whisper models by HF id, loaded on demand, unloaded after TTL | OpenAI-shaped multi-model server; STT and TTS in one container |
| [vLLM](https://docs.vllm.ai)                                                  | `/v1/audio/transcriptions`, `/v1/audio/translations`                  | `openai/whisper-*` and other STT models                              | high throughput when vLLM is already your engine               |

Pick whisper.cpp for a lean, single-model service; Speaches for OpenAI-compatible STT plus TTS with built-in model management; vLLM when you're already running vLLM and need batching.

## Install

**whisper.cpp:** build from source with the backend you need and download a ggml model. Build flags, the Docker platform caveat and models are in the whisper-cpp skill (depth line at the end of this file).

**Speaches (Docker, amd64 and arm64 images):**

```bash
# container-side HF cache path, read from upstream's compose file
SPEACHES_CACHE_DIR="$(curl -s https://raw.githubusercontent.com/speaches-ai/speaches/master/compose.cuda.yaml \
  | awk -F'hf-hub-cache:' '/hf-hub-cache:\//{print $2; exit}')"
docker run --rm --detach --name speaches \
  --publish 127.0.0.1:8000:8000 \
  --volume "hf-hub-cache:$SPEACHES_CACHE_DIR" \
  --gpus=all \
  -e API_KEY="$SPEACHES_API_KEY" \
  ghcr.io/speaches-ai/speaches:latest-cuda
```

`latest-cpu` is the CPU image; `latest-cuda-12.6.3` pins an older CUDA base. Compose files (`compose.yaml` + `compose.cuda.yaml`) are in the repo. A `uv` source install is documented too.

**vLLM:** `pip install "vllm[audio]"`, then `vllm serve openai/whisper-large-v3-turbo`. Engine install and tuning belong to the `self-hosted-llms` skill.

## Minimal working config/command

**whisper-server with an OpenAI-shaped path:** start it with `--request-path /v1/audio --inference-path /transcriptions` (plus `-l auto`, and `--convert` if ffmpeg is installed). That serves `POST /v1/audio/transcriptions` and `GET /v1/audio/health`.

**Speaches:**

```bash
export SPEACHES_BASE_URL=http://127.0.0.1:8000
uvx speaches-cli model download Systran/faster-distil-whisper-small.en
curl -sS "$SPEACHES_BASE_URL/v1/audio/transcriptions" \
  -H "Authorization: Bearer $SPEACHES_API_KEY" \
  -F file=@sample.wav -F model=Systran/faster-distil-whisper-small.en \
  | jq -r .text > transcript.txt
```

Browse STT models with `uvx speaches-cli registry ls --task automatic-speech-recognition`.

## How it plugs into the stack

- **Format in:** `multipart/form-data` with `file` and `model` (the OpenAI shape). llama-swap reads `model` from the form to pick the upstream and applies `useModelName` rewrites to multipart bodies too.
- **Health:**
  - whisper-server `GET <request-path>/health` returns 200 `{"status":"ok"}` when ready and 503 while loading. It's a good `checkEndpoint`.
  - Speaches `GET /health` stays public even when `API_KEY` is set.
- **Auth:**
  - whisper-server has none: bind it to `127.0.0.1`.
  - Speaches enforces `API_KEY` on its API routes when set; its web UI, `/docs` and `/openapi.json` stay public. Disable the UI with `ENABLE_UI=false` on shared hosts.
- **Binding:** Speaches listens on `0.0.0.0` inside the container (`UVICORN_HOST`). Publish with `127.0.0.1:` on the host.
- **LiteLLM:**

  ```yaml
  - model_name: whisper
    litellm_params:
      model: openai/whisper # llama-swap model id after the prefix
      api_base: http://127.0.0.1:8080/v1 # llama-swap
      api_key: os.environ/LLAMA_SWAP_KEY
    model_info:
      mode: audio_transcription
  ```

## Operating

- whisper-server holds one model and serves one request at a time. In a llama-swap setup, prefer separate entries per model.
- Speaches unloads idle models after `STT_MODEL_TTL` seconds (default 300; `-1` never, `0` immediately). `GET /api/ps` lists loaded models; `DELETE /api/ps/{model}` unloads one.
- Speaches `PRELOAD_MODELS='["Systran/faster-whisper-large-v3"]'` downloads models at startup and exits if any download fails. Use it to fail fast when a node lacks weights.
- Long recordings take a while. Over Cloudflare a synchronous transcription of a long file can exceed the 125 s read timeout; split audio or use a tailnet path.

## Tuning knobs worth knowing

| Server   | Knob                         | Effect                                                       |
| -------- | ---------------------------- | ------------------------------------------------------------ |
| Speaches | `WHISPER__INFERENCE_DEVICE`  | device selection (nested settings use `__`)                  |
| Speaches | `WHISPER__COMPUTE_TYPE=int8` | quantized compute                                            |
| Speaches | `STT_MODEL_TTL`              | idle unload time                                             |
| Speaches | `LOG_LEVEL`                  | log verbosity (default `debug`)                              |
| vLLM     | see the vLLM docs            | beam search is supported but slow for encoder-decoder models |

## Known pitfalls

- whisper-server defaults to `-l en`; pass `-l auto`. It has no auth and accepts uploads: sandbox it. Details are in the whisper-cpp skill.
- `openai/whisper-large-v3-turbo` doesn't translate (per the vLLM docs). Use a non-turbo model for `/v1/audio/translations`.
- OpenAI SDKs need a non-empty API key even when the server has none. Use any placeholder when talking to an auth-less backend directly.
- Whisper weights: the openai/whisper repo says MIT; some HF cards list Apache-2.0. Both are permissive; see `licenses.md`.

Depth: install the whisper-cpp skill (npx skills add ScaleDockHQ/llms-skills --skill whisper-cpp)

## Official links

- whisper.cpp: https://github.com/ggml-org/whisper.cpp
- whisper-server README: https://github.com/ggml-org/whisper.cpp/blob/master/examples/server/README.md
- Speaches docs: https://speaches.ai/
- Speaches repo: https://github.com/speaches-ai/speaches
- vLLM speech-to-text: https://docs.vllm.ai/en/latest/serving/online_serving/speech_to_text.html
- LiteLLM transcription: https://docs.litellm.ai/docs/audio_transcription
