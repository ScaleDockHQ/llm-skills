# Integrations

> Verified against mistral.rs v0.9.4 (docs `guides/serve/coding-agents`, `guides/serve/openai-compatible-apis`, `guides/serve/with-web-ui`, `guides/agents/expose-as-mcp`), 2026-10-11

Anything that speaks OpenAI Chat Completions, OpenAI Responses or Anthropic Messages can use mistral.rs. Use a placeholder key
(`not-used`) unless a proxy in front enforces one. Only the Codex and Claude Code settings below come from upstream docs; the
LiteLLM and Open WebUI snippets use their documented generic OpenAI-compatible provider settings and were not run against a live server.

## OpenAI SDK

```python
from openai import OpenAI
client = OpenAI(base_url="http://127.0.0.1:1234/v1", api_key="not-used")
print(client.chat.completions.create(model="default", messages=[{"role": "user", "content": "hi"}]).choices[0].message.content)
```

## Built-in web UI

`http://127.0.0.1:1234/ui` (disable with `--no-ui`). It is part of the unauthenticated surface: do not expose it without a proxy.

## LiteLLM

```yaml
model_list:
  - model_name: local-qwen
    litellm_params:
      model: openai/default
      api_base: http://mistralrs:1234/v1
      api_key: not-used
```

For the full gateway setup (keys, budgets, fallbacks) use the `litellm` skill: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
mistral.rs reports per-model readiness in `/v1/models` `status`, which a gateway health check can use.

## Open WebUI

Add an OpenAI-compatible connection with base URL `http://<host>:1234/v1` and any non-empty key. With several models, use the ids
from `/v1/models`.

## llama-swap

mistral.rs already hosts several models in one process via `from-config`; use llama-swap only to swap whole processes (for example a
CUDA model and another engine). Command template: `mistralrs serve --host 127.0.0.1 --port ${PORT} -m ...`, health-check path `/health`
(liveness only, so also probe `/v1/models`). Skill: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.

## Codex (Responses API)

In the user-level `~/.codex/config.toml` (provider tables are ignored in project-local files):

```toml
model = "default"
model_provider = "mistralrs"
model_context_window = 32768
model_reasoning_summary = "none"
model_supports_reasoning_summaries = false

[model_providers.mistralrs]
name = "mistral.rs"
base_url = "http://127.0.0.1:1234/v1"
wire_api = "responses"
request_max_retries = 1
stream_max_retries = 0
stream_idle_timeout_ms = 300000
# env_key = "MISTRALRS_API_KEY"   # only when a reverse proxy enforces authentication
```

## Claude Code (Anthropic Messages API)

Base URL without `/v1`. Map every Claude role to the single local model and set the real context window:

```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:1234
export ANTHROPIC_API_KEY=not-used
export ANTHROPIC_MODEL=sonnet
export ANTHROPIC_DEFAULT_SONNET_MODEL=default ANTHROPIC_DEFAULT_OPUS_MODEL=default ANTHROPIC_DEFAULT_HAIKU_MODEL=default
export CLAUDE_CODE_MAX_CONTEXT_TOKENS=32768 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```

Use a tool-capable model (upstream's example is `Qwen/Qwen3-Coder-Next`). The coding clients bring their own file and shell tools;
leave mistral.rs `--agent` off unless you need server-side execution.

## MCP

- As a client: `--mcp-config <json>` (or `MCP_CONFIG_PATH`) attaches outbound MCP servers whose tools the model can call; each
  server you add is code you trust. `/v1/models` shows `mcp_tools_count` and `mcp_servers_connected`.
- As a server: `--mcp-port <port>` exposes the loaded model over JSON-RPC at `POST /mcp`. No auth; private network only.

## Kubernetes

`templates/k8s-deployment.yaml`: one Deployment per model, a PVC at `/data`, startup probe on `/v1/models` with a generous window,
liveness on `/health`, `ClusterIP` Service only. Use the NVIDIA device plugin (`nvidia.com/gpu`). Put auth in an ingress or gateway.
Multi-node NCCL on Kubernetes (`MISTRALRS_MN_*`) has no upstream recipe; plan it as a StatefulSet with headless Service and test
`NCCL_SOCKET_IFNAME`.

## Rust and Python embedding

`pip install mistralrs` gives `Runner`; the Rust crate offers `ModelBuilder`. Embedding apps own authentication, CORS and the sandbox
(SDK defaults are no sandbox). See `guides/python` and `guides/rust` upstream.
