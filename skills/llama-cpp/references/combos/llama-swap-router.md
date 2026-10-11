# llama.cpp with llama-swap, and llama.cpp router mode

> Verified against llama.cpp b11556 (router mode, tools/server/README.md) and v0.6.0, llama-swap v263 (docs/config.example.yaml, docker/unified README), 2026-10-11

Two ways to serve several GGUF models from one endpoint, loading on demand:

| Aspect          | llama-server router mode                                          | llama-swap in front of llama-server                                |
| --------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------ |
| Setup           | `llama-server --models-dir DIR` or `--models-preset FILE.ini`     | `llama-swap --config config.yaml`, one `cmd` per model             |
| Engines         | llama.cpp only                                                    | Any OpenAI-compatible server (llama.cpp, vLLM, SGLang, containers) |
| Concurrency     | `--models-max N` models loaded at once (default 4)                | Groups with `swap`, `exclusive`, `persistent` rules                |
| Unload          | `POST /models/unload`, `--sleep-idle-seconds`, LRU via models-max | `ttl` per model, `cmdStop` for containers                          |
| Per-model flags | Preset INI sections                                               | Full command line per model                                        |

**Never combine them for the same models**: llama-swap would start a router that itself swaps, giving double loading and port clashes. If llama-swap fronts llama.cpp, each `cmd` starts a plain single-model `llama-server` (`-m` or `-hf`), never a router.

## Choose

- Only llama.cpp, a laptop or single box, want built-in downloads and Web UI model picker: router mode.
- Mixed engines, containers, custom stop logic, co-resident groups, per-model TTLs, one gateway endpoint for a team: llama-swap (`llama-swap` skill, planned).

## Router mode quick start

```bash
llama-server --models-dir /srv/models/gguf --models-max 2 --host 127.0.0.1 --port 9931 \
  -c 8192 -np 2 -fa on --api-key-file ~/.config/llama-server/keys
# or with presets (templates/models.ini)
llama-server --models-preset ~/.config/llama-server/models.ini --host 127.0.0.1 --port 9931
curl -s http://127.0.0.1:9931/models | jq '.data[] | {id, status: .status.value}'
curl -s http://127.0.0.1:9931/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"my-model","messages":[{"role":"user","content":"hi"}]}'
```

Details (sources, presets, precedence, API) are in `references/serve-config.md`. `GET /props` and `/metrics` need `?model=<id>` in router mode.

## llama-swap with llama-server

`config.yaml` (keys per llama-swap's example config; `${PORT}` is allocated by llama-swap):

```yaml
healthCheckTimeout: 500
store:
  path: /var/lib/llama-swap/state.sqlite # keeps discovered capabilities and activity across restarts

models:
  small-gguf:
    cmd: llama-server --port ${PORT} -m /models/Qwen3-8B-Q4_K_M.gguf -a ${MODEL_ID} -c 32768 -ngl all -fa on
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    disableKeepAlives: true # avoids 502 "proxy error: EOF" right after a stream
    ttl: 900 # unload after 15 minutes idle
```

Container variant (the engine in Docker, llama-swap on the host):

```yaml
models:
  small-gguf:
    cmd: >
      docker run --rm --name ${MODEL_ID} --gpus all -p 127.0.0.1:${PORT}:8080
      -v /srv/models/gguf:/models:ro ghcr.io/ggml-org/llama.cpp:server-cuda13
      -m /models/Qwen3-8B-Q4_K_M.gguf -a ${MODEL_ID} -c 32768 -ngl all -fa on --host 0.0.0.0 --port 8080
    cmdStop: docker stop ${MODEL_ID}
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    disableKeepAlives: true
```

Co-resident small models (embedding, rerank, a small chat model) next to one big swapping model, using router groups (schema from the example config; confirm against your llama-swap version):

```yaml
router:
  use: group
  settings:
    groups:
      big:
        swap: true # one member at a time
        exclusive: true # loading one unloads other groups
        members: [big-model-a, big-model-b]
      small:
        swap: false # all members stay loaded together
        exclusive: false # do not unload other groups
        members: [small-gguf, embed, rerank]
```

Notes:

- **Port:** always `--port ${PORT}`. llama-server's own default is 9931 on master (8080 on v0.6.0 and older, which collides with llama-swap's usual port).
- **Health:** `/health` is 503 until loaded and 200 after; exempt from the idle-sleep timer. Let llama-swap own unloading (`ttl`); do not also set `--sleep-idle-seconds`.
- **Capabilities:** llama-swap fills `capabilities` (image/audio input, tools, reranker) from llama-server `/props` when the model first becomes ready (works with llama-server and vLLM). Set `store.path` so discovered values persist. Values set in the config win per field. `capabilities.tools` only advertises; tool calls still need `--jinja` and a tool-capable template.
- **Unified image:** `ghcr.io/mostlygeek/llama-swap:unified-cuda13` (amd64 + arm64; Ampere through Blackwell including GB10), `:unified-cuda` (amd64, CUDA 12, Pascal to Ada) and `:unified-vulkan` (amd64, AMD/other Vulkan) bundle `llama-server`, `sd-server`, whisper.cpp and other backends, built from source; inside them `cmd: llama-server --port ${PORT} -m ...` works without a wrapper. Pin by digest. See the llama-swap `docker/unified` README.
- **Auth:** keep llama-server keyless on loopback and put keys on llama-swap or the gateway (`llm-gateway`, `litellm`), or use `--api-key-file` on both if exposure is possible.
- **Logs and slots:** `/logs/stream/<model>` for logs; `/upstream/<model>/slots` and `/upstream/<model>/props` reach the child server directly.
- **Update:** pull the new llama.cpp image or binary, then restart llama-swap or let TTLs unload each model; smoke test tools and reasoning (`references/updating.md`).
- **DGX Spark:** shared 128 GB unified memory means co-resident groups must fit together with the big model's KV cache; keep the big model exclusive and small utility models in a non-exclusive group. See `nvidia-dgx-spark` (planned).

## Pitfalls

- 502 `proxy error: EOF` after a stream: `disableKeepAlives: true` on the model.
- Requests time out: missing `--port ${PORT}` (direct `cmd`) or wrong `-p` mapping (container).
- Models answer tool calls in prose: old build or template without tools, see `references/troubleshooting.md`.
- Router child ignores a preset key: spelling (no leading dashes) or key controlled by the router (host, port, API key, HF repo, alias).

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml
- https://github.com/mostlygeek/llama-swap/tree/main/docker/unified
