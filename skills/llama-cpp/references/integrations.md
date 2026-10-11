# llama.cpp: integrations

> Verified against llama.cpp b11556 (master; tools/server/README.md) and v0.6.0, llama-swap v263 (docker/unified README), 2026-10-11

## OpenAI and Anthropic clients

Any OpenAI SDK or tool works with `base_url=http://HOST:PORT/v1` and any non-empty API key when no key is configured (or the real key from an environment variable). Anthropic-style clients can use `/v1/messages` with `x-api-key`. Set the model name to the `-a/--alias` value. The server applies the model's chat template, so clients should send plain messages, not pre-templated prompts.

```bash
export OPENAI_BASE_URL=http://127.0.0.1:9931/v1
export OPENAI_API_KEY="$(cat ~/.config/llama-server/key)"   # file mode 0600
```

Editors and apps (Continue, Cline, Open WebUI, and others) use the same OpenAI-compatible settings; see the `llm-clients` skill. Code completion (FIM) uses `/infill`; the `--fim-qwen-*-default` flags are upstream shortcuts that start a preset FIM model (they download weights).

## Built-in Web UI

Served at `/` (disable with `--no-ui`; defaults via `--ui-config-file`). It is open to anyone who can reach the port unless `--api-key-file` is set. In v0.6.0 the UI gained a Hugging Face Hub model download pipeline (router mode). Keep it on loopback or behind an authenticating proxy.

## llama-swap

llama-swap (`mostlygeek/llama-swap`) starts and stops `llama-server` processes (or containers) per requested model name and proxies OpenAI/Anthropic requests. Config per model: `cmd`, `proxy`, `checkEndpoint: /health`, `ttl`, `cmdStop`, groups for co-resident models. Details and the combined setup are in `references/combos/llama-swap-router.md`; the `llama-swap` skill (planned) covers the proxy itself: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.

## LiteLLM and other gateways

Point a gateway at `llama-server` (or llama-swap) as an `openai/` provider:

```yaml
model_list:
  - model_name: local-model
    litellm_params:
      model: openai/local-model
      api_base: http://127.0.0.1:9931/v1
      api_key: os.environ/LLAMA_SERVER_API_KEY
```

The gateway holds client keys; llama-server stays on loopback with its own key (or none). See the `llm-gateway` and `litellm` skills. Gateways should forward `tools`, `response_format` and `chat_template_kwargs` unchanged; if tool calls degrade through a gateway, test the same request directly against llama-server first.

## Remote access

Expose through a private network or authenticated tunnel, not a raw port: the `tailscale` or `cloudflare-tunnel` skills, or a reverse proxy such as `caddy` (use `--api-prefix` when serving under a sub-path and raise proxy timeouts for streaming; the server's own `--timeout` default is 3600 s, SSE ping every 30 s via `--sse-ping-interval`).

## Containers and Kubernetes

- Docker/Compose: `templates/docker-compose.yml` (env-driven config with `LLAMA_ARG_*`).
- Kubernetes: `templates/k8s.yaml` is a Deployment, Service and PVC for a GPU node. Needs the NVIDIA device plugin (or the AMD equivalent) and a model volume. Probe `/health` for readiness (it returns 503 while loading, so use a generous `startupProbe`), not `/v1/models`. One replica per model; scale out with several Deployments behind a gateway, because llama.cpp slots do not share KV across pods.
- The llama-swap unified image also contains `kubeswap`, a wrapper that creates a Deployment + Service per model in a namespace (needs a Kubernetes client and namespaced RBAC); see the llama-swap `docker/unified` README.

## Other runtimes built on llama.cpp

Ollama, LM Studio, Jan and similar apps embed llama.cpp; their GGUF files and many flags carry over, but versions lag. Choose them for convenience (`ollama`, `lm-studio` skills) and use this skill when you need exact flag control, a specific backend, or the newest model support.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://github.com/mostlygeek/llama-swap/tree/main/docker/unified
