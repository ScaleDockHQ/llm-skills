# OpenAI API: LiteLLM and OpenAI-compatible clients

> Verified against LiteLLM OpenAI provider docs, OpenAI Developer quickstart, API reference "List models", 2026-10-11

## LiteLLM proxy entry

The `openai/` prefix routes to api.openai.com. The key is read from the environment, never pasted in YAML.

```yaml
model_list:
  - model_name: gpt-main # alias your clients call
    litellm_params:
      model: openai/<pinned-model-id> # taken from GET /v1/models
      api_key: os.environ/OPENAI_API_KEY
      max_budget: 50 # USD per budget_duration for this deployment
      budget_duration: 30d
  - model_name: "*" # optional wildcard: any OpenAI model not listed above
    litellm_params:
      model: openai/*
      api_key: os.environ/OPENAI_API_KEY
```

```bash
export OPENAI_API_KEY="$(cat ~/.config/llm/openai.key)"   # from a 0600 file, never printed
litellm --config config.yaml
```

- Use a dedicated project key for the gateway (`references/setup-and-auth.md`); clients get LiteLLM virtual keys.
- LiteLLM's docs also describe OpenAI workload identity federation (a token file plus `openai_identity_provider_id` and `openai_service_account_id`) instead of a static key. Treat it as optional and confirm in both products' docs first.
- Fallbacks, budgets and routing live in the gateway: `llm-gateway` and `litellm` skills. A cross-provider example is in the `cloud-llms` skill assets.

## OpenAI SDK against OpenAI

```python
from openai import OpenAI
client = OpenAI()  # OPENAI_API_KEY from the environment
```

## OpenAI SDK against a gateway or compatible server

```python
import os
from openai import OpenAI
client = OpenAI(base_url="https://llm.example.com/v1", api_key=os.environ["GATEWAY_KEY"])
```

Gateways and most compatible servers speak `/v1/chat/completions`; only call `/v1/responses` on them after confirming support. Environment-based clients (many agents) honor `OPENAI_BASE_URL` and `OPENAI_API_KEY`; confirm in the client's docs.

## Health and discovery

```bash
curl -sS https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY" | jq '.data | length'
```

There is no public health endpoint to poll; use the status page and your gateway's health checks. See `llm-clients` for tools that take a base URL and `llm-observability` for tracing.

## Where to read more

- https://docs.litellm.ai/docs/providers/openai
