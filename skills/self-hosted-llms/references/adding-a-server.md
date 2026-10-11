# Adding a server

> Verified against llama-swap v263, llama.cpp v0.6.0, SGLang v0.5.21, Ollama v0.40.3, stable-diffusion.cpp master-956-1b0ba10, 2026-10-11

How to put any inference server (a new engine, a second instance, an image server) behind
llama-swap and LiteLLM without breaking the rest of the stack.

## The backend contract

A backend is ready for the stack when all of these hold:

1. **Loopback only.** It listens on `127.0.0.1:${PORT}` (the port llama-swap assigns), or a container
   publishes only `-p 127.0.0.1:${PORT}:<inner-port>`. Never `0.0.0.0` on the host network.
2. **OpenAI-compatible routes** for what it serves: `/v1/chat/completions` (streaming SSE, `usage`
   on the final chunk when `stream_options.include_usage` is set), `/v1/completions` if needed,
   `/v1/images/generations` for image servers, `/v1/models`.
3. **Truthful readiness.** A health path that returns 200 only once the model is loaded
   (`checkEndpoint`), or `checkEndpoint: none` plus a wrapper that waits itself.
4. **Accepts the llama-swap model ID** as `model` (`--served-model-name`, `--alias`), or the
   llama-swap entry sets `useModelName` to the name the server expects.
5. **Foreground lifecycle.** The `cmd` stays in the foreground while the model serves and exits when
   it stops; `cmdStop` (or SIGTERM) leaves no container, worker or child process behind on any node.
6. **Labelled and named.** Containers are named after the model ID (`<id>`, `<id>-worker`) and carry
   `--label llm-stack.role=engine`, so the wrapper and status checks can find them.
7. **Inside the memory plan**, with weights read offline (`HF_HUB_OFFLINE=1`) and caches mounted
   read-only where the engine allows it.
8. **Parsers set.** Tool-call and reasoning parsers configured, so tools and reasoning content
   come back in OpenAI fields rather than as raw text.

## Steps

1. Run the server by hand on a spare port and check health and one chat request on loopback.
2. Write `models.d/<id>.sh` (container engines) or a plain `cmd` (host binaries).
3. Add the llama-swap entry: group, `ttl`, `checkEndpoint`, `capabilities`, filters.
4. Reload llama-swap (`sudo systemctl restart llama-swap`, or run it with `-watch-config`) and test
   through it: `curl -s 127.0.0.1:8080/upstream/<id>/health`, then a chat request to
   `127.0.0.1:8080/v1/chat/completions` with `"model":"<id>"`.
5. Add the LiteLLM entry with `model_info` (`litellm.md`), catalog metadata (`model-catalog.md`),
   reasoning mapping if any (`reasoning-effort.md`).
6. Run `smoke-test.md` and record a baseline (`benchmarking.md`).

## Worked example: llama.cpp (co-resident GGUF)

`models.d/small-gguf.sh`:

```bash
MODEL_IMAGE="${SMALL_GGUF_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-cuda13}"
MODEL_EXCLUSIVE=0                                   # stays loaded next to a large model
MODELS_DIR="${LLM_MODELS_DIR:-/srv/models}"

model_run() {
  docker run -d --name "$MODEL_ID" --label "$LLM_ENGINE_LABEL" --gpus all --init \
    -p "127.0.0.1:$PORT:8080" -v "$MODELS_DIR:/models:ro" \
    "$MODEL_IMAGE" \
    --host 0.0.0.0 --port 8080 \
    -m /models/<file>.gguf --alias "$MODEL_ID" \
    --ctx-size 16384 -ngl 999 --parallel 2 --jinja
}
```

`--host 0.0.0.0` is inside the container only; the publish rule keeps it on host loopback. llama-swap
entry: `cmd`/`cmdStop` through the wrapper, `checkEndpoint: /health`, `disableKeepAlives: true`
(llama-server can close keep-alive connections after a stream, which shows as 502
`proxy error: EOF`), and put it in the non-exclusive `side` group.

## Worked example: SGLang (exclusive safetensors model)

`models.d/<id>.sh`:

```bash
MODEL_IMAGE="${SGLANG_IMAGE:-lmsysorg/sglang:spark}"
HF_DIR="${LLM_HF_DIR:-$HOME/.cache/huggingface}"
REPO="<org>/<model>"; REVISION="<commit-sha>"

model_run() {
  docker run -d --name "$MODEL_ID" --label "$LLM_ENGINE_LABEL" --gpus all --ipc host \
    --network host -v "$HF_DIR:/hf" -e HF_HOME=/hf -e HF_HUB_OFFLINE=1 \
    --entrypoint python3 "$MODEL_IMAGE" -m sglang.launch_server \
    --model-path "$REPO" --revision "$REVISION" \
    --host 127.0.0.1 --port "$PORT" --served-model-name "$MODEL_ID" \
    --context-length 65536 --mem-fraction-static 0.75
}
```

`--revision` selects the pinned commit from the cache (download it first; the container is offline).
Health: `checkEndpoint: /health`.
Multi-node uses `--nnodes`, `--node-rank`, `--dist-init-addr` and `--tp-size` (see
`engine-sglang.md`); add a `worker_run` like the vLLM example.

## Worked example: Ollama as a backend

Ollama manages its own models; llama-swap only starts and stops the server.

```bash
MODEL_IMAGE="${OLLAMA_IMAGE:-ollama/ollama:latest}"
MODEL_EXCLUSIVE=0

model_run() {
  docker run -d --name "$MODEL_ID" --label "$LLM_ENGINE_LABEL" --gpus all \
    -p "127.0.0.1:$PORT:11434" -v ollama:/root/.ollama \
    -e OLLAMA_KEEP_ALIVE=-1 -e OLLAMA_MAX_LOADED_MODELS=1 \
    "$MODEL_IMAGE"
}
```

llama-swap entry: `checkEndpoint: /api/version`, and `useModelName: "<ollama-model>:<tag>"` so the
request names the model Ollama knows. Pull the model once with
`docker exec <id> ollama pull <ollama-model>:<tag>` while the container runs. The first request
loads the model, so a healthy `/api/version` does not mean warm: preload with one request.

## Worked example: sd-server (image generation, host binary)

No container and no wrapper: llama-swap runs the binary directly and kills it on unload.

```yaml
"image-sd":
  cmd: |
    /usr/local/bin/sd-server --listen-ip 127.0.0.1 --listen-port ${PORT}
    --diffusion-model ${models_dir}/<diffusion>.safetensors
    --vae ${models_dir}/<vae>.safetensors
    --llm ${models_dir}/<text-encoder>.safetensors
  checkEndpoint: /v1/models
  ttl: 600
  capabilities:
    in: [text]
    out: [image]
```

sd-server has no dedicated health route, but it creates the model context before it starts
listening, so `/v1/models` answering means the weights are loaded. In LiteLLM use
`model_info.mode: image_generation`. Image jobs often outlast proxy timeouts; see
`exposure-cloudflare.md`. ComfyUI and other image servers: `engine-sdcpp.md`.

## Known pitfalls

- A server that daemonizes itself: llama-swap thinks it exited and marks the model failed.
- An engine bound to `0.0.0.0` on `--network host`: unauthenticated API on every interface.
- Health returning 200 before weights are loaded: the first requests fail with 503 or connection
  resets.
- A wrapper that waits with `pgrep -f <pattern>`: the pattern matches the waiting shell itself
  (its own command line contains it), so the loop never ends. Wait on container state instead
  (`templates/common.sh`).
- Different image IDs behind the same tag on node-a and node-b (`updating.md`).

## Official links

- [llama-swap configuration](https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml)
- [llama.cpp server](https://github.com/ggml-org/llama.cpp/tree/master/tools/server)
- [SGLang server arguments](https://docs.sglang.ai/advanced_features/server_arguments.html)
- [Ollama FAQ (environment)](https://docs.ollama.com/faq)
- [stable-diffusion.cpp server](https://github.com/leejet/stable-diffusion.cpp/tree/master/examples/server)
