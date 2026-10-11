# llama-swap

> Verified against llama-swap v263, 2026-10-11

## What it is and when to choose it

[llama-swap](https://github.com/mostlygeek/llama-swap) (by mostlygeek) is a single Go binary that
exposes one OpenAI-compatible URL and starts the right upstream server for the requested `model`,
stopping others as needed. It works with any server that speaks HTTP: llama.cpp, vLLM, SGLang,
TensorRT-LLM, Ollama, sd-server, or a wrapper script.

Choose it when you serve more models than fit at once, want idle models unloaded, or want to swap
engines without touching clients. Skip it if every model fits and stays loaded.

## Install (DGX Spark/arm64 and generic x86)

Host binary (recommended here: it launches containers through the wrapper, so it needs no GPU itself):

```bash
V=263; ARCH=arm64          # amd64 on x86
curl -fsSLO "https://github.com/mostlygeek/llama-swap/releases/download/v$V/llama-swap_${V}_linux_${ARCH}.tar.gz"
curl -fsSLO "https://github.com/mostlygeek/llama-swap/releases/download/v$V/llama-swap_${V}_checksums.txt"
grep "linux_${ARCH}.tar.gz" "llama-swap_${V}_checksums.txt" | sha256sum -c -
tar xzf "llama-swap_${V}_linux_${ARCH}.tar.gz" llama-swap && sudo install -m 755 llama-swap /usr/local/bin/
```

Container alternative: `ghcr.io/mostlygeek/llama-swap:unified-cuda13` (amd64 and arm64, bundles
llama.cpp and other servers). Configure with `LLAMA_SWAP_CONFIG` / `LLAMA_SWAP_LISTEN` or the
`-config` / `-listen` flags.

## Minimal working config

`assets/llama-swap.yaml` holds the full example (two exclusive large models, two co-resident
side models, aliases, preload). The smallest useful entry:

```yaml
healthCheckTimeout: 900
models:
  "qwen-coder":
    cmd: /opt/llm-stack/start-model.sh run ${MODEL_ID} ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop ${MODEL_ID}
    checkEndpoint: /health
```

Run: `llama-swap -config /etc/llm-stack/llama-swap.yaml -listen 127.0.0.1:8080` (the systemd unit in
`assets/systemd/llama-swap.service`). `-watch-config` reloads on file change.

## How it plugs into the stack

- Listens on `127.0.0.1:8080`; LiteLLM calls `http://127.0.0.1:8080/v1` with model IDs from this file.
- Assigns `${PORT}` from `startPort` (default 5800) to each model; `proxy` defaults to
  `http://localhost:${PORT}`.
- Health: `GET /health` returns `OK`. What is loaded: `GET /running`.
- No keys here: only LiteLLM on loopback talks to it. (`apiKeys` exists if you expose it directly.)
- Routes OpenAI chat/completions/embeddings, `/v1/messages`, `/v1/responses`,
  `/v1/images/generations`, `/v1/models`, plus `/upstream/<id>/...` for direct access to a model's
  own API and web UI.

## Operating

```bash
curl -s 127.0.0.1:8080/running | jq .                       # loaded models and state
curl -s 127.0.0.1:8080/upstream/qwen-coder/health           # direct access to the engine API
curl -s -X POST 127.0.0.1:8080/api/models/unload            # unload everything
curl -s -X POST 127.0.0.1:8080/api/models/unload/qwen-coder # unload one model
curl -sN 127.0.0.1:8080/logs/stream/upstream                # follow engine output (also /proxy, /<model-id>)
journalctl -u llama-swap -f
sudo systemctl restart llama-swap                           # stops all models (cmdStop), reloads config
```

Preload a model to avoid the first cold start: one request to it, or `hooks.on_startup.preload`.
The web UI at `http://127.0.0.1:8080/ui` shows models, logs and activity (reach it through an SSH
tunnel, not the public hostname).

## Tuning knobs worth knowing

| Key                                 | Where          | Use                                                                                                                             |
| ----------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `healthCheckTimeout`                | global         | seconds to wait for `checkEndpoint`; large models need many minutes                                                             |
| `ttl` / `globalTTL`                 | model / global | idle seconds before unload; 0 = never                                                                                           |
| `unloadTimeout`                     | global / model | graceful stop budget before force-kill (default 10); `docker stop` needs more                                                   |
| `sendLoadingState`                  | global / model | streams loading messages in the reasoning field during a cold start                                                             |
| `routing.router.settings.groups`    | global         | `swap` (one member at a time), `exclusive` (unloads other groups), `persistent` (cannot be unloaded by other groups), `members` |
| `hooks.on_startup.preload`          | global         | models to load at startup; preload several only if they share a non-swapping group                                              |
| `filters.setParamsByID`             | model          | per-alias parameter overrides; each key becomes an alias                                                                        |
| `filters.stripParams` / `setParams` | model          | remove or force request fields                                                                                                  |
| `useModelName`                      | model          | name sent upstream when it differs from the ID                                                                                  |
| `capabilities`                      | model          | `in`, `out`, `tools`, `context` shown in `/v1/models`                                                                           |
| `disableKeepAlives`                 | model          | new upstream connection per request                                                                                             |
| `timeouts.*`                        | model          | `connect`, `keepalive`, `responseHeader`, `tlsHandshake`, `idleConn`                                                            |
| `macros`, `${env.VAR}`              | global         | reuse paths; environment values (loading fails if unset)                                                                        |

### Groups in practice

- `large`: `swap: true` so only one big model runs; `exclusive: false` so the side group stays
  loaded. Set `exclusive: true` if no side model fits next to a large one.
- `side`: `swap: false`, `exclusive: false` for small models that fit together.
- Without groups llama-swap runs one model at a time. Put every model in an
  explicit group so behaviour is predictable (a model belongs to at most one group).

### Aliases for parameter variants

```yaml
filters:
  setParamsByID:
    "${MODEL_ID}-high":
      reasoning_effort: high
```

A request for `gpt-oss-high` runs the `gpt-oss` process with `reasoning_effort` forced to `high`,
with no second copy of the model in memory. See `reasoning-effort.md`.

## Known pitfalls

- `healthCheckTimeout` shorter than the real load time: llama-swap kills a model that was about to
  become ready, and every request fails.
- 502 `proxy error: EOF` after streaming from llama-server: set `disableKeepAlives: true`.
- The default `unloadTimeout` (10 s) is shorter than a graceful `docker stop`: containers get
  force-killed, multi-node workers may be left running. The wrapper stops both nodes itself.
- Preloading several models that are in the same swapping group: they load and immediately swap
  each other out.
- Containers started outside llama-swap (manual tests) hold memory llama-swap does not know about:
  `docker ps --filter label=llm-stack.role=engine` before blaming it.
- `${env.VAR}` in the config with the variable missing from the unit's environment: the config fails
  to load and the service restarts in a loop.

## Official links

- [llama-swap repository](https://github.com/mostlygeek/llama-swap)
- [Full configuration example](https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml)
- [Releases](https://github.com/mostlygeek/llama-swap/releases)
