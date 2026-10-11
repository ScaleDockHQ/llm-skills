# Vercel AI SDK behind LiteLLM or llama-swap

> Verified against Vercel AI SDK ai@7.0.137 (@ai-sdk/openai-compatible 3.0.67, @ai-sdk/anthropic 4.0.78), 2026-10-11

A gateway gives the app one URL, one key and stable aliases; the AI SDK needs only the gateway's base URL. Run and secure the gateway with the `litellm` skill (`npx skills add ScaleDockHQ/llms-skills --skill litellm`) or `llama-swap` (`npx skills add ScaleDockHQ/llms-skills --skill llama-swap`).

```ts
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
export const gw = createOpenAICompatible({
  name: "gateway",
  baseURL: process.env.LLM_BASE_URL!, // https://llm.example.com/v1
  apiKey: process.env.LLM_API_KEY, // virtual key, scoped and budgeted at the gateway
  includeUsage: true,
});
```

- **Model ids** are the gateway aliases (`GET /v1/models`). Renaming the engine's model changes nothing in the app.
- **Anthropic route:** `createAnthropic({ baseURL: "https://llm.example.com/v1", authToken: ... })` works when the gateway serves `/v1/messages`; the gateway bridges to chat-only engines.
- **Per-app keys:** give each service its own virtual key; rotate by replacing the env var.
- **Capability flags** still describe the engine behind the alias. If an alias can route to different engines, set flags for the weakest.
- **Failures:** a 401 is the gateway key; a 5xx or 400 `model not found` after a gateway config change means the alias moved; compare `/v1/models` before and after.
- **Behind a tunnel or access proxy:** pass service-token headers with `headers`, and make sure SSE is not buffered.
