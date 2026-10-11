# Managed open-model APIs

> Verified against provider docs: Together AI OpenAI compatibility, Fireworks AI OpenAI compatibility and data handling, Groq OpenAI compatibility and "Your data", DeepInfra OpenAI API and data privacy, OpenRouter quickstart and data collection, Hugging Face Inference Providers docs and security page; LiteLLM v1.105.0 provider docs, 2026-10-11

## What it is and when to choose it

Providers that host open-weight models behind per-token APIs, usually OpenAI-compatible. Choose this tier for open models without running GPUs, for validating a model before self-hosting it, or as overflow capacity for a self-hosted model. Because the weights are open, moving to your own GPUs later keeps model behavior close (same model, possibly different quantization).

## Setup

Base URLs below were checked in each provider's documentation on 2026-10-11.

| Provider                         | OpenAI-compatible base URL              | Key env var (LiteLLM convention) | LiteLLM prefix  |
| -------------------------------- | --------------------------------------- | -------------------------------- | --------------- |
| Together AI                      | `https://api.together.ai/v1`            | `TOGETHERAI_API_KEY`             | `together_ai/`  |
| Fireworks AI                     | `https://api.fireworks.ai/inference/v1` | `FIREWORKS_AI_API_KEY`           | `fireworks_ai/` |
| Groq                             | `https://api.groq.com/openai/v1`        | `GROQ_API_KEY`                   | `groq/`         |
| DeepInfra                        | `https://api.deepinfra.com/v1/openai`   | `DEEPINFRA_API_KEY`              | `deepinfra/`    |
| OpenRouter                       | `https://openrouter.ai/api/v1`          | `OPENROUTER_API_KEY`             | `openrouter/`   |
| Hugging Face Inference Providers | `https://router.huggingface.co/v1`      | `HF_TOKEN`                       | `huggingface/`  |

Notes:

- Together AI's documented base URL is `api.together.ai`; older examples may show a different domain.
- OpenRouter and Hugging Face Inference Providers are **routers**: one key reaches many upstream providers. The upstream's data terms and performance apply to each request.
- Model IDs are provider-specific (for example `org/model-name`, or `accounts/fireworks/models/...` on Fireworks). List them from `/models` rather than guessing.

Minimal check (key read from the environment, never echoed):

```bash
BASE=https://api.together.ai/v1   # any base URL from the table
curl -s "$BASE/models" -H "Authorization: Bearer $TOGETHERAI_API_KEY" | jq -r '.. | .id? // empty' | head
```

## How it plugs into the stack

- Use LiteLLM's native provider prefix when available (it handles provider quirks), or the generic `openai/` prefix with `api_base` set to the base URL above.
- Put the same open model you run locally under the same alias as a second deployment or a fallback. See `assets/litellm-hybrid.yaml`.
- API coverage: all six expose Chat Completions; Groq also documents Responses, batches and files under its OpenAI path. Check each provider's docs for embeddings, tool calling and structured output per model.

## Operating

- Rate limits are per account and often per model; check the provider console. Groq publishes its limits at https://console.groq.com/docs/rate-limits.
- Model catalogs change; models are retired. Keep a fallback alias and watch provider changelogs.
- Quantization and context length can differ from the reference model, so quality can differ from your self-hosted copy. Run the eval against the exact provider and model ID.

**Data handling (as stated by each provider on 2026-10-11)**

- Fireworks: does not log or store prompt or generation data for open models without explicit opt-in; enterprise Zero Data Retention policy available; its Responses API stores conversation data when `store=true` (the default).
- Groq: retains customer data only when a feature needs it (for example batch input/output files for 30 days, fine-tuning artifacts until deleted), plus cases described on its page.
- DeepInfra: inference inputs are not stored to disk; held in memory during processing only.
- OpenRouter: does not store prompts or responses unless you opt in to logging; documents which upstream providers may capture data for training and offers ZDR controls.
- Hugging Face Inference Providers: Hugging Face does not store request bodies or responses when routing; logs kept up to 30 days without user data; the upstream provider's policy also applies.
- Together AI: see its privacy policy.

## Tuning knobs worth knowing

- Pin the upstream on routers, which stabilizes latency and data terms. OpenRouter: the request's `provider` object (`order`, `allow_fallbacks`, `data_collection: "deny"`). Hugging Face: append a policy or provider to the model ID (`:fastest` is the default, `:cheapest`, `:preferred`, or a provider name such as `:groq`).
- `max_tokens` to bound cost; streaming for interactive use.
- Dedicated deployments (several of these providers offer reserved capacity) change the cost shape to per-hour; treat them like a GPU VM in the cost model.

## Known pitfalls

- Treating a router as a single provider for compliance purposes.
- Different tokenizers and chat templates across providers for the "same" model.
- Assuming tool calling works the same as on your self-hosted engine; test with your real tool schemas.
- Free tiers or promotional models with different data terms.

## Official links

- Together AI OpenAI compatibility: https://docs.together.ai/docs/openai-api-compatibility
- Together AI privacy: https://www.together.ai/privacy
- Fireworks AI OpenAI compatibility: https://docs.fireworks.ai/tools-sdks/openai-compatibility
- Fireworks AI data handling: https://docs.fireworks.ai/guides/security_compliance/data_handling
- Groq OpenAI compatibility: https://console.groq.com/docs/openai
- Groq data: https://console.groq.com/docs/your-data
- DeepInfra OpenAI API: https://deepinfra.com/docs/openai_api
- DeepInfra data privacy: https://docs.deepinfra.com/account/data-privacy
- OpenRouter quickstart: https://openrouter.ai/docs/quickstart
- OpenRouter data collection: https://openrouter.ai/docs/guides/privacy/data-collection
- Hugging Face Inference Providers: https://huggingface.co/docs/inference-providers/index
- Hugging Face Inference Providers security: https://huggingface.co/docs/inference-providers/security
- LiteLLM providers: https://docs.litellm.ai/docs/providers
