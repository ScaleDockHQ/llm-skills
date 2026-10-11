# Gemini API: endpoints, SDKs and OpenAI compatibility

> Verified against Gemini API docs: Generating content, Interactions API key page, OpenAI compatibility, Caching, 2026-10-11

Base URL: `https://generativelanguage.googleapis.com/v1beta/`. Model IDs below are placeholders; list models first and pin one (`GEMINI_MODEL`).

## List models

```bash
curl -sS "https://generativelanguage.googleapis.com/v1beta/models" -H "x-goog-api-key: $GEMINI_API_KEY" \
  | jq -r '.models[] | [.name, (.supportedGenerationMethods // [] | join(","))] | @tsv'
# OpenAI-compatible listing
curl -sS "https://generativelanguage.googleapis.com/v1beta/openai/models" -H "Authorization: Bearer $GEMINI_API_KEY" | jq -r '.data[].id'
```

(The `supportedGenerationMethods` field name is from the REST model resource; unverified on this run, adjust the filter if absent.)

## generateContent (native, long-standing)

```bash
curl -sS "https://generativelanguage.googleapis.com/v1beta/models/$GEMINI_MODEL:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"Explain how AI works in a few words"}]}]}' | jq -r '.candidates[0].content.parts[0].text'
```

- Streaming: `models/<id>:streamGenerateContent?alt=sse` (server-sent events).
- Response includes `usageMetadata` and `promptFeedback`; check `finishReason` and the candidate's safety fields when output is empty.
- Batch uses `models/<id>:batchGenerateContent` (`references/features.md`).

## Interactions API (newer)

`POST /v1beta/interactions` with `{"model": "...", "input": "..."}`; SDKs expose `client.interactions.create(...)` and `interaction.output_text`. Stateful conversations use `previous_interaction_id`. Documented gaps: only **implicit** caching (explicit `cachedContents` needs `generateContent`), and the Batch API note says it currently works with `generateContent` only. Check the docs page for current feature parity before choosing it.

```bash
curl -sS "https://generativelanguage.googleapis.com/v1beta/interactions" \
  -H "x-goog-api-key: $GEMINI_API_KEY" -H "Content-Type: application/json" \
  -d "$(jq -n --arg m "$GEMINI_MODEL" '{model:$m,input:"Explain how AI works in a few words"}')"
```

## SDKs

`google-genai` (Python: `from google import genai; client = genai.Client()`), `@google/genai` (Node), `google.golang.org/genai` (Go), Java `com.google.genai`. The client reads `GEMINI_API_KEY` or `GOOGLE_API_KEY`.

## OpenAI compatibility (Chat Completions style)

Base URL `https://generativelanguage.googleapis.com/v1beta/openai/`, key as bearer token, Gemini model ID.

```python
from openai import OpenAI
import os
client = OpenAI(api_key=os.environ["GEMINI_API_KEY"], base_url="https://generativelanguage.googleapis.com/v1beta/openai/")
r = client.chat.completions.create(model=os.environ["GEMINI_MODEL"], reasoning_effort="low",
                                   messages=[{"role": "user", "content": "Hello"}])
```

Documented support and quirks:

- Endpoints named: chat completions (text, vision, audio input, streaming, function calling, structured output), image generation, video via a Sora-style `/v1/videos`, embeddings, models list, and Batch (create, status, results).
- Batch compatibility is partial: file upload and download go through the `genai` client, not the OpenAI SDK.
- `reasoning_effort` maps to Gemini `thinking_level` or `thinking_budget`; do not combine it with `thinking_config`. Reasoning cannot be turned off on Gemini 2.5 Pro or 3 models.
- Gemini-only features go in `extra_body` (note the nested `extra_body.google` structure), for example `cached_content` and `thinking_config`. Unknown parameters are silently ignored for image generation.
- `service_tier` accepts `priority` or `flex`; default is standard.
- The docs recommend calling Gemini directly if you are not already using the OpenAI libraries.

## Where to read more

- https://ai.google.dev/gemini-api/docs/openai
- https://ai.google.dev/api/generate-content
- https://ai.google.dev/gemini-api/docs/api-key
