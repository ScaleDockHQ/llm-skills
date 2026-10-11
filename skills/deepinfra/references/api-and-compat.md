# DeepInfra API and compatibility

> Verified against DeepInfra docs (Quickstart, Anthropic SDK and Claude Code integration, Batch API introduction, API reference tags), 2026-10-11

## Base URLs

| Protocol          | Base URL                              | Endpoints                                                                 |
| ----------------- | ------------------------------------- | ------------------------------------------------------------------------- |
| OpenAI-compatible | `https://api.deepinfra.com/v1/openai` | chat completions, completions, embeddings, images, audio, files, batches  |
| Anthropic         | `https://api.deepinfra.com/anthropic` | `POST /anthropic/v1/messages`, `POST /anthropic/v1/messages/count_tokens` |
| Native DeepInfra  | `https://api.deepinfra.com`           | model inference, `/deploy/*`, `/v1/containers`, `/v1/api-tokens`, billing |

Auth: `Authorization: Bearer $DEEPINFRA_API_KEY`; the Anthropic endpoint also accepts `x-api-key`. The full OpenAPI spec is at `https://api.deepinfra.com/openapi.json`.

## First call

```bash
curl -sS https://api.deepinfra.com/v1/openai/chat/completions \
  -H "Content-Type: application/json" -H "Authorization: Bearer $DEEPINFRA_API_KEY" \
  -d '{"model":"<slug from /v1/openai/models>","messages":[{"role":"user","content":"Hello!"}],"max_tokens":64}' \
  | jq '.choices[0].message.content, .usage'
```

The response `usage` includes `estimated_cost` (USD). Log it.

```python
import os
from openai import OpenAI
client = OpenAI(api_key=os.environ["DEEPINFRA_API_KEY"], base_url="https://api.deepinfra.com/v1/openai")
```

Model names are DeepInfra slugs (`org/model`), not OpenAI names.

## Anthropic Messages

```python
import os, anthropic
client = anthropic.Anthropic(base_url="https://api.deepinfra.com/anthropic", api_key=os.environ["DEEPINFRA_API_KEY"])
```

You run open models over the Anthropic protocol, not Claude. Standard messages, streaming and token counting work; other Anthropic-only features may not. `anthropic-version` and `anthropic-beta` headers can be passed.

## Batch API

OpenAI-compatible files plus batches at the OpenAI base URL, 20% below real-time pricing, results within 24 hours. Endpoints supported inside a batch: `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`. Not supported: images, moderations, responses, videos. Rules: unique `custom_id`, `method` POST, one endpoint and one model per file, DeepInfra model slugs. Limits as documented: 50,000 requests per file, 200 MB, 100 concurrent batches per user. Batch usage does not count against real-time limits.

```bash
curl -sS https://api.deepinfra.com/v1/openai/files -H "Authorization: Bearer $DEEPINFRA_API_KEY" -F purpose=batch -F file=@requests.jsonl | jq -r .id
curl -sS -X POST https://api.deepinfra.com/v1/openai/batches/BATCH_ID/cancel -H "Authorization: Bearer $DEEPINFRA_API_KEY"
```

Create batches with `completion_window: "24h"` and optionally `output_expires_after` (seconds from `created_at`) to bound how long output is kept. Terminal states: `completed`, `failed`, `expired`, `cancelled`.

## Other API groups (OpenAPI tags)

Text completions, embeddings, image generation, audio (OpenAI-style speech, transcription, translation), text to speech (ElevenLabs-compatible), reranker, LoRA adapters, agents, sandboxes, logs and metrics. Each has a page under `https://docs.deepinfra.com/apis/` or `api-reference/`.

## Official links

- Quickstart: https://docs.deepinfra.com/quickstart.md
- Anthropic and Claude Code: https://docs.deepinfra.com/integrations/anthropic.md
- Batch: https://docs.deepinfra.com/batch/introduction.md
