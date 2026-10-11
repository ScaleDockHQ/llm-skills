# Cerebras models and features

> Verified against Cerebras Inference docs (Model Catalog, Deprecations, Structured Outputs, Prompt Caching, Batch, Service Tiers, Dedicated Inference overview, Reasoning and Tool Calling index entries), 2026-10-11

## Find models

Never hardcode a model list. Ask the API, then read the model page for context, capabilities and limits:

```bash
curl -sS https://api.cerebras.ai/v1/models -H "Authorization: Bearer $CEREBRAS_API_KEY" | jq -r '.data[].id'
```

Model catalog page (Shared Inference): https://inference-docs.cerebras.ai/models/overview. On 2026-10-11 it listed `gpt-oss-120b` and `qwen-3.8-27b`, with context shown as a free versus paid figure. Additional families (Qwen3, Llama, GLM, Kimi, DeepSeek, MiniMax, Mistral, Gemma and others) are Dedicated Inference only.

Compression: the docs state Shared Inference models are the original, unpruned versions, with weight-only storage quantization and full-precision activations, attention and KV cache. A changed architecture would ship as a separate model ID. Run your eval on the exact ID (`llm-evals`).

## Deprecations (read before pinning)

The deprecation page lists retired IDs with suggested replacements, newest first. On 2026-10-11 it included:

- `gemma-4-31b` left Shared Inference on 2026-09-03 (still on Dedicated).
- `zai-glm-4.7`, `llama3.1-8b`, `qwen-3-235b-a22b-instruct-2507`, `qwen-3-32b`, `llama-3.3-70b`, `zai-glm-4.6` and several Qwen and Llama 4 IDs were deprecated, most with GPT OSS 120B as the suggested replacement.
- The `disable_reasoning` parameter for `zai-glm-4.7` ended after 2026-07-21; use `reasoning_effort="none"`.

A 404 `model not found` often means a retired ID. Always re-read https://inference-docs.cerebras.ai/support/deprecation when a config is older than a few months.

## Reasoning

- OpenAI-standard `reasoning_effort`; Cerebras-specific `reasoning_format` and `clear_thinking` go through `extra_body` on OpenAI clients.
- `qwen-3.8-27b`: `reasoning_effort` of `none`, `low`, `medium` or `high` (default `high`), reasoning returned separately, `hidden` format unsupported.
- Other models differ; read https://inference-docs.cerebras.ai/capabilities/reasoning before changing defaults.

## Structured outputs

`response_format` with `json_schema` and `strict: true` uses constrained decoding. Strict-mode rules that cause 400s:

- Root must be an object with `properties`; every object needs `"additionalProperties": false`; arrays need `items`.
- Not supported in strict mode: recursive schemas, external `$ref`, `oneOf`, `allOf`, `not`, string `pattern` and `format`, `minItems` and `maxItems`.
- Limits include nesting depth and total counted schema text (see the page for the numbers).
- Do not combine `tools` and `response_format` unless the model's page says so. `gpt-oss-120b` rejects it.

## Tool calling

Standard OpenAI `tools` / `tool_choice`. Put structure in the tool's `parameters` schema when you also want structured data. Strict tool schemas for `qwen-3.8-27b` do not support `minLength` or `maxLength`.

## Prompt caching

Automatic, no parameters. Prefix matching in 128-token blocks, ephemeral, TTL guaranteed for 5 minutes and possibly up to 1 hour under light load. One changed early character misses every later block. Cached tokens do not count against the uncached token limit, so keep system prompts and tool definitions first and stable. Check the Cached-Usage tab in Analytics.

## Batch (private preview)

Asynchronous JSONL jobs over `/v1/chat/completions`, 24 hour window, via Files and Batches endpoints; contact Cerebras for access. SDK support was not available in preview (use cURL). Constraints documented: at least 10 and at most 50,000 requests per file, 200 MB file, one model per file, results retained for 7 days. Expired requests are not charged.

```bash
curl -sS https://api.cerebras.ai/v1/files -H "Authorization: Bearer $CEREBRAS_API_KEY" \
  -F purpose=batch -F file=@requests.jsonl | jq -r .id
```

Cancel with `DELETE /v1/batches/<batch-id>`; delete files with the Files API (`teardown.md`).

## Service tiers (private preview, Dedicated only)

`service_tier`: `priority`, `default`, `auto`, `flex`. Not available with Shared Inference. Optional `queue_threshold` header (50 to 20000 ms) for flex or auto.

## Dedicated Inference

Reserved capacity behind a stable endpoint ID. Resource model: model architecture, model version (immutable weights), deployment (running version plus capacity and replicas), endpoint (stable ID), replica. Features: custom or fine-tuned weights, Management API, Batch, predicted outputs, service tiers, Prometheus metrics. Available to enterprise customers; contact Cerebras. In requests, `model` is the endpoint ID. Pricing is by quote.

## Official links

- Model catalog: https://inference-docs.cerebras.ai/models/overview
- Deprecations: https://inference-docs.cerebras.ai/support/deprecation
- Structured outputs: https://inference-docs.cerebras.ai/capabilities/structured-outputs
- Prompt caching: https://inference-docs.cerebras.ai/capabilities/prompt-caching
- Batch: https://inference-docs.cerebras.ai/capabilities/batch
- Dedicated: https://inference-docs.cerebras.ai/dedicated/overview
