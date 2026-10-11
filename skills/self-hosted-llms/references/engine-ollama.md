# Ollama as a backend

> Verified against Ollama v0.40.3, 2026-10-11

## What it is and when to choose it

Ollama is a model runner with its own model library (`ollama pull`), Modelfiles and an always-on server
that loads and unloads models on demand. In this stack it is a **backend**, not the front door: useful
when a model is only conveniently packaged for Ollama, when users already maintain an Ollama library, or
for quick experiments. For anything you tune seriously, llama.cpp (same GGUF family, explicit flags) or
vLLM/SGLang fit the stack better.

The key design issue: **Ollama schedules models itself** (keep-alive timers, max loaded models, queueing
when memory is short). llama-swap also schedules. Two schedulers sharing one memory pool will fight, so
pick one of these patterns:

1. **One Ollama instance per llama-swap model ID** (recommended behind llama-swap): the wrapper starts a
   dedicated Ollama container for that model with `OLLAMA_MAX_LOADED_MODELS=1` and `OLLAMA_KEEP_ALIVE=-1`;
   llama-swap's group, `ttl` and swaps decide lifetime. Several IDs can share one read-only model store.
2. **One persistent Ollama with a fixed memory slice**, outside llama-swap: run it as its own service,
   size it (`OLLAMA_MAX_LOADED_MODELS`, `OLLAMA_CONTEXT_LENGTH`, `OLLAMA_NUM_PARALLEL`) so its worst case
   fits beside your llama-swap groups, and point LiteLLM straight at it. Never let llama-swap swap
   exclusive models into the memory Ollama believes it owns.

## Install (DGX Spark/arm64 and generic x86)

- **Container (stack default):** `ollama/ollama:0.40.3` (amd64 + arm64). GPU via NVIDIA Container
  Toolkit and `--gpus=all`. The image listens on all interfaces inside the container; publish on loopback.
- **Native:** `curl -fsSL https://ollama.com/install.sh | sh` installs a systemd unit `ollama.service`
  (NVIDIA's DGX Spark Ollama playbook uses this). Set variables with `sudo systemctl edit ollama` →
  `[Service]` `Environment="OLLAMA_HOST=127.0.0.1:11434"`, then `daemon-reload` and restart.
- Keep models out of the image: mount a volume at `/root/.ollama` (or set `OLLAMA_MODELS`).

## Minimal working config

Engine command (pattern 2, persistent instance on loopback):

```bash
docker run -d --name ollama --restart unless-stopped --gpus=all \
  -p 127.0.0.1:11434:11434 -v /srv/ollama:/root/.ollama \
  -e OLLAMA_MAX_LOADED_MODELS=1 -e OLLAMA_CONTEXT_LENGTH=32768 -e OLLAMA_NUM_PARALLEL=2 \
  ollama/ollama:0.40.3
docker exec ollama ollama pull qwen3:8b && curl -s http://127.0.0.1:11434/api/version
```

Pattern 1, `/opt/llm-stack/models.d/ollama-qwen3.sh`:

```bash
model_run() {
  docker run -d --name "$MODEL_ID" --label llm-stack.role=engine \
    --gpus=all -p "127.0.0.1:${PORT}:11434" -v /srv/ollama:/root/.ollama \
    -e OLLAMA_MAX_LOADED_MODELS=1 -e OLLAMA_KEEP_ALIVE=-1 -e OLLAMA_NOPRUNE=1 \
    -e OLLAMA_CONTEXT_LENGTH=32768 -e OLLAMA_NUM_PARALLEL=2 \
    ollama/ollama:0.40.3
}
```

`OLLAMA_NOPRUNE=1` stops each instance from pruning blobs in the shared store at startup. llama-swap entry:

```yaml
models:
  ollama-qwen3:
    cmd: /opt/llm-stack/start-model.sh run ollama-qwen3 ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop ollama-qwen3
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /api/version
    useModelName: qwen3:8b       # the name Ollama knows the model by
    ttl: 600
```

`/api/version` answers as soon as the server is up and loads nothing, so the first real request pays the
model load. To warm it, send an empty generate after start (`curl .../api/generate -d '{"model":"qwen3:8b"}'`).

## How it plugs into the stack

- **Port:** default `127.0.0.1:11434` (`OLLAMA_HOST`); pattern 1 publishes llama-swap's `${PORT}`.
- **Health:** `GET /api/version` (or `GET /`, "Ollama is running"): neither loads a model. `GET /api/ps`
  lists loaded models; `GET /api/tags` lists local ones.
- **Auth:** none on loopback; LiteLLM holds the keys. Do not set `OLLAMA_HOST=0.0.0.0` on the host.
- **APIs:** native `/api/chat`, `/api/generate`, `/api/embed`; OpenAI `/v1/chat/completions`,
  `/v1/completions`, `/v1/embeddings`, `/v1/models`, `/v1/responses`; Anthropic `/v1/messages`.
- **LiteLLM entry** (through llama-swap; for pattern 2 use `api_base: http://127.0.0.1:11434/v1` and
  `model: openai/qwen3:8b`):

```yaml
  - model_name: ollama-qwen3
    litellm_params:
      model: openai/ollama-qwen3
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/LLAMA_SWAP_API_KEY
```

## Operating

- Loaded models: `docker exec <name> ollama ps` or `curl -s http://127.0.0.1:11434/api/ps | jq .`
- Unload now: `ollama stop <model>` or a generate with `"keep_alive": 0`.
- Pull/delete: `ollama pull <model>`, `ollama rm <model>`; pulls are large, run them in a capped scope.
- Logs: `docker logs -f <name>` or `journalctl -u ollama -f` for the native service.
- Update: pull the new image tag, restart, check `/api/version`, smoke test each Ollama-backed model.

## Tuning knobs worth knowing

All from Ollama's `envconfig`:

- `OLLAMA_HOST` (default `127.0.0.1:11434`), `OLLAMA_MODELS` (store path), `OLLAMA_ORIGINS` (CORS).
- `OLLAMA_KEEP_ALIVE` (default `5m`; negative = forever, `0` = unload after each response). Request
  `keep_alive` overrides it on `/api/*` calls.
- `OLLAMA_MAX_LOADED_MODELS` (per GPU), `OLLAMA_NUM_PARALLEL` (memory scales with parallel x context),
  `OLLAMA_MAX_QUEUE` (503 when exceeded), `OLLAMA_LOAD_TIMEOUT` (default `5m` of stalled loading).
- `OLLAMA_CONTEXT_LENGTH`: default context unless requested (default depends on detected VRAM: 4k/32k/256k).
  Set it explicitly; on GB10 the VRAM heuristic sees shared memory.
- `OLLAMA_FLASH_ATTENTION`, `OLLAMA_KV_CACHE_TYPE` (default f16; quantized types change numerics).
- `OLLAMA_GPU_OVERHEAD` reserves bytes per GPU; `OLLAMA_NO_CLOUD` disables cloud inference and web search.

## Known pitfalls

- A persistent Ollama with default settings keeps up to three models loaded for five minutes each; on a
  shared Spark that silently eats the memory llama-swap planned for an exclusive model.
- When memory is short, Ollama queues requests instead of failing; behind a 125 s proxy timeout that looks
  like a hang. Size it so loads fit.
- OpenAI-compatible requests use the model name Ollama knows (`qwen3:8b`); use `useModelName` in llama-swap
  or the exact name in LiteLLM.
- The OpenAI API has no way to set context size; use `OLLAMA_CONTEXT_LENGTH` or a Modelfile with
  `PARAMETER num_ctx <n>` (`ollama create`). Ollama suggests at least 64000 tokens for agents and coding tools.
- LoRA adapters are rejected (`ADAPTER` in a Modelfile fails with "LoRA adapters are no longer
  supported"). Serve adapters with vLLM or llama-server, or merge and import the merged GGUF.

## Official links

- Repo and releases: https://github.com/ollama/ollama
- Docs (FAQ, Linux, Docker, OpenAI and Anthropic compatibility): https://docs.ollama.com/
- Environment variables (source of truth): https://github.com/ollama/ollama/blob/main/envconfig/config.go
- DGX Spark playbook: https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/ollama
