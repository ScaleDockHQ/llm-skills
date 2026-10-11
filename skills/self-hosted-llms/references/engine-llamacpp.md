# llama.cpp `llama-server` + GGUF

> Verified against llama.cpp v0.6.0 and master b11556 (common/common.h default port), 2026-10-11

## What it is and when to choose it

`llama-server` is llama.cpp's HTTP server for GGUF models: small footprint, fast start, CPU/GPU split,
quantized KV cache, multimodal projectors, embeddings and reranking. Choose it for GGUF quants, small and
medium models that should stay co-resident in a non-exclusive llama-swap group, embedding/rerank models,
and anything that needs to start in seconds. Prefer vLLM/SGLang/TRT-LLM for high-concurrency serving of
large safetensors models.

## Install (DGX Spark/arm64 and generic x86)

- **Container (stack default):** `ghcr.io/ggml-org/llama.cpp:server-cuda13` (CUDA 13: Ampere through
  Blackwell including GB10) or `:server-cuda` (CUDA 12); both amd64 + arm64. The image entrypoint is
  `llama-server`, so arguments follow the image name. Pin by digest; tags move with every build.
- **Bundled in llama-swap:** `ghcr.io/mostlygeek/llama-swap:unified-cuda13` (amd64 + arm64, GB10) contains
  `llama-server` (and `sd-server`) built from source. If llama-swap itself runs from that image, a direct
  `cmd: llama-server ...` works without the wrapper.
- **Source:** `cmake -B build -DGGML_CUDA=ON && cmake --build build --config Release -t llama-server`.
  Compiling on a serving Spark competes for unified memory; build with serving stopped or `-j` limited.

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

## Operating

- Start/stop via llama-swap; logs via `docker logs -f small-gguf` or `/logs/stream/small-gguf`.
- Slot state: `curl -s http://127.0.0.1:8080/upstream/small-gguf/slots | jq .`; loaded config:
  `.../upstream/small-gguf/props`.
- Update: pull the new image digest, restart the model (seconds), smoke test tool calls and reasoning
  output; the template engine and parsers change often.

## Tuning knobs worth knowing

- `-c/--ctx-size N` (0 = from model), split across `-np/--parallel` slots unless the unified KV buffer
  (`-kvu`, on when slots are auto) is in use. llama-swap advertises the per-request window.
- `-ngl/--n-gpu-layers N|auto|all`, `-cmoe/--cpu-moe` for MoE offload on discrete GPUs (rarely useful on GB10).
- `-fa/--flash-attn on|off|auto`, `-ctk/-ctv q8_0` (quantized KV; numerics change), `-b`/`-ub` batch sizes.
- `--jinja` is on by default (`--no-jinja` disables); `--chat-template-file` overrides the GGUF template.
- `--reasoning-format`, `--reasoning-budget N`, `--reasoning-effort LEVEL` for thinking models.
- `-hf <user>/<model>[:quant]` downloads from Hugging Face at start; avoid it in the stack (pre-download).
- `--metrics` enables `/metrics`; `--cache-reuse N`, `-cram` tune prompt-cache reuse.
- `--sleep-idle-seconds N` unloads weights while idle; leave unloading to llama-swap `ttl` instead.

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
