# OpenRouter API, models and errors

> Verified against OpenRouter API v1 (docs: api_reference/overview, parameters, errors-and-debugging, guides/overview/models, routing/model-variants/overview, responses/overview), 2026-10-11

## Endpoints

All under `https://openrouter.ai/api/v1` and authenticated with a bearer key: `POST /chat/completions` (OpenAI Chat schema, normalized across providers; `choices` is always an array, `usage` always present with the model's native tokenizer counts), `POST /responses` (Responses API), `POST /messages` (Anthropic Messages, for Claude Code and the Anthropic SDK; root URL has no `/v1`), `POST /embeddings`, `POST /rerank`, `POST /batches`, `/files`, audio (`/audio/speech`, `/audio/transcriptions`), `/videos`, `/images`, `GET /models`, `GET /key`, `GET /generation?id=`. OpenAPI spec: https://openrouter.ai/openapi.json (or `.yaml`).

## Models

`GET /api/v1/models` returns text-output models by default. Use `?output_modalities=` with `text`, `image`, `video`, `audio`, `speech`, `transcription`, `embeddings`, `rerank`, `decisions` or `all`; embedding models also have `GET /embeddings/models`. A key-filtered catalog is available at `/api/v1/models/user`, and organizations can force it with `is_filtered_model_catalog_enabled`. Per-model endpoints (provider, quantization, pricing, uptime): `GET /api/v1/models/{author}/{slug}/endpoints`. Single model lookup: `GET /api/v1/model/{author}/{slug}`.

Read pricing, context length and `supported_parameters` from these responses at use time. Do not copy them into configs or docs.

## Variants (suffixes)

| Suffix                              | Kind       | Effect                                                                                                                        |
| ----------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `:free`                             | catalog    | A separate free entry with its own limits; its context window and pricing can differ from the base model.                     |
| `:batch`                            | catalog    | Batch-priced entry used by the Batch API.                                                                                     |
| `:nitro`                            | routing    | Sort providers by throughput; admits priority service tier endpoints, billed at the priority rate.                            |
| `:floor`                            | routing    | Sort by price; admits flex service tier endpoints.                                                                            |
| `:exacto`                           | routing    | Sort by quality signals tuned for tool-calling reliability.                                                                   |
| `:thinking`, `:extended`, `:online` | deprecated | Use the `reasoning` parameter, no model offers `:extended`, and the `openrouter:web_search` server tool instead of `:online`. |

Routing variants work on any model ID; a catalog suffix on a model that has no such entry does not fall back to the base model (inference fails). Suffixes combine in any order (`model:free:nitro`); the last sort variant wins. When resolving metadata keep the catalog suffix, drop routing suffixes.

Slugs with a leading `~` such as `~anthropic/claude-sonnet-latest` are latest-resolution aliases that follow newer releases. Avoid them where reproducibility matters.

## Request parameters worth knowing

Standard sampling and tool parameters follow the OpenAI schema. OpenRouter additions: `provider` (routing object), `models` (fallback list), `plugins`, `preset`, `reasoning`, `response_format` with `json_object` or `json_schema`, assistant prefill (end `messages` with an assistant turn). Parameters a provider does not support are ignored unless `provider.require_parameters` is true.

## Errors

Error body: `{ "error": { "code": <number>, "message": "...", "metadata": {...} } }`. The HTTP status equals `error.code` when the request failed before generation; once the model started, the HTTP status is 200 and the error arrives in the body or as an SSE event, so check both.

| Code | Meaning                                                                              |
| ---- | ------------------------------------------------------------------------------------ |
| 400  | Invalid or missing params, CORS                                                      |
| 401  | Invalid or disabled key, expired OAuth session or management key                     |
| 402  | Insufficient credits, or the in-flight spending budget; read `metadata.limit_source` |
| 403  | Moderation flag, guardrail block, or a spent guardrail, workspace or key budget      |
| 408  | Request timed out                                                                    |
| 429  | Rate limited                                                                         |
| 502  | Chosen model down or invalid response                                                |
| 503  | No provider meets your routing requirements                                          |

`Retry-After` may be present on 429, 503 and some 402 responses. Honor it. For moderation errors `metadata` carries `reasons`, `flagged_input` (at most 100 characters), `provider_name`, `model_slug`; upstream codes appear in `metadata.provider_code`.
