# llama-swap

> Verified against llama-swap v263, 2026-10-11

This page keeps only what is specific to this stack: the wrapper script, the llama-swap and LiteLLM entries, and the stack pitfalls. Install, flags, tuning and operating detail live in the product skill.

Depth: install the llama-swap skill (`npx skills add ScaleDockHQ/llms-skills --skill llama-swap`).

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
