# Cerebras with LiteLLM and OpenAI clients

> Verified against LiteLLM provider page (docs.litellm.ai/docs/providers/cerebras), Cerebras LiteLLM integration and OpenAI compatibility pages, 2026-10-11

## LiteLLM provider

LiteLLM has a native `cerebras/` prefix and reads `CEREBRAS_API_KEY`. No `api_base` is needed.

```python
import os
from litellm import completion

r = completion(
    model="cerebras/gpt-oss-120b",           # cerebras/<id from GET /v1/models>
    messages=[{"role": "user", "content": "Hello"}],
    max_tokens=64,
    extra_headers={"X-Cerebras-3rd-Party-Integration": "litellm"},
)
```

Cerebras asks integrations to send the `X-Cerebras-3rd-Party-Integration` header. It is not a secret.

## LiteLLM proxy

```yaml
model_list:
  - model_name: cerebras-gpt-oss
    litellm_params:
      model: cerebras/gpt-oss-120b
      api_key: os.environ/CEREBRAS_API_KEY
      extra_headers:
        X-Cerebras-3rd-Party-Integration: litellm
      rpm: 100 # your own cap; read real limits in the Cloud Console
```

Notes:

- Cerebras' own LiteLLM page shows the proxy variant `custom_llm_provider: openai` with `api_base: https://api.cerebras.ai/v1`, while the LiteLLM page uses the `cerebras/` prefix. Prefer the `cerebras/` prefix; it is the provider LiteLLM documents.
- Set `rpm`/`tpm` per deployment lower than the project limit, so the gateway queues before Cerebras returns 429.
- Add a second deployment under the same `model_name` from another provider for failover. Strategy and fallback design: `llm-gateway`, `litellm`, `cloud-llms`.

Validate through the proxy:

```bash
curl -sS http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"cerebras-gpt-oss","messages":[{"role":"user","content":"ping"}],"max_tokens":16}' | jq .usage
```

## Any OpenAI-compatible tool

| Field    | Value                                       |
| -------- | ------------------------------------------- |
| Base URL | `https://api.cerebras.ai/v1`                |
| API key  | `CEREBRAS_API_KEY` (from a file or env var) |
| Model    | exact ID from `/v1/models`                  |

Tools that only accept the OpenAI Chat Completions shape work. Tools that require `n > 1`, image URLs by HTTPS, or Anthropic's Messages API need a gateway or will fail (`api-and-compat.md`).

## Embeddings

No embeddings endpoint was listed on the pages read. Unverified: check https://inference-docs.cerebras.ai/api-reference before routing embedding traffic here; use another provider through the gateway.

## Official links

- LiteLLM: https://docs.litellm.ai/docs/providers/cerebras
- Cerebras OpenAI compatibility: https://inference-docs.cerebras.ai/resources/openai
