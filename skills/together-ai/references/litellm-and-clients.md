# Together AI with LiteLLM and OpenAI-compatible clients

> Verified against Together OpenAI compatibility and Dedicated endpoints "Send requests" docs; LiteLLM Together AI provider page (prefix `together_ai/`, env `TOGETHERAI_API_KEY`), 2026-10-11

## LiteLLM serverless entry

LiteLLM's provider prefix is `together_ai/` and its key variable is `TOGETHERAI_API_KEY` (note: not `TOGETHER_API_KEY`).

```yaml
model_list:
  - model_name: open-chat
    litellm_params:
      model: together_ai/MODEL_ID # exactly as listed by GET /v1/models
      api_key: os.environ/TOGETHERAI_API_KEY
```

Start the proxy with the key exported from a 0600 file (`export TOGETHERAI_API_KEY="$(cat ~/.config/together/api-key)"`). Keep the same alias for a self-hosted copy as a second deployment or fallback; see the `llm-gateway` skill.

## LiteLLM dedicated endpoint entry

A dedicated endpoint is OpenAI-compatible at `https://api-inference.together.ai/v1`, with the endpoint string as the model. Use LiteLLM's generic OpenAI route:

```yaml
model_list:
  - model_name: my-dedicated
    litellm_params:
      model: openai/your-project-slug/my-endpoint
      api_base: https://api-inference.together.ai/v1
      api_key: os.environ/TOGETHERAI_API_KEY
```

Unverified: whether the `together_ai/` prefix accepts a custom `api_base` for dedicated endpoints. Check https://docs.litellm.ai/docs/providers/togetherai before using it that way. Note that a stopped or scaled-to-zero deployment makes this route fail, so pair it with a serverless fallback.

## OpenAI SDK

```python
import os
from openai import OpenAI

serverless = OpenAI(api_key=os.environ["TOGETHER_API_KEY"], base_url="https://api.together.ai/v1")
dedicated = OpenAI(api_key=os.environ["TOGETHER_API_KEY"], base_url="https://api-inference.together.ai/v1")
```

```ts
import OpenAI from "openai";
const client = new OpenAI({
  apiKey: process.env.TOGETHER_API_KEY,
  baseURL: "https://api.together.ai/v1",
});
```

Environment-variable style for tools that read `OPENAI_*`: set `OPENAI_BASE_URL=https://api.together.ai/v1` and `OPENAI_API_KEY` from your secret store (do not print it).

## Compatibility reminders

- Model IDs are namespaced; OpenAI names 404.
- Assistants, Threads, Runs, OpenAI-shaped batches and fine-tuning are not served through `/v1`. Use `tg` or the `together` SDK.
- Use the `together` SDK for Together-native features: reasoning controls, video generation, batch, fine-tuning, files.
- The dedicated base URL serves inference only.

## Cost tracking

Give each workload its own key so cost analytics can attribute spend via `api_key_id`. Track per-request cost in the gateway (see `llm-observability`) because Together has no per-key budgets.

## Sources

- https://docs.together.ai/docs/inference/openai-compatibility
- https://docs.together.ai/docs/dedicated-endpoints/requests
- https://docs.litellm.ai/docs/providers/togetherai
