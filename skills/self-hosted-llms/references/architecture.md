# Architecture

> Verified against llama-swap v263, LiteLLM v1.105.0, Caddy v2.11.7, cloudflared 2026.10.0, 2026-10-11

## Reference stack

```text
client (IDE, CLI, chat UI, SDK)
  |  HTTPS, Authorization: Bearer <your-key>
  v
Cloudflare Tunnel (llm.example.com)        or   Tailscale Serve (node-a.<tailnet>.ts.net)
  |  path ^/(v1/)?models/?$ -> 127.0.0.1:8088      everything -> 127.0.0.1:8088
  |  everything else        -> 127.0.0.1:4000
  v
Caddy catalog front 127.0.0.1:8088   -- forward_auth --> LiteLLM /v1/models (key check)
  |  /v1/models: static models.json        other paths: reverse_proxy -> 127.0.0.1:4000
  v
LiteLLM gateway 127.0.0.1:4000   keys, aliases, API bridging (/v1/messages, /v1/responses)
  |  openai/<model-id>, api_base http://127.0.0.1:8080/v1
  v
llama-swap 127.0.0.1:8080        starts/stops one upstream per model ID, groups, TTLs
  |  cmd: /opt/llm-stack/start-model.sh run <id> ${PORT}     (PORT from 5800 up)
  v
engine container on node-a 127.0.0.1:${PORT}   (+ worker container on node-b over ConnectX-7)
```

Every listener binds to loopback. The only ways in are the tunnel (outbound connection, no open
port) or the tailnet. Engines never see client keys; LiteLLM is the single authentication point.

## Port map

| Component           | Listen          | Health / status                                             |
| ------------------- | --------------- | ----------------------------------------------------------- |
| Caddy catalog front | 127.0.0.1:8088  | `GET /v1/models` with a valid key                           |
| LiteLLM             | 127.0.0.1:4000  | `GET /health/liveliness`, `GET /health/readiness` (no auth) |
| llama-swap          | 127.0.0.1:8080  | `GET /health`, `GET /running`                               |
| Engines             | 127.0.0.1:5800+ | engine-specific, usually `GET /health`                      |
| sparkDash           | 127.0.0.1:5555  | see `monitoring-sparkdash.md`                               |
| cloudflared         | outbound only   | `cloudflared tunnel info <name>`                            |

## What each layer is for

- **Engine** (vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, ExLlamaV3, TensorFold, sd-server):
  loads weights, serves an OpenAI-compatible API for one model.
- **llama-swap**: one URL for many engines. It starts the right engine for the requested `model`,
  stops others according to groups, unloads idle models (ttl), and streams loading progress.
- **LiteLLM**: client-facing names and aliases, API keys (master + virtual keys), Anthropic Messages
  and Responses API bridging to chat completions, parameter dropping and mapping, `model_info`.
- **Caddy catalog front**: replaces LiteLLM's thin `/v1/models` with an enriched static list
  (context length, capabilities, real dates) that clients use to configure themselves, without
  opening a second auth system. See `model-catalog.md`.
- **Exposure**: Cloudflare Tunnel for a public hostname, Tailscale Serve for tailnet-only.

## Layering options

| Need                                                        | Layers                                             |
| ----------------------------------------------------------- | -------------------------------------------------- |
| One model, local scripts only                               | engine on loopback                                 |
| Several models, one trusted client on the tailnet           | llama-swap (+ its `apiKeys`) + Tailscale           |
| Public endpoint, one always-on model                        | engine + LiteLLM + tunnel                          |
| Public endpoint, many models, swapping                      | engine + llama-swap + LiteLLM (+ catalog) + tunnel |
| Rich gateway features (budgets, fallbacks, cloud providers) | as above; depth in `llm-gateway`                   |

Drop the catalog front if your clients ignore `/v1/models` metadata. Drop llama-swap if every model
fits and stays loaded; point LiteLLM straight at the engines.

## Single node versus dual node

- **Single node**: all of the above on node-a.
- **Dual node (2x DGX Spark)**: everything runs on node-a; node-b only runs worker containers that
  the wrapper starts through SSH before the head starts (`assets/start-model.sh`,
  `assets/models.d/example-vllm.sh`). Engine traffic between nodes uses the ConnectX-7 link
  (10.0.0.1 / 10.0.0.2). Images, weights, configs and the service user must match on both nodes.

## Why loopback plus wrapper scripts

- Wrapper scripts give llama-swap one command per model regardless of engine, start workers on
  other nodes, wait on container state instead of process names, and always clean up both nodes.
- Loopback binding means a misconfigured engine flag cannot expose an unauthenticated API.

## Request lifecycle on a cold model

1. Client calls `POST /v1/chat/completions` with `model: coder`.
2. LiteLLM resolves the alias (`model_group_alias`) to `qwen-coder`, calls llama-swap.
3. llama-swap sees `qwen-coder` is not running: stops the other member of its swap group, runs the
   `cmd`, polls `checkEndpoint` until healthy or `healthCheckTimeout`.
4. With `sendLoadingState: true`, streaming clients receive loading progress while they wait.
5. The request is proxied; the response streams back through every layer.

Cold starts of large models take minutes. Anything on the path with a read timeout (Cloudflare,
clients) must tolerate it or be kept busy: see `exposure-cloudflare.md` and `llama-swap.md`.

## Official links

- [llama-swap](https://github.com/mostlygeek/llama-swap)
- [LiteLLM proxy](https://docs.litellm.ai/docs/simple_proxy)
- [Caddy forward_auth](https://caddyserver.com/docs/caddyfile/directives/forward_auth)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)
- [Tailscale Serve](https://tailscale.com/kb/1312/serve)
