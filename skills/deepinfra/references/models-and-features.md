# DeepInfra models and features

> Verified against DeepInfra docs (docs index, Models, Chat Completions, Prompt Caching, Prompt Cache Retention, Structured Outputs, Tool Calling, Reasoning, Vision pages listed in llms.txt; live GET /v1/openai/models), 2026-10-11

## Find models

```bash
curl -sS https://api.deepinfra.com/v1/openai/models | jq -r '.data[].id'                 # works without a key
curl -sS https://api.deepinfra.com/v1/openai/models | jq '.data[0]'                      # see which metadata fields exist
```

Each entry carries `metadata` (description and more). Inspect one entry before writing a `jq` filter for context length or pricing. The catalog (200+ models per the docs index, across chat, embeddings, image, audio, reranking, video) is browsable at https://deepinfra.com/models and each model page shows current per-token pricing. Do not copy prices into configs; read them from the model page or API metadata.

## Slugs and versions

- Slugs are `org/model`, often with a dated suffix (for example `...-0731`, `...-0813`). The Claude Code page says undated slugs for the same family can be older preview checkpoints that dated releases supersede.
- Pin the dated slug in gateway configs. Re-list models monthly (`llm-evals` after each swap).
- Dedicated deployments appear as `YOUR_GITHUB_USERNAME/model-name`, or via `deploy_id:<id>` as the model before the endpoint is up.

## Features and where they are documented

| Feature                | Docs page under `https://docs.deepinfra.com/`                                                   |
| ---------------------- | ----------------------------------------------------------------------------------------------- |
| Chat completions       | `chat/overview.md`                                                                              |
| Streaming              | `chat/streaming.md`                                                                             |
| Tool calling           | `chat/tool-calling.md`                                                                          |
| Structured outputs     | `chat/structured-outputs.md` (`response_format`)                                                |
| Vision and OCR         | `chat/vision.md`                                                                                |
| Reasoning models       | `chat/reasoning.md`                                                                             |
| Log probs              | `chat/log-probs.md`                                                                             |
| Prompt caching         | `chat/prompt-caching.md`                                                                        |
| Prompt cache retention | `chat/prompt-cache-retention.md` (5 minutes or 1 hour, cache-read rate)                         |
| Embeddings, reranker   | `apis/embeddings.md`, `apis/reranker.md`                                                        |
| Images, speech, video  | `apis/image-generation.md`, `apis/speech.md`, `apis/text-to-speech.md`, `apis/text-to-video.md` |
| Batch                  | `batch/introduction.md`                                                                         |

Support differs per model. Check a model's page for tools, vision, reasoning and cache support before relying on it. The Claude Code integration page says its recommended models support prompt caching, which makes cache reads substantially cheaper.

## Service tiers and fail-fast

The docs pages for these were not read in this verification pass. Unverified: service tier and `fail_fast` request options. Check the chat overview page and the OpenAPI spec (`https://api.deepinfra.com/openapi.json`) before using them.

## LoRA and custom models

Private LLM deployments, LoRA language adapters and LoRA image adapters are covered in `dedicated-and-gpu.md` and `https://docs.deepinfra.com/private-models/`.

## Official links

- Index: https://docs.deepinfra.com/llms.txt
- Model catalog: https://deepinfra.com/models
- Prompt caching: https://docs.deepinfra.com/chat/prompt-caching.md
