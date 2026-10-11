# SDKs: OpenAI, Anthropic, Vercel AI SDK

> Verified against openai-python v3.28.0, openai-node v7.32.0, anthropic-sdk-python v1.13.0, anthropic-sdk-typescript sdk-v0.133.0, Vercel AI SDK ai@7.0.137 (@ai-sdk/openai 3.0.125), 2026-10-11

Application code is the easiest client to point at a gateway: every official SDK takes a base URL and a key. The traps are base-URL shape (with or without `/v1`) and SDKs that default to a newer API than your endpoint serves.

| SDK | Base URL option (env) | Expected shape | Default API |
|---|---|---|---|
| openai (Python) | `base_url` (`OPENAI_BASE_URL`) | `https://llm.example.com/v1` | whatever method you call (`chat.completions` or `responses`) |
| openai (Node) | `baseURL` (`OPENAI_BASE_URL`) | `https://llm.example.com/v1` | same |
| anthropic (Python) | `base_url` (`ANTHROPIC_BASE_URL`) | `https://llm.example.com` (no `/v1`) | Messages |
| @anthropic-ai/sdk (Node) | `baseURL` (`ANTHROPIC_BASE_URL`) | `https://llm.example.com` (no `/v1`) | Messages |
| @ai-sdk/openai | `baseURL` (`OPENAI_BASE_URL`) | `https://llm.example.com/v1` | **Responses** for `openai(id)` |
| @ai-sdk/openai-compatible | `baseURL` | `https://llm.example.com/v1` | Chat Completions |
| @ai-sdk/anthropic | `baseURL` | `https://llm.example.com/v1` (**includes** `/v1`) | Messages |

## OpenAI SDK (Python and Node)

### What it is and when to choose it

The reference client for Chat Completions and Responses. Works with any OpenAI-compatible engine or gateway.

### Config location

Constructor arguments or env vars `OPENAI_BASE_URL` and `OPENAI_API_KEY`.

### Minimal config

```python
import os
from openai import OpenAI

client = OpenAI(base_url="https://llm.example.com/v1", api_key=os.environ["LITELLM_API_KEY"])
r = client.chat.completions.create(model="coder", messages=[{"role": "user", "content": "ping"}])
```

```ts
import OpenAI from "openai";

const client = new OpenAI({ baseURL: "https://llm.example.com/v1", apiKey: process.env.LITELLM_API_KEY });
```

### Capability flags

None client-side. Send only what the backend supports; extra provider-specific fields go through `extra_body` (Python) or extra body params in Node, headers through `extra_headers`.

### Pitfalls

- `client.responses.create` against a chat-only endpoint returns 404; use `chat.completions` or bridge in the gateway.
- A missing `/v1` on the base URL yields 404 on every call.
- Local endpoints that need no key still require a non-empty `api_key` string.

## Anthropic SDK (Python and TypeScript)

### What it is and when to choose it

Messages API client. Use against Anthropic or a gateway route that serves `/v1/messages`.

### Config location

Constructor or env: `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY` (sent as `x-api-key`), `ANTHROPIC_AUTH_TOKEN` (sent as `Authorization: Bearer`).

### Minimal config

```python
import os
from anthropic import Anthropic

client = Anthropic(base_url="https://llm.example.com", auth_token=os.environ["LITELLM_API_KEY"])
msg = client.messages.create(model="claude-main", max_tokens=64, messages=[{"role": "user", "content": "ping"}])
```

TypeScript: `new Anthropic({ baseURL: "https://llm.example.com", authToken: process.env.LITELLM_API_KEY })`.

### Capability flags

None client-side. Beta features are opt-in per request (`anthropic-beta` header); non-Anthropic backends behind a gateway often reject them.

### Pitfalls

- Base URL with `/v1` produces `/v1/v1/messages`.
- Setting both `api_key` and `auth_token` sends both headers; pick the one your gateway checks.

## Vercel AI SDK

### What it is and when to choose it

TypeScript framework with provider packages. Three ways to reach a custom endpoint, depending on the API it serves.

### Config location

Provider factory options in code; keys from `process.env`.

### Minimal config

Chat Completions endpoint (engines, most gateways):

```ts
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { generateText } from "ai";

const gateway = createOpenAICompatible({
  name: "gateway",
  baseURL: "https://llm.example.com/v1",
  apiKey: process.env.LITELLM_API_KEY,
  includeUsage: true,
});

const { text } = await generateText({ model: gateway("coder"), prompt: "ping" });
```

Responses endpoint: `createOpenAI({ baseURL, apiKey })` then `openai("coder")` or `openai.responses("coder")`. Chat-only endpoint with the OpenAI provider: `openai.chat("coder")`.

Anthropic Messages endpoint: `createAnthropic({ baseURL: "https://llm.example.com/v1", authToken: process.env.LITELLM_API_KEY })`.

### Capability flags

`createOpenAICompatible` options: `includeUsage` (usage in streams), `supportsStructuredOutputs`, `supportsMultiPartToolContent`, `headers`, `queryParams`.

### Pitfalls

- `openai(id)` calls the Responses API (since AI SDK 5). Against a chat-only engine that is a 404; use `openai.chat(id)` or `createOpenAICompatible`.
- `@ai-sdk/anthropic` expects the base URL **with** `/v1`, unlike the Anthropic SDK.
- Without `includeUsage: true`, streamed responses report no token usage.

## Test tool calls in CI

Chat succeeding proves little. Add one integration test per model alias that sends a tool definition and asserts a tool call comes back:

```bash
curl -sS https://llm.example.com/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"coder","messages":[{"role":"user","content":"What is the weather in Paris? Use the tool."}],
       "tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}]}' \
  | jq '.choices[0].message.tool_calls[0].function'
```

## Official links

- openai-python: https://github.com/openai/openai-python
- openai-node: https://github.com/openai/openai-node
- Anthropic Python SDK: https://github.com/anthropics/anthropic-sdk-python
- Anthropic TypeScript SDK: https://github.com/anthropics/anthropic-sdk-typescript
- Anthropic client SDKs: https://platform.claude.com/docs/en/api/client-sdks
- AI SDK OpenAI-compatible providers: https://ai-sdk.dev/providers/openai-compatible-providers
- AI SDK OpenAI provider: https://ai-sdk.dev/providers/ai-sdk-providers/openai
- AI SDK Anthropic provider: https://ai-sdk.dev/providers/ai-sdk-providers/anthropic
