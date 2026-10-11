# Speaches under llama-swap, with LiteLLM in front

> Verified against Speaches master compose files, llama-swap v263 (docs/config.example.yaml Docker example) and LiteLLM v1.105.0 audio docs, 2026-10-11

The combined stack was not run live when this file was written.

Stack: `client -> LiteLLM :4000 -> llama-swap :8080 -> speaches container :${PORT}`. llama-swap starts the container on the first request, routes by the multipart or JSON `model`, and stops it with `docker stop` when idle or evicted.

## 1. llama-swap entry

```yaml
models:
  "speaches":
    proxy: http://127.0.0.1:${PORT}
    cmd: |
      docker run --name ${MODEL_ID} --init --rm
      --publish 127.0.0.1:${PORT}:8000
      --volume hf-hub-cache:/home/ubuntu/.cache/huggingface/hub
      --env-file ${env.HOME}/.config/speaches.env
      --gpus=all
      ghcr.io/speaches-ai/speaches:latest-cuda
    cmdStop: docker stop ${MODEL_ID}
    useModelName: Systran/faster-whisper-small # what the container receives as `model`
    checkEndpoint: /health
    ttl: 600
    unloadTimeout: 30
```

- `proxy`, `cmd`, `cmdStop` and `${MODEL_ID}` are the pattern in llama-swap's own Docker example.
- `checkEndpoint: /health` is public in Speaches even with `API_KEY` set.
- llama-swap picks the upstream from the request `model` field. Clients must send the llama-swap model id (`speaches` here), but Speaches itself needs a real Hugging Face model id in `model`. Use llama-swap `useModelName` to rewrite it per entry, or define one entry per Speaches model id. The `useModelName` option exists (`docs/config.example.yaml`); the multipart rewrite behaviour is documented in the `self-hosted-genmedia` skill and was not retested here.
- Speaches already unloads its own models (`STT_MODEL_TTL`); the llama-swap `ttl` frees the whole container and its CUDA context.
- Sharing the GPU with an LLM: put both in an exclusive swap group (see the `llama-swap` skill).

## 2. LiteLLM

Point LiteLLM at llama-swap, not at Speaches (`templates/litellm-speaches.yaml` shows both targets):

```yaml
model_list:
  - model_name: whisper
    litellm_params:
      model: openai/speaches # llama-swap id after the openai/ prefix
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/LLAMA_SWAP_API_KEY
    model_info:
      mode: audio_transcription
```

## 3. Test each hop

```bash
scripts/transcribe.sh sample.wav                                   # hop 0: Speaches alone on its own port
curl -fsS http://127.0.0.1:8080/v1/audio/transcriptions -H "Authorization: Bearer $LLAMA_SWAP_API_KEY" \
  -F file=@sample.wav -F model=speaches | jq -r .text              # hop 1: llama-swap starts the container
curl -fsS http://127.0.0.1:4000/v1/audio/transcriptions -H "Authorization: Bearer $LITELLM_KEY" \
  -F file=@sample.wav -F model=whisper | jq -r .text               # hop 2: LiteLLM
```

## Pitfalls

- The model id the container sees is whatever llama-swap forwards. If a download is missing you get a Speaches error body, not a llama-swap one.
- First request after a cold start includes image start, CUDA init and model load; raise client timeouts (LiteLLM `timeout: 600`).
- Do not also run a long-lived `speaches` container on the same port or name.
