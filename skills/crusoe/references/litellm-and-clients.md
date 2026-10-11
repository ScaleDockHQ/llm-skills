# Crusoe: LiteLLM and OpenAI clients

> Verified against LiteLLM docs (Crusoe provider) and Crusoe Managed Inference docs, 2026-10-11

## OpenAI SDK

```python
import os
from openai import OpenAI
client = OpenAI(base_url="https://api.inference.crusoecloud.com/v1", api_key=os.environ["CRUSOE_API_KEY"])
```

For a self-serve deployment use the same base URL and the deployment alias as `model`.

## LiteLLM

LiteLLM has a `crusoe/` provider reading `CRUSOE_API_KEY`. Its default base URL moved from `managed-inference-api-proxy.crusoecloud.com` to `api.inference.crusoecloud.com`; older LiteLLM versions use the old host, and `CRUSOE_API_BASE` overrides it. The model names in LiteLLM's docs are stale because several have been deprecated: use ids from `/v1/models`.

```yaml
model_list:
  - model_name: crusoe-chat
    litellm_params:
      model: crusoe/<model-id-from-/v1/models>
      api_key: os.environ/CRUSOE_API_KEY
      api_base: https://api.inference.crusoecloud.com/v1
```

Fallback: `openai/<model-id>` with the same `api_base`. Check https://docs.litellm.ai/docs/providers/crusoe for the current form. Test one request. Gateway policy: `llm-gateway`.
