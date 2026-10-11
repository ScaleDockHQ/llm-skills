# Groq API and features

> Verified against GroqDocs: OpenAI Compatibility, Responses API, Service Tiers, Flex Processing, Tool Use overview, Structured Outputs, Reasoning, Prompt Caching, Errors, API Reference, 2026-10-11

Base URL: `https://api.groq.com/openai/v1`. Auth: `Authorization: Bearer $GROQ_API_KEY`. List models with `GET /openai/v1/models` and check each model page at https://console.groq.com/docs/models: model IDs, context limits and feature support change often.

## Minimal calls

```bash
curl -s https://api.groq.com/openai/v1/chat/completions \
  -H "Authorization: Bearer $GROQ_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"<MODEL_ID_FROM_/models>","messages":[{"role":"user","content":"ping"}],"max_completion_tokens":16}' | jq -r '.choices[0].message.content'
```

```python
import os, openai
client = openai.OpenAI(base_url="https://api.groq.com/openai/v1", api_key=os.environ["GROQ_API_KEY"])
```

Endpoints in the API reference: chat completions, Responses, audio transcriptions, translations and speech, models, batches, files, fine_tunings.

## OpenAI compatibility gaps

Supplying these returns a 400: `logprobs`, `logit_bias`, `top_logprobs`, `messages[].name`; `n` must be 1. `temperature: 0` is converted to `1e-8`. Some audio response formats (`vtt`, `srt`) are not supported. The Responses API is supported but `previous_response_id` and `truncation` are listed as unsupported, so keep conversation state client-side. Built-in tools in the Responses API (`code_interpreter`, `browser_search`) work only on the models in the docs table.

## Service tiers

Set `service_tier` on a request:

| Tier          | Meaning                                                                                                                                                           |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `on_demand`   | Default. Standard speed, occasional queue latency in peaks                                                                                                        |
| `flex`        | Paid plans only, higher rate limits (documented as 10x at time of reading), same price as on-demand; returns 498 `capacity_exceeded` quickly when out of capacity |
| `auto`        | Uses the best tier available to you at the moment                                                                                                                 |
| `performance` | Enterprise customers                                                                                                                                              |

Add jittered backoff to flex calls and fall back to `on_demand`. Batch has its own window and rejects `service_tier`.

## Tools

Three patterns: Groq built-in tools (server-side), remote MCP tools executed server-side, and local function tools you execute. Per-model support for local and remote tools, parallel tool use, JSON mode and built-in tools is a table at https://console.groq.com/docs/tool-use; check it before choosing a model. An MCP authentication failure returns 424.

## Structured outputs

`response_format: {"type":"json_schema","json_schema":{"name":...,"strict":true,"schema":{...}}}`. Two modes: `strict: true` uses constrained decoding (a short list of models at time of reading, including the gpt-oss models) and `strict: false` (default) is best effort on a few more models. Other models offer JSON Object Mode (`{"type":"json_object"}`) for valid JSON without schema guarantees. Always validate output and handle `finish_reason: "length"`.

## Reasoning

`reasoning_format` controls how reasoning is returned (`include_reasoning` is an alternative and the two are mutually exclusive). `reasoning_effort` is supported on some models only (gpt-oss: low, medium, high; one Qwen model also accepts `none` and `default`). Verify the accepted values on the model page.

## Prompt caching

Automatic on supported models (gpt-oss family at time of reading), no code change and no fee. Matching prefixes are reused, cached input tokens get a discount and do not count toward rate limits, entries expire after 2 hours unused, and hits are not guaranteed. The discount does not stack with the Batch discount. Put stable content (system prompt, tools) first.

## Errors to handle

429 (check `retry-after`), 498 flex capacity, 400 for unsupported params or spend-limit block, 403 for model permissions, 413 body too large, 424 MCP failure, 5xx are not billed. See `troubleshooting.md`.

## Sources

- https://console.groq.com/docs/openai
- https://console.groq.com/docs/responses-api
- https://console.groq.com/docs/service-tiers
- https://console.groq.com/docs/flex-processing
- https://console.groq.com/docs/tool-use
- https://console.groq.com/docs/structured-outputs
- https://console.groq.com/docs/reasoning
- https://console.groq.com/docs/prompt-caching
- https://console.groq.com/docs/errors
- https://console.groq.com/docs/api-reference
