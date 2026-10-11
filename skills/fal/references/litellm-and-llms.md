# fal with LiteLLM and OpenAI clients

> Verified against docs.litellm.ai/docs/providers/fal_ai, fal.ai/docs use-llms example, fal model pages for the OpenRouter router and any-llm, 2026-10-11

fal is genmedia-first. Its LLM support is a side feature, so prefer a text-first provider for chat unless you want one bill for media and text (`cloud-llms`).

## LiteLLM `fal_ai/` provider (images)

LiteLLM's provider uses the `fal_ai/` prefix with `FAL_AI_API_KEY` (not `FAL_KEY`). Per LiteLLM's page it covers `/images/generations`, for example `fal_ai/fal-ai/flux-pro/v1.1-ultra` and `fal_ai/flux/schnell`. Check the LiteLLM page for the current model list.

```yaml
model_list:
  - model_name: fal-image
    litellm_params:
      model: fal_ai/fal-ai/flux/schnell # confirm the endpoint exists on fal first
      api_key: os.environ/FAL_AI_API_KEY
```

Do not expect video, audio, 3D or custom serverless apps through this provider. Call those with `fal-client` or the queue API.

## OpenAI-compatible text route

fal exposes `https://fal.run/openrouter/router/openai/v1` with `/chat/completions`. The model page says it is powered by OpenRouter and billed by tokens. With the OpenAI SDK, point `base_url` at it, set `api_key` to a placeholder, and send fal's header:

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url="https://fal.run/openrouter/router/openai/v1",
    api_key="not-used",
    default_headers={"Authorization": f"Key {os.environ['FAL_KEY']}"},
)
```

LiteLLM equivalent (an `openai/` entry with a custom header; verify the LiteLLM `extra_headers` syntax in its docs):

```yaml
- model_name: fal-openrouter
  litellm_params:
    model: openai/<openrouter-model-name>
    api_base: https://fal.run/openrouter/router/openai/v1
    api_key: "not-used"
    extra_headers:
      Authorization: "Key os.environ/FAL_KEY" # unverified: check LiteLLM for env interpolation inside headers
```

If env interpolation inside headers does not work in your LiteLLM version, front it with a small proxy or use a different provider. Model names and availability come from the model page. The tutorial's names looked stale on 2026-10-11.

## Simple LLM endpoint

`fal-ai/any-llm` takes `{prompt, model}` through the normal queue flow (`references/model-apis.md`). It is not OpenAI-shaped.

## Gateway tips

- Image generation is slow. Use the queue with webhooks, and give gateway routes long timeouts.
- fal returns media URLs that expire. Copy them before returning to a client that may fetch later.
- Retry policy on fal's side (up to 10 retries on 503, 504 and 429) can stack with gateway retries. Keep one layer.

## Verify

- [ ] A tiny image or a 16-token completion returns through the gateway.
- [ ] An expired key returns a clean error, not a hang.
