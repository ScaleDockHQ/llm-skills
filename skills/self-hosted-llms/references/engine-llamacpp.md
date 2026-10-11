# llama.cpp `llama-server` + GGUF

> Verified against llama.cpp v0.6.0 and master b11556 (common/common.h default port), 2026-10-11

This page keeps only what is specific to this stack: the wrapper script, the llama-swap and LiteLLM entries, and the stack pitfalls. Install, flags, tuning and operating detail live in the product skill.

Depth: install the llama-cpp skill (`npx skills add ScaleDockHQ/llms-skills --skill llama-cpp`).

## Minimal working config

Engine command (standalone):

```bash
docker run --rm --gpus all -p 127.0.0.1:8081:8080 -v /srv/models/gguf:/models:ro \
  ghcr.io/ggml-org/llama.cpp:server-cuda13 \
  -m /models/Qwen3-8B-Q4_K_M.gguf -a small-gguf -c 32768 -ngl all -fa on -np 4 \
  --host 0.0.0.0 --port 8080
curl -s http://127.0.0.1:8081/health
```

Stack wrapper, `/opt/llm-stack/models.d/small-gguf.sh`:

```bash
model_run() {
  docker run -d --name "$MODEL_ID" --label llm-stack.role=engine \
    --gpus all -p "127.0.0.1:${PORT}:8080" -v /srv/models/gguf:/models:ro \
    ghcr.io/ggml-org/llama.cpp:server-cuda13 \
    -m /models/Qwen3-8B-Q4_K_M.gguf -a "$MODEL_ID" -c 32768 -ngl all -fa on -np 4 \
    --host 0.0.0.0 --port 8080
}
```

llama-swap entry (co-resident group member):

```yaml
models:
  small-gguf:
    cmd: /opt/llm-stack/start-model.sh run small-gguf ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop small-gguf
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    disableKeepAlives: true # avoids 502 "proxy error: EOF" right after a stream
    ttl: 900
```

Direct variant when llama-swap runs from the unified image (llama-server listens on loopback by default):

```yaml
small-gguf:
  cmd: llama-server --port ${PORT} -m /models/Qwen3-8B-Q4_K_M.gguf -a ${MODEL_ID} -c 32768 -ngl all -fa on
  disableKeepAlives: true
```

## How it plugs into the stack

- **Port:** llama-swap `${PORT}`. Native defaults are `--host 127.0.0.1 --port 9931` since b11521
  (8080 in v0.6.0 and earlier, which collides with llama-swap), so always pass `--port`.
- **Health:** `GET /health` (also `/v1/health`) is public, returns 503 "Loading model" until ready, then 200. It is exempt from the idle-sleep timer and never triggers a reload, as are `GET /props`, `/models`
  and `/metrics`.
- **Auth:** leave `--api-key`/`--api-key-file` unset on loopback; LiteLLM holds the keys. If you ever set
  one, use `--api-key-file` so the key is not visible in `ps`.
- **APIs:** OpenAI `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/models`,
  `/v1/responses` (plus input-token counting), Anthropic `/v1/messages` and `/v1/messages/count_tokens`,
  plus native `/completion`, `/tokenize`, `/reranking`, `/slots`, `/props`.
- **Capabilities:** llama-swap auto-discovers context, image/audio input and tool support from `/props`
  the first time the model is ready (detected via `owned_by: llamacpp` in `/v1/models`). Set
  `store.path` in llama-swap so discovered values survive restarts.
- **LiteLLM entry:**

```yaml
- model_name: small-gguf
  litellm_params:
    model: openai/small-gguf
    api_base: http://127.0.0.1:8080/v1
    api_key: os.environ/LLAMA_SWAP_API_KEY
```

## Known pitfalls

- 502 `proxy error: EOF` on the request right after a stream: llama-server closes keep-alive connections
  it advertised; set `disableKeepAlives: true` on the llama-swap model.
- A model that describes tool calls in prose usually runs an old build without default `--jinja`, or a GGUF
  whose template lacks tool support; `capabilities.tools` only advertises, it does not enable.
- Forgetting `--port ${PORT}` (direct cmd) or the `-p` mapping (container) makes every request time out.
- Router mode (`--models-dir`, `--models-max`) does its own loading; do not combine it with llama-swap
  swapping for the same models.

## Official links

- Server README (flags, endpoints): https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- Docker images: https://github.com/ggml-org/llama.cpp/blob/master/docs/docker.md
- Repo and releases: https://github.com/ggml-org/llama.cpp
- llama-swap unified image: https://github.com/mostlygeek/llama-swap/tree/main/docker/unified
