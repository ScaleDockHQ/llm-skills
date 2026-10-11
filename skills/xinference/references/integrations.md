# Xinference integrations

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

## Clients

- **OpenAI SDK or HTTP:** `base_url=http://HOST:9997/v1`, `api_key` = an Xinference API key (any non-empty string
  when auth is off), `model` = model UID.
- **Anthropic SDK and Claude Code:** `base_url=http://HOST:9997/anthropic`.
- **Codex CLI:** provider with `wire_api = "responses"` (`features.md`).
- **Xinference client:** `pip install xinference-client==<server version>`; `Client(endpoint, api_key=...)`.
- Listed by upstream as built-in integrations: LangChain, LlamaIndex, Dify, FastGPT, RAGFlow, MaxKB and
  Xagent. Use each tool's Xinference provider with the endpoint and key.

## LiteLLM

```yaml
model_list:
  - model_name: xinf-qwen
    litellm_params:
      model: openai/qwen2.5-instruct # the Xinference model UID
      api_base: http://127.0.0.1:9997/v1
      api_key: os.environ/XINFERENCE_API_KEY
```

Xinference implements `/v1/responses`, so LiteLLM's Responses pass-through for custom `openai/` bases works;
still test a streamed request and a tool call. See the `litellm` skill for keys, budgets and fallbacks.

## llama-swap or another router in front

Xinference already keeps many models loaded and launches them via API, so a router mostly adds auth,
aliases and spend control. If used, point routes at `http://127.0.0.1:9997`, probe `/status`, and keep the
Xinference API key in the router's environment. Models are launched separately (`xinference launch`), not by
the router.

## Reverse proxy and exposure

The server speaks plain HTTP and has built-in auth. For TLS and rate limits front it with Caddy, Traefik or a
tunnel (`caddy`, `traefik`, `cloudflare-tunnel`, `tailscale` skills); disable response buffering for
streaming, keep `/v1/admin/setup` unreachable until the admin exists, and restrict with
`XINFERENCE_ALLOWED_IPS`. The Web UI is served on the same port.

## Kubernetes

Official Helm chart (`install.md`). Probe `GET /status`. Persist `XINFERENCE_HOME` on a PVC (models, auth DB,
virtualenvs); set the same `XINFERENCE_AUTH_*` secrets for every replica of the API; GPUs via the device plugin;
raise shared memory for vLLM.

## Monitoring stacks

Prometheus scrapes `/metrics` on the supervisor and each worker exporter (`observability.md`); `/v1/cluster/monitor_config` stores Grafana settings.
