# SambaNova API and compatibility

> Verified against SambaNova docs (OpenAI compatibility, Anthropic compatibility, API error codes, API keys and URLs), 2026-10-11

## Endpoints (SambaCloud)

- Base URL: `https://api.sambanova.ai/v1`
- `POST /v1/chat/completions` (OpenAI Chat Completions)
- `POST /v1/responses` (OpenAI Responses)
- `POST /v1/messages` and `POST /v1/messages/count_tokens` (Anthropic Messages)
- Also listed in the API reference: completions, embeddings, audio transcription and translation, models list and per-model metadata.

For SambaStack, use the base URL given by your administrator.

## cURL and SDKs

```bash
curl -sS https://api.sambanova.ai/v1/chat/completions \
  -H "Authorization: Bearer $SAMBANOVA_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"gpt-oss-120b","messages":[{"role":"user","content":"Say hi."}],"max_tokens":64}' \
  | jq -r '.choices[0].message.content'
```

```python
import os
from openai import OpenAI

client = OpenAI(base_url="https://api.sambanova.ai/v1", api_key=os.environ["SAMBANOVA_API_KEY"])
r = client.responses.create(model="gpt-oss-120b", input="Two sentences on RDUs.")
print(r.output[0].content[0].text)
```

Use an ID from `GET /v1/models`. A native `sambanova` Python SDK is also used in the docs (`from sambanova import SambaNova`); the OpenAI client works with only `base_url` and `api_key`.

## Anthropic client

```python
import os, anthropic
client = anthropic.Anthropic(base_url="https://api.sambanova.ai/v1", api_key=os.environ["SAMBANOVA_API_KEY"])
```

Or set `ANTHROPIC_BASE_URL` and `ANTHROPIC_API_KEY` (the Anthropic compatibility page uses the base `https://api.sambanova.ai/v1`). Another page (Claude Code integration) may differ on whether the base URL ends in `/v1`; if a client returns 404, try the other form (`references/litellm-and-clients.md`). The `model` must be a SambaNova ID, not a Claude name.

## Differences from OpenAI

- Ignored: `presence_penalty`, `frequency_penalty`.
- `n`: 1 to 8, but `n > 1` with tools or function calling returns 400.
- `seed`: supported on text models; not on multimodal or continuous-batching models. No `system_fingerprint` field in responses.
- `logit_bias`: values -100 to 100 on supported text models; an error (not silently ignored) on unsupported ones.
- `top_k`: supported by SambaNova but not part of OpenAI client types; send through `extra_body`.
- In streaming, each chunk can contain multiple tokens; count tokens per chunk when computing tokens per second.

## Error format

OpenAI-shaped plus a `request_id`:

```json
{
  "error": {
    "message": "...",
    "type": "invalid_request_error",
    "param": "top_p",
    "code": "decimal_above_max_value"
  },
  "request_id": "..."
}
```

Quote the `request_id` to support (help@sambanova.ai per the deprecations page). Status codes: 400, 401, 408, 410, 429 (`insufficient_quota` or `queue_full`), 500, 503. See `troubleshooting.md`.

## Official links

- OpenAI compatibility: https://docs.sambanova.ai/docs/en/features/openai-compatibility.md
- Anthropic compatibility: https://docs.sambanova.ai/docs/en/features/anthropic-compatibility.md
- Error codes: https://docs.sambanova.ai/docs/en/api-reference/using-the-api/api-error-codes.md
