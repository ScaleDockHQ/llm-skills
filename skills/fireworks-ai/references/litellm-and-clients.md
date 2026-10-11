# Fireworks AI with LiteLLM and OpenAI-compatible clients

> Verified against Fireworks OpenAI compatibility and Deployments docs; LiteLLM Fireworks AI provider page (prefix `fireworks_ai/`, env `FIREWORKS_AI_API_KEY`), 2026-10-11

## LiteLLM

LiteLLM's provider prefix is `fireworks_ai/` and the key variable is `FIREWORKS_AI_API_KEY` (the LiteLLM page also mentions `FIREWORKS_API_KEY`). Use the full Fireworks model path after the prefix.

```yaml
model_list:
  - model_name: open-chat
    litellm_params:
      model: fireworks_ai/accounts/fireworks/models/MODEL_NAME
      api_key: os.environ/FIREWORKS_AI_API_KEY
```

Export the key from a 0600 file (`export FIREWORKS_AI_API_KEY="$(cat ~/.config/fireworks/api-key)"`). Fireworks docs note that for routers, `litellm_params.model` takes the full path, for example `fireworks_ai/accounts/fireworks/routers/firerouter/opus`.

For an on-demand deployment through the OpenAI-compatible route (unverified for the native prefix; check https://docs.litellm.ai/docs/providers/fireworks_ai):

```yaml
- model_name: my-dedicated
  litellm_params:
    model: openai/accounts/fireworks/models/MODEL_NAME#accounts/ACCOUNT/deployments/DEPLOYMENT_ID
    api_base: https://api.fireworks.ai/inference/v1
    api_key: os.environ/FIREWORKS_AI_API_KEY
```

A deployment at zero replicas returns 503 while it starts, so keep a serverless or secondary route as a fallback and retry with backoff. See `llm-gateway` for fallback and budget configuration.

## OpenAI SDK

```python
import os
from openai import OpenAI
client = OpenAI(base_url="https://api.fireworks.ai/inference/v1", api_key=os.environ["FIREWORKS_API_KEY"])
```

Tools that read `OPENAI_*` variables: set `OPENAI_API_BASE` (or `OPENAI_BASE_URL`, per the tool) to `https://api.fireworks.ai/inference/v1` and `OPENAI_API_KEY` from your secret store. Do not print the key. `openai.api_base = ...` in old SDKs has a process-wide effect.

## Anthropic SDK

```python
import os, anthropic
client = anthropic.Anthropic(api_key=os.environ["FIREWORKS_API_KEY"], base_url="https://api.fireworks.ai/inference")
```

Note the Anthropic base URL has no `/v1` suffix (the SDK adds `/v1/messages`). Supported for serverless and on-demand deployments.

## Fireworks SDK

`pip install --pre fireworks-ai`, then `Fireworks()` reads `FIREWORKS_API_KEY`. The SDK is documented as alpha: pin the version.

## Reminders

- Model IDs are `accounts/fireworks/models/<name>`; OpenAI names do not exist here.
- Different providers' "same" model can differ in quantization, context and chat template; run evals against the exact provider and model ID (`llm-evals`).
- Responses API `store=true` is the default and retains conversation data for 30 days. Pass `store=False` where that matters.

## Sources

- https://docs.fireworks.ai/tools-sdks/openai-compatibility
- https://docs.fireworks.ai/tools-sdks/anthropic-compatibility
- https://docs.litellm.ai/docs/providers/fireworks_ai
