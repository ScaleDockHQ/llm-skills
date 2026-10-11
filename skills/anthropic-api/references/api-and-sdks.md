# Anthropic API: Messages API, SDKs and OpenAI compatibility

> Verified against Claude Platform docs: API overview, Get started, Models API "List models", OpenAI SDK compatibility, API errors, 2026-10-11

## Endpoints

| Endpoint                          | Purpose                                                  |
| --------------------------------- | -------------------------------------------------------- |
| `POST /v1/messages`               | Messages API (native, full feature set)                  |
| `POST /v1/messages/count_tokens`  | Count tokens before sending                              |
| `POST /v1/messages/batches`       | Message Batches (`references/features.md`)               |
| `GET /v1/models`                  | List models with capabilities, `lifecycle`, `retires_at` |
| `POST /v1/files`, `GET /v1/files` | Files API                                                |

Request size limits: Messages and token counting 32 MB, Batches 256 MB, Files 500 MB (`413 request_too_large` beyond).

## SDKs

```bash
pip install anthropic                 # Python
npm install @anthropic-ai/sdk         # TypeScript
# Also official: C# (dotnet add package Anthropic), Go (github.com/anthropics/anthropic-sdk-go), Java, PHP, Ruby
```

SDKs retry transient failures (connection errors, `429`, 5xx) with exponential backoff, twice by default, honoring `retry-after`; tune with `max_retries`.

## First call

Pick an active model from the list and keep it in a variable. The docs' examples use `claude-opus-5-5`; pin the ID you choose.

```bash
curl -sS https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d "$(jq -n --arg m "$ANTHROPIC_MODEL" '{model:$m, max_tokens:256, messages:[{role:"user",content:"Say hello in five words."}]}')" \
  | jq -r '.content[] | select(.type=="text") | .text'
```

```python
import anthropic

client = anthropic.Anthropic()  # ANTHROPIC_API_KEY from the environment
msg = client.messages.create(model="<pinned-model-id>", max_tokens=256,
                             messages=[{"role": "user", "content": "Hello"}])
print([b.text for b in msg.content if b.type == "text"])
```

`max_tokens` is required. `content` is a list of blocks (text, tool_use, thinking); always filter by `type`. Current docs: Claude 4.7 and later models reject `temperature` below 1 and any `top_p` other than the default, and a request that sets both returns `400`; omit them. Check the models page for per-model thinking and tool-choice rules (for example some models do not support forced `tool_choice`).

## List models

```bash
curl -sS "https://api.anthropic.com/v1/models?limit=100" -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" \
  | jq -r '.data[] | [.id, .display_name, .lifecycle, (.retires_at // "-")] | @tsv'
# include retired models in the history
curl -sS "https://api.anthropic.com/v1/models?lifecycle=retired&lifecycle=active&lifecycle=deprecated" \
  -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" | jq '.data | length'
```

`lifecycle` is `active`, `deprecated` (still callable for existing users, closed to new adopters) or `retired` (requests fail). Capabilities per model (batch, structured outputs, effort, thinking types, PDF input) are in the same response. Pagination uses `after_id` and `has_more`.

## OpenAI SDK compatibility layer

Intended for testing and comparing models, not a long-term or production path for most uses; use the native API for PDFs, citations, thinking and prompt caching.

```python
import os
from openai import OpenAI

client = OpenAI(api_key=os.environ["ANTHROPIC_API_KEY"], base_url="https://api.anthropic.com/v1/")
r = client.chat.completions.create(model="<claude-model-id>", messages=[
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Who are you?"}])
print(r.choices[0].message.content)
```

If the key spans several workspaces, also send `anthropic-workspace-id` (for example `default_headers={"anthropic-workspace-id": "wrkspc_..."}`).

Documented limits:

| Area                      | Behavior                                                                                                                                       |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `strict` on tools         | Ignored: tool JSON is not guaranteed to match the schema                                                                                       |
| `response_format`         | Ignored: use native structured outputs                                                                                                         |
| Prompt caching            | Not supported (works in the Anthropic SDKs)                                                                                                    |
| System/developer msgs     | Hoisted and joined with a newline into the top-level `system` field                                                                            |
| `n`                       | Must be 1                                                                                                                                      |
| Ignored fields            | `logprobs`, `seed`, `metadata`, `presence_penalty`, `frequency_penalty`, `service_tier`, `store`, `user`, `reasoning_effort`, audio and others |
| `temperature`             | Capped at 1; on 4.7+ models values below 1 return `400`                                                                                        |
| Audio input, `file` parts | Ignored                                                                                                                                        |
| Thinking                  | Enable via `extra_body={"thinking": {...}}`; thinking content is not returned                                                                  |
| Usage details             | `prompt_tokens_details` and `completion_tokens_details` always empty                                                                           |
| Rate limits               | Same as `/v1/messages`; `x-ratelimit-*` and `retry-after` headers are supported                                                                |

Most unsupported fields are silently ignored, so verify behavior rather than assuming parity.

## Where to read more

- https://platform.claude.com/docs/en/api/openai-sdk
- https://platform.claude.com/docs/en/api/models/list
- https://platform.claude.com/docs/en/api/overview
