# Baseten with LiteLLM and OpenAI-compatible clients

> Verified against docs.litellm.ai/docs/providers/baseten, docs.baseten.co model-apis overview, inference/calling-your-model, external gateway docs, 2026-10-11

## LiteLLM provider

Model APIs use `baseten/<org>/<model>`. Dedicated deployments use `baseten/<8-character model id>`. The key comes from `BASETEN_API_KEY`.

```yaml
model_list:
  - model_name: baseten-model-api
    litellm_params:
      model: baseten/<org>/<model> # slug from `baseten model-api list`
      api_key: os.environ/BASETEN_API_KEY
  - model_name: baseten-dedicated
    litellm_params:
      model: baseten/<model-id> # 8-character ID of your deployment
      api_key: os.environ/BASETEN_API_KEY
```

LiteLLM's page notes streaming for Model APIs only. For a dedicated deployment, if you need streaming through the provider entry, test it, or use the OpenAI-compatible form below.

## OpenAI-compatible form (dedicated)

Baseten's external-gateway docs give: base URL `https://model-<id>.api.baseten.co/environments/production/sync/v1`, `model` equal to the server's `--served-model-name`, key equal to your Baseten API key.

```yaml
- model_name: baseten-dedicated-oai
  litellm_params:
    model: openai/<served-model-name>
    api_base: https://model-<id>.api.baseten.co/environments/production/sync/v1
    api_key: os.environ/BASETEN_API_KEY
```

Remove the entry at teardown and add a fallback to another route in the gateway (the `llm-gateway` skill).

## OpenAI SDK

```python
from openai import OpenAI
import os
client = OpenAI(base_url="https://inference.baseten.co/v1", api_key=os.environ["BASETEN_API_KEY"])
```

For a dedicated model use its sync base URL instead. Streaming responses end with `data: [DONE]`.

## Anthropic SDK

Base URL `https://inference.baseten.co`, endpoint `/v1/messages`. The SDK sends `x-api-key`, so override default headers to send `Authorization: Bearer <key>`. This surface is beta, so check https://docs.baseten.co before relying on it.

## Gateway tips

- Give the gateway an inference-only key, not a manage-all key.
- Retry on 429 and 529 with backoff. Honour `Retry-After`.
- A scaled-to-zero dedicated model answers slowly on the first request (cold start). Set the gateway timeout above the expected cold start, or keep one replica.
- Stateful session reuse on Model APIs: pass the `x-session-affinity` header via the client's extra headers.

## Verify

- [ ] `curl` the base URL's `/models` or a 16-token completion through the gateway.
- [ ] A forced 429 or a dead deployment falls back as intended.
