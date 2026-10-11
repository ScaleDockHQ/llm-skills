# Nebius Token Factory: inference API

> Verified against Nebius Token Factory docs (Introduction, Switch to Token Factory, Function calling, Structured output, Create embeddings, Upload file, Supervised fine-tuning, Batch, Rate limits), 2026-10-11

Token Factory (formerly AI Studio) is OpenAI-compatible: change `base_url` and the key.

| Item      | Value                                                                                                                                 |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Base URL  | `https://api.tokenfactory.nebius.com/v1/` (dedicated endpoints in some regions may use a regional host, see `dedicated-endpoints.md`) |
| Auth      | `Authorization: Bearer $NEBIUS_API_KEY`                                                                                               |
| Model ids | Hugging Face style, for example `moonshotai/Kimi-K2.5`; always take them from `/v1/models`                                            |

## Discover models

```bash
curl -sS "https://api.tokenfactory.nebius.com/v1/models?verbose=true" \
  -H "Authorization: Bearer $NEBIUS_API_KEY" | jq -r '.data[].id'
```

`GET /v1/models` accepts `ai_project_id` and `verbose` query parameters. Model availability changes; do not hardcode lists. Model cards in the console show tags such as `JSON mode`.

## Chat completions

```bash
curl -sS https://api.tokenfactory.nebius.com/v1/chat/completions \
  -H "Authorization: Bearer $NEBIUS_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Hello"}],"temperature":0.6}' | jq .
```

## Tools and structured output

- Function calling: standard `tools` (JSON Schema) and `tool_choice` (`auto` or an explicit function). The model returns `tool_calls`; you execute them.
- Structured output: `response_format` with `{"type":"json_schema", ...}` for schema-following, or `{"type":"json_object"}` for arbitrary JSON. Prefer the schema form. Support varies by model (look for the JSON mode tag).

## Embeddings

`POST /v1/embeddings` with `model`, `input`, optional `encoding_format` (`float` or `base64`) and `dimensions`.

## Batch

`/v1/batches` with `completion_window` `24h`; upload the JSONL with `purpose=batch` via `POST /v1/files` first. Check the batch docs for the request-line format: https://docs.tokenfactory.nebius.com/ai-models-inference/batch-inference (unverified path, find via https://docs.tokenfactory.nebius.com/llms.txt).

## Files and fine-tuning

- `POST /v1/files` multipart with `file` and `purpose` (`batch`, `fine-tune`, `history`).
- `POST /v1/fine_tuning/jobs` with `model`, `training_file`, optional `validation_file`, `suffix`, `hyperparameters` (batch size, learning rate, epochs, LoRA settings, context length) and `integrations` (W&B, Hugging Face push). Fine-tuning bills; ask first. Data design and evaluation belong to `fine-tuning-llms` and `llm-evals`.

## Rate limits

Dynamic per-project limits. A 429 means slow down; read the `x-ratelimit-*` response headers and back off with jitter. See `limits-and-billing.md`. The embeddings request accepts a `service_tier` (`auto`, `default`, `over-limit`, `flex`, `no-limit`); semantics are in the API reference, unverified here.

## Sources

- https://docs.tokenfactory.nebius.com/api-reference/introduction
- https://docs.tokenfactory.nebius.com/ai-models-inference/function-calling
- https://docs.tokenfactory.nebius.com/ai-models-inference/json
- https://docs.tokenfactory.nebius.com/api-reference/inference/create-embeddings
- https://docs.tokenfactory.nebius.com/api-reference/files/upload-file
- https://docs.tokenfactory.nebius.com/post-training/how-to-fine-tune
