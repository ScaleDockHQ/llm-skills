# Groq with LiteLLM and clients

> Verified against GroqDocs: LiteLLM integration, OpenAI Compatibility, Client Libraries, Quickstart; LiteLLM docs for Groq provider, 2026-10-11

## LiteLLM

Prefix the model with `groq/` and set `GROQ_API_KEY` in the environment of the LiteLLM process.

```python
import os
from litellm import completion

os.environ["GROQ_API_KEY"]  # must already be set; do not hardcode
r = completion(model="groq/<MODEL_ID>", messages=[{"role": "user", "content": "ping"}])
```

LiteLLM proxy entry:

```yaml
model_list:
  - model_name: groq-fast
    litellm_params:
      model: groq/<MODEL_ID>
      api_key: os.environ/GROQ_API_KEY
```

Pass `service_tier` through `extra_body` or as a request parameter if your LiteLLM version forwards it; unverified, check https://docs.litellm.ai/docs/providers/groq. Put an `on_demand` or other-provider fallback behind a flex model in the gateway (`llm-gateway`), because flex fails fast with 498.

## OpenAI-compatible clients

Any client that accepts a base URL works:

```bash
export OPENAI_BASE_URL=https://api.groq.com/openai/v1
export OPENAI_API_KEY="$(cat ~/.config/groq/api-key)"   # file is 0600; never echo it
```

Check before relying on it: `logprobs`, `logit_bias`, `top_logprobs`, `messages[].name` and `n > 1` return 400, which breaks some agent frameworks. Disable those options in the client. See `llm-clients` for tool-specific settings.

## Native SDKs

```bash
pip install groq
npm install groq-sdk
```

Both expose chat completions, batches, files and fine_tunings resources, and read the key you pass explicitly from the environment.

## Smoke test through any path

```bash
curl -s "$OPENAI_BASE_URL/chat/completions" -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"<MODEL_ID>","messages":[{"role":"user","content":"ping"}],"max_completion_tokens":8}' | jq -r '.choices[0].message.content'
```

## Sources

- https://console.groq.com/docs/litellm
- https://console.groq.com/docs/openai
- https://console.groq.com/docs/libraries
- https://docs.litellm.ai/docs/providers/groq
