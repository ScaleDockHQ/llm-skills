# Infinity with llama-swap

> Verified against infinity_emb 0.0.77 and llama-swap v263 (config patterns from the llama-swap skill), 2026-10-11

Normally run Infinity always-on beside the swapped chat models and reserve its VRAM. Use llama-swap only when memory is tight (`templates/llama-swap-snippet.yaml`):

```yaml
models:
  "embed-bge":
    proxy: "http://127.0.0.1:${PORT}"
    cmd: |
      docker run --name ${MODEL_ID} --init --rm --gpus all --env-file ${env.INFINITY_ENV_FILE}
      -p 127.0.0.1:${PORT}:7997 -v ${env.INFINITY_CACHE}:/app/.cache
      michaelf34/infinity:0.0.77 v2 --model-id BAAI/bge-small-en-v1.5 --port 7997
    cmdStop: docker stop ${MODEL_ID}
    checkEndpoint: /health
    ttl: 600
```

- `/health` returns when the server is up; with warmup enabled the server is ready after models load. Raise `healthCheckTimeout` for first-time downloads.
- Put it in a group with `swap: false` so it does not evict the chat model.
- Routing of `/v1/embeddings` through llama-swap depends on its OpenAI-compatible routing and on Infinity's lack of a `/v1` prefix; verify with a test request, or set `--url-prefix /v1`.
