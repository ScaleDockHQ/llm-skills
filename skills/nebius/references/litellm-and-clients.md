# Nebius: LiteLLM and OpenAI clients

> Verified against LiteLLM docs (Nebius provider) and Nebius Token Factory docs (Switch to Token Factory), 2026-10-11

## OpenAI SDK or curl

```python
import os
from openai import OpenAI
client = OpenAI(base_url="https://api.tokenfactory.nebius.com/v1/", api_key=os.environ["NEBIUS_API_KEY"])
```

For dedicated endpoints use the endpoint's base URL and its `routing_key` as the model (`dedicated-endpoints.md`).

## LiteLLM

LiteLLM has a `nebius/` provider that reads `NEBIUS_API_KEY`. Recent LiteLLM versions route it to Token Factory; older versions used `api.studio.nebius.ai`. If you run an old LiteLLM, upgrade or set the base explicitly. Check https://docs.litellm.ai/docs/providers/nebius for the current base-URL variable and model names.

```yaml
model_list:
  - model_name: kimi
    litellm_params:
      model: nebius/<model-id-from-/v1/models>
      api_key: os.environ/NEBIUS_API_KEY
```

If the prefix misbehaves, use the generic OpenAI route:

```yaml
model: openai/<model-id>
api_base: https://api.tokenfactory.nebius.com/v1/
api_key: os.environ/NEBIUS_API_KEY
```

Test with one request through the gateway. Fallbacks, budgets and keys: `llm-gateway`.
