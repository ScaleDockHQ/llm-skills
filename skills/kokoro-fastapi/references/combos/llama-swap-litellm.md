# Kokoro-FastAPI under llama-swap, with LiteLLM in front

> Verified against Kokoro-FastAPI v0.9.0, llama-swap v263 (docs/config.example.yaml Docker example) and LiteLLM v1.105.0 audio docs, 2026-10-11

The combined stack was not run live when this file was written.

Stack: `client -> LiteLLM :4000 -> llama-swap :8080 -> kokoro container :${PORT}`. llama-swap starts the container on the first `/v1/audio/speech` request and stops it when idle or evicted by an LLM, which frees VRAM on a shared GPU.

## 1. llama-swap entry

```yaml
models:
  "kokoro":
    proxy: http://127.0.0.1:${PORT}
    cmd: |
      docker run --name ${MODEL_ID} --init --rm --gpus all
      -p 127.0.0.1:${PORT}:8880
      ghcr.io/remsky/kokoro-fastapi-gpu:v0.9.0
    cmdStop: docker stop ${MODEL_ID}
    checkEndpoint: /health
    ttl: 300
    unloadTimeout: 30
```

- `proxy`, `cmd`, `cmdStop` and `${MODEL_ID}` follow llama-swap's own Docker example.
- Kokoro-FastAPI expects `model` to be `kokoro`, `tts-1` or `tts-1-hd`. If clients send the llama-swap id `kokoro`, it works as is; if you register another id, add `useModelName: kokoro`.
- `/health` returns 200 `{"status":"healthy"}` once the model is warm. The server loads and warms at startup using `DEFAULT_VOICE`, so allow time for the first start (`healthCheckTimeout` in llama-swap).
- The image bakes the model in, so there is no download at start. Auth is absent; bind to loopback as shown.
- To share a GPU with an LLM, put both entries in an exclusive swap group (`llama-swap` skill).

## 2. LiteLLM

```yaml
model_list:
  - model_name: tts
    litellm_params:
      model: openai/kokoro # llama-swap id after openai/
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/LLAMA_SWAP_API_KEY
    model_info:
      mode: audio_speech
      health_check_voice: af_heart
```

## 3. Test each hop

```bash
scripts/speak.sh "Hello" hop0.mp3                                   # Kokoro alone (start it by hand)
curl -fsS http://127.0.0.1:8080/v1/audio/speech -H "Authorization: Bearer $LLAMA_SWAP_API_KEY" \
  -H 'Content-Type: application/json' -d '{"model":"kokoro","voice":"af_heart","input":"Hello"}' -o hop1.mp3
curl -fsS http://127.0.0.1:4000/v1/audio/speech -H "Authorization: Bearer $LITELLM_KEY" \
  -H 'Content-Type: application/json' -d '{"model":"tts","voice":"af_heart","input":"Hello"}' -o hop2.mp3
file hop*.mp3
```

## Pitfalls

- A container left running by hand on the same port or name blocks llama-swap's `docker run`.
- Cold start includes image start, CUDA init and warm-up; raise client timeouts.
- `docker stop` can exceed llama-swap's default unload timeout; keep `unloadTimeout` generous.
