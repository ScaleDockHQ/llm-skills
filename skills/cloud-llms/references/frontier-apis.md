# Frontier APIs: OpenAI, Anthropic, Google Gemini

> Verified against OpenAI API docs (rate limits, Batch, prompt caching, data controls), Anthropic Claude Platform docs (OpenAI SDK compatibility, rate limits, Message Batches, prompt caching, data retention), Gemini API docs (OpenAI compatibility, batch mode, caching, rate limits, Additional Terms), 2026-10-11

Closed models consumed through the vendor's own API. Choose this tier when only a frontier model passes your eval and the data class allows it. For your cloud contract, IAM or residency, use the same models through a hyperscaler (`hyperscalers.md`).

Depth: install the `openai-api` skill (`npx skills add ScaleDockHQ/llms-skills --skill openai-api`), the `anthropic-api` skill (`npx skills add ScaleDockHQ/llms-skills --skill anthropic-api`) and the `gemini-api` skill (`npx skills add ScaleDockHQ/llms-skills --skill gemini-api`).

## How it plugs into this stack

- Add each provider as a LiteLLM deployment with the native provider prefix (`openai/`, `anthropic/`, `gemini/`) and `api_key: os.environ/...`. See `assets/litellm-hybrid.yaml`.
- Use the native prefixes rather than the vendors' OpenAI-compatibility layers when you need native features. For example, Anthropic's OpenAI compatibility layer ignores `strict` on function definitions and does not support prompt caching.
- Clients call aliases on the gateway. Coding agents that speak the Anthropic Messages API can use the gateway's `/v1/messages` route (details in `llm-gateway`).
- Keys: one key per project or environment, injected into the gateway only. Clients get gateway keys.
- Health: no public health endpoint to poll; use gateway health checks and the vendors' status pages.
- Every provider returns HTTP 429 when limited: retries with backoff and a fallback alias in the gateway, never a tight loop.
- Data floor: the Gemini API's unpaid tier may use content to improve products. Use a paid project, or the hyperscaler route, for non-public data.
- Pin dated model IDs; keep a tested fallback alias for deprecations.

## Official links

- OpenAI data controls: https://developers.openai.com/api/docs/guides/your-data
- Anthropic OpenAI SDK compatibility: https://platform.claude.com/docs/en/api/openai-sdk
- Gemini OpenAI compatibility: https://ai.google.dev/gemini-api/docs/openai
- Gemini API terms: https://ai.google.dev/gemini-api/terms
