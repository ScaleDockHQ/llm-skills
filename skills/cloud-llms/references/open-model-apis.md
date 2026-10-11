# Managed open-model APIs

> Verified against provider docs: Together AI OpenAI compatibility, Fireworks AI OpenAI compatibility, Groq OpenAI compatibility, DeepInfra OpenAI API, OpenRouter quickstart, Hugging Face Inference Providers docs; LiteLLM v1.105.0 provider docs, 2026-10-11

Providers that host open-weight models behind per-token APIs, usually OpenAI-compatible. Choose this tier for open models without running GPUs, for validating a model before self-hosting it, or as overflow capacity for a self-hosted model.

Depth: install the provider skill (`npx skills add ScaleDockHQ/llms-skills --skill <skill>`): `together-ai`, `fireworks-ai`, `groq`, `cerebras`, `sambanova`, `deepinfra` and `hugging-face`. OpenRouter has no skill yet; use the table and links below.

## How it plugs into this stack

| Provider                         | OpenAI-compatible base URL              | Key env var (LiteLLM convention) | LiteLLM prefix  | Skill          |
| -------------------------------- | --------------------------------------- | -------------------------------- | --------------- | -------------- |
| Together AI                      | `https://api.together.ai/v1`            | `TOGETHERAI_API_KEY`             | `together_ai/`  | `together-ai`  |
| Fireworks AI                     | `https://api.fireworks.ai/inference/v1` | `FIREWORKS_AI_API_KEY`           | `fireworks_ai/` | `fireworks-ai` |
| Groq                             | `https://api.groq.com/openai/v1`        | `GROQ_API_KEY`                   | `groq/`         | `groq`         |
| DeepInfra                        | `https://api.deepinfra.com/v1/openai`   | `DEEPINFRA_API_KEY`              | `deepinfra/`    | `deepinfra`    |
| OpenRouter                       | `https://openrouter.ai/api/v1`          | `OPENROUTER_API_KEY`             | `openrouter/`   | none yet       |
| Hugging Face Inference Providers | `https://router.huggingface.co/v1`      | `HF_TOKEN`                       | `huggingface/`  | `hugging-face` |

Cerebras and SambaNova follow the same pattern: see the `cerebras` and `sambanova` skills for their verified base URLs and LiteLLM prefixes.

- Use LiteLLM's native provider prefix when available, or the generic `openai/` prefix with `api_base` set to the base URL above.
- Put the same open model you run locally under the same alias as a second deployment or a fallback. See `assets/litellm-hybrid.yaml`.
- Model IDs are provider-specific. List them from `/models` rather than guessing.
- OpenRouter and Hugging Face are routers: the upstream's data terms and performance apply to each request. Pin the upstream where it matters.
- Quantization and context length can differ from your self-hosted copy. Run the eval against the exact provider and model ID.

## Official links

- LiteLLM providers: https://docs.litellm.ai/docs/providers
- OpenRouter quickstart: https://openrouter.ai/docs/quickstart
- OpenRouter data collection: https://openrouter.ai/docs/guides/privacy/data-collection
