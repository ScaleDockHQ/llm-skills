# SDKs and frameworks: OpenAI, Anthropic, Vercel AI SDK, LangChain, LlamaIndex, Pydantic AI

> Verified against openai-python, anthropic-sdk-python and Vercel AI SDK docs, 2026-10-11

Stack notes only. Per-SDK config, structured output, tools, streaming and troubleshooting live in the product skills.

## How they plug into this stack

Pick the client that matches the API the endpoint serves, set base URL and key from env, and keep a tool-call integration test in CI.

Stack pitfalls:

- Responses calls (`client.responses.create`, Vercel `openai(id)`, Pydantic AI bare `openai:`) 404 on chat-only endpoints; use chat completions, `openai.chat(id)`, `createOpenAICompatible`, or bridge in the gateway.
- OpenAI SDK base URL needs `/v1`; Anthropic SDK base URL must not (`/v1/v1/messages`); `@ai-sdk/anthropic` wants it.
- Keyless local endpoints still need a non-empty `api_key` string.
- Setting both `api_key` and `auth_token` on the Anthropic SDK sends both headers.
- Streamed usage is missing unless requested (`includeUsage: true`, `stream_usage`).

CI check per alias:

```bash
curl -sS https://llm.example.com/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"coder","messages":[{"role":"user","content":"What is the weather in Paris? Use the tool."}],
       "tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}]}' \
  | jq '.choices[0].message.tool_calls[0].function'
```

Depth:

- `openai-sdk`: `npx skills add ScaleDockHQ/llms-skills --skill openai-sdk`
- `anthropic-sdk`: `npx skills add ScaleDockHQ/llms-skills --skill anthropic-sdk`
- `vercel-ai-sdk`: `npx skills add ScaleDockHQ/llms-skills --skill vercel-ai-sdk`
- `langchain`: `npx skills add ScaleDockHQ/llms-skills --skill langchain`
- `llamaindex`: `npx skills add ScaleDockHQ/llms-skills --skill llamaindex`
- `pydantic-ai`: `npx skills add ScaleDockHQ/llms-skills --skill pydantic-ai`
