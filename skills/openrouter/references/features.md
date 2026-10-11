# OpenRouter presets, caching, structured outputs and tools

> Verified against OpenRouter API v1 (docs: features/presets, response-caching, structured-outputs, tool-calling, plugins, server-tools), 2026-10-11

## Presets

Named, versioned configurations managed at https://openrouter.ai/settings/presets: model or model list with fallbacks, provider routing, system prompt, generation parameters, provider include/exclude rules and tools (including OpenRouter server tools such as `openrouter:web_search`). Use them to change behavior without redeploying clients. Three ways to reference one:

```json
{"model": "@preset/email-copywriter"}
{"model": "openai/gpt-4@preset/email-copywriter"}
{"preset": "@preset/email-copywriter"}
```

A bare slug without the `@preset/` prefix is ignored in the `preset` field. Request tools are unioned with the preset's tools and a request tool overrides the same identity. You can also create or update a preset from a request body with `POST /api/v1/presets/{slug}/chat/completions` (and `/messages`, `/responses`): a new version becomes active. Keep presets out of reach of untrusted editors, since editing one changes every client using it.

## Response caching

Opt in per request with `X-OpenRouter-Cache: true`, or per preset with `cache_enabled` and `cache_ttl_seconds` (1 to 86400, default 300). Hits return from OpenRouter with zeroed usage and no billing; status is in `X-OpenRouter-Cache-Status` (`HIT` or `MISS`), `-Age` and `-TTL`. The cache key is the API key, model, endpoint type, streaming mode and a SHA-256 of the exact body, so key order and explicit defaults change it, and caches do not share across keys. Only 200 responses are cached. Cached output ignores `temperature`; send `X-OpenRouter-Cache-Clear: true` to refresh one entry. Do not enable it for prompts where fresh randomness or per-user data matters. Prompt caching (provider-side) is separate; see guides/best-practices/prompt-caching.

## Structured outputs

`response_format: {"type":"json_schema","json_schema":{...}}` for strict schema, `{"type":"json_object"}` for plain JSON. Only models that list `structured_outputs` in `supported_parameters` honor it. Combine with `provider.require_parameters: true` so the request does not land on a provider that ignores it. The `response-healing` plugin repairs malformed JSON.

## Tool calling

OpenAI-style `tools` and `tool_choice`. Tool support is per model and provider; use `provider.require_parameters: true`, or the `:exacto` suffix to sort providers by tool-call reliability. OpenRouter server tools (`openrouter:web_search`, `datetime`, `image_generation`, and others listed under server-tools) run on OpenRouter's side and are billed separately; read their pages for charges before enabling.

## Plugins

Add `plugins: [...]` to a request: `web` (search), `file-parser` (PDFs), `response-healing`, `context-compression` (middle-out compression). The `:online` suffix is deprecated in favor of the web search server tool.

## Verify

- [ ] Features were tested on the final model and provider, with `require_parameters` where needed.
- [ ] Caching was confirmed with a MISS then HIT, and the prompt is safe to replay verbatim.
