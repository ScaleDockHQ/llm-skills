# Cerebras API and OpenAI compatibility

> Verified against Cerebras Inference docs (Quickstart, OpenAI Compatibility, Error Codes, Chat Completions, List models, Authentication), cerebras-cloud-sdk usage shown there, 2026-10-11

## Endpoints

- OpenAI-compatible base URL: `https://api.cerebras.ai/v1`
- Chat: `POST https://api.cerebras.ai/v1/chat/completions`
- Models: `GET https://api.cerebras.ai/v1/models` (the API reference also lists `Retrieve model` and `Public models` routes; unverified: whether `Public models` needs a key, check https://inference-docs.cerebras.ai/api-reference/models/public-models)
- Also documented: Completions, Files and Batch (private preview), Metrics (Prometheus format, Dedicated endpoints) and the Dedicated Management API.
- Auth: `Authorization: Bearer $CEREBRAS_API_KEY`.

No Anthropic Messages endpoint is documented on the pages read. Do not point an Anthropic client at Cerebras without a gateway translating the protocol (`llm-gateway`).

## cURL

```bash
curl -sS https://api.cerebras.ai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CEREBRAS_API_KEY" \
  -d '{
    "model": "gpt-oss-120b",
    "messages": [{"role": "user", "content": "Say hi in five words."}],
    "max_completion_tokens": 64
  }' | jq -r '.choices[0].message.content, .usage'
```

Use a model ID that `GET /v1/models` returned for your key.

## OpenAI SDK

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url="https://api.cerebras.ai/v1",
    api_key=os.environ["CEREBRAS_API_KEY"],
)
r = client.chat.completions.create(
    model="gpt-oss-120b",
    messages=[{"role": "user", "content": "Hello"}],
    max_completion_tokens=64,
)
print(r.choices[0].message.content)
```

JavaScript uses `apiKey` and `baseURL`. Many tools accept a custom OpenAI-compatible provider with: base URL `https://api.cerebras.ai/v1`, your key, and an exact model ID. If a tool wants the full endpoint, use `https://api.cerebras.ai/v1/chat/completions`.

## Cerebras SDK

```bash
pip install --upgrade cerebras_cloud_sdk        # Python
npm install @cerebras/cerebras_cloud_sdk@latest  # Node
```

```python
from cerebras.cloud.sdk import Cerebras
client = Cerebras()   # reads CEREBRAS_API_KEY
r = client.chat.completions.create(model="gpt-oss-120b", messages=[{"role": "user", "content": "Hi"}])
```

With the Cerebras SDK, Cerebras-specific parameters (`reasoning_format`, `clear_thinking`) are top-level arguments. With an OpenAI client, pass them in `extra_body`.

## Compatibility differences

| Area                           | Cerebras behavior                                                                                                             |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `n`                            | Only `n: 1`.                                                                                                                  |
| `service_tier`                 | Not available with Shared Inference (private preview, Dedicated only).                                                        |
| `prediction`                   | Depends on endpoint and model; not available for `qwen-3.8-27b` on Shared Inference.                                          |
| Tool streaming                 | Use plain `stream: true`. Do not send `tool_stream`.                                                                          |
| Images                         | `image_url` parts with a base64 PNG or JPEG data URI only. HTTPS URLs and `image_url.detail` are not supported.               |
| `tools` plus `response_format` | `gpt-oss-120b` rejects requests with both. Call tools first, then a second request for the structured result.                 |
| Roles on gpt-oss               | `system` and `developer` both map to a developer-level instruction layer, so prompts may behave more strongly than on OpenAI. |
| `model` field                  | Shared Inference: an exact model ID. Dedicated Inference: your stable endpoint ID.                                            |

## Errors, retries, timeouts

HTTP statuses and SDK exceptions: 400 BadRequest, 401 Authentication, 402 PaymentRequired, 403 PermissionDenied, 404 NotFound, 413 ContentTooLarge, 422 Unprocessable, 429 RateLimit, 500 InternalServer, 503 ServiceUnavailable, plus `APIConnectionError`. All inherit from `cerebras.cloud.sdk.APIError`.

The Cerebras SDK retries connection errors, 408, 429 and 5xx twice by default with short exponential backoff (`max_retries`), and times out after one minute by default (`timeout`). Configure per client or with `client.with_options(...)`.

Image input errors worth recognizing: `"HTTPS image URLs are not supported. Use a base64-encoded data URI instead."` (400), `"Invalid image_url: expected base64 data URI"` (400), `"Image dimensions {w}x{h} exceed the 15000px per-side limit"` (413).

## Official links

- Quickstart: https://inference-docs.cerebras.ai/quickstart
- OpenAI compatibility: https://inference-docs.cerebras.ai/resources/openai
- Error codes: https://inference-docs.cerebras.ai/support/error
- List models: https://inference-docs.cerebras.ai/api-reference/models/list-models
