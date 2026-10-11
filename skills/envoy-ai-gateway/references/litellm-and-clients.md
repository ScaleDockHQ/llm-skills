# Clients, LiteLLM and agents

> Verified against Agent Router (Envoy AI Gateway) v1.2.0 supported-endpoints docs, examples/goose and LiteLLM OpenAI-compatible docs, 2026-10-11

Base URLs (replace host and port; standalone `aigw` is `127.0.0.1:1975`, Kubernetes is the Gateway address or a port-forward):

| Client protocol            | Base URL                | Path used                                                               |
| -------------------------- | ----------------------- | ----------------------------------------------------------------------- |
| OpenAI SDK, curl           | `http://<gw>/v1`        | `/v1/chat/completions`, `/v1/embeddings`, `/v1/responses`, `/v1/models` |
| Anthropic SDK, Claude Code | `http://<gw>/anthropic` | `/anthropic/v1/messages` and `/count_tokens`                            |
| Cohere rerank              | `http://<gw>`           | `/cohere/v2/rerank`                                                     |
| MCP clients                | `http://<gw>/mcp`       | the `MCPRoute.path`                                                     |

The model name a client sends is what your `AIGatewayRoute` rules match on `x-ai-eg-model`. `GET /v1/models` lists the matched names. The API key a client sends is not checked by the gateway unless you add inbound auth; send any placeholder, or the real token when a `SecurityPolicy` expects one.

## curl and SDKs

```bash
curl -sS "$GATEWAY_URL/v1/chat/completions" -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-32b","messages":[{"role":"user","content":"Say hi"}],"stream":false}'
curl -sS "$GATEWAY_URL/v1/models" | jq -r '.data[].id'
```

```python
from openai import OpenAI
client = OpenAI(base_url="http://127.0.0.1:1975/v1", api_key="unused")   # no inbound auth by default
client.chat.completions.create(model="qwen3-32b", messages=[{"role": "user", "content": "hi"}])
```

Send a tenant header from clients behind your auth layer (`default_headers={"x-tenant-id": "team-a"}`) when limits or metrics key on it, and only if a trusted layer sets or validates it.

## Claude Code and Anthropic SDK

Route Anthropic-format traffic to an Anthropic, GCP Anthropic, AWS Anthropic or Bedrock backend (the endpoints page lists which schemas serve Messages):

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:1975/anthropic"
export ANTHROPIC_AUTH_TOKEN="unused"        # or the inbound token your SecurityPolicy expects
claude
```

The route must match the model name Claude Code sends, or the alias you set with `ANTHROPIC_MODEL`. See `claude-code` for the full environment variables.

## LiteLLM

LiteLLM treats the gateway as an OpenAI-compatible endpoint:

```yaml
model_list:
  - model_name: qwen3-32b
    litellm_params:
      model: openai/qwen3-32b # the alias your AIGatewayRoute matches
      api_base: http://envoy-gateway.llm.svc.cluster.local/v1
      api_key: os.environ/AI_GATEWAY_KEY # placeholder unless inbound auth is on
```

Use one retry owner: either LiteLLM retries and fallbacks, or the gateway's `BackendTrafficPolicy`, not both. Use LiteLLM when you need virtual keys and budgets in front of a gateway that has none (`litellm` skill).

## Agents (Goose and others)

`examples/goose` in the repo shows Goose using the gateway for both LLM and MCP, with `aigw run --mcp-config`. For other agents set the OpenAI base URL and a model alias, then confirm tool calls work against the real backend: tool-calling and structured output quality depend on the upstream model and server parsers (`tool-calling-parsers`, `structured-outputs`). See `goose`, `cline`, `opencode`, `llm-clients` for per-agent settings.

## Smoke test

```bash
curl -fsS "$GATEWAY_URL/v1/models" | jq -e '.data|length>0' >/dev/null && echo models-ok
curl -sS -N "$GATEWAY_URL/v1/chat/completions" -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-32b","stream":true,"messages":[{"role":"user","content":"count to 3"}]}' | head -5
```
