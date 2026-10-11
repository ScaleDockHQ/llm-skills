# Cloud models behind the same gateway as local models

> Verified against LiteLLM v1.105.0 docs (proxy configs, config settings, Fallbacks / reliability, provider budget routing, budgets and rate limits, health checks, provider pages for OpenAI, Anthropic, Gemini, Bedrock, Vertex AI, Azure OpenAI, Together AI, Fireworks AI, Groq, DeepInfra, OpenRouter, Hugging Face, hosted vLLM), 2026-10-11

## What it is and when to choose it

A single LiteLLM proxy that serves local models and cloud models under stable aliases, with fallbacks and budgets. This file covers only the cloud-specific entries and hybrid wiring. Everything general about the gateway (virtual keys, teams, routing strategies, API bridging, guardrails, UI) is owned by `llm-gateway`; the self-hosted side (llama-swap, engines, DGX Spark) by `self-hosted-llms`.

## Install / setup

Use the gateway that already exists (discovery step in `SKILL.md`). If none exists, install LiteLLM per `llm-gateway` or `self-hosted-llms`, then start from `templates/litellm-hybrid.yaml`.

## Minimal working config

One entry per provider, using LiteLLM's provider prefixes:

| Provider | `model:` prefix | Credentials in `litellm_params` |
| --- | --- | --- |
| Local vLLM / any OpenAI-compatible server | `hosted_vllm/` (or `openai/` + `api_base`) | `api_base`, `api_key: os.environ/...` |
| OpenAI | `openai/` | `api_key: os.environ/OPENAI_API_KEY` |
| Anthropic | `anthropic/` | `api_key: os.environ/ANTHROPIC_API_KEY` |
| Gemini API | `gemini/` | `api_key: os.environ/GEMINI_API_KEY` |
| AWS Bedrock | `bedrock/` | `aws_region_name`; credentials from the AWS chain, or `aws_profile_name` / `aws_role_name` |
| Agent Platform (Vertex AI) | `vertex_ai/` | `vertex_project`, `vertex_location`; Application Default Credentials |
| Azure OpenAI (Foundry) | `azure/<deployment>` | `api_base`, `api_version`, `api_key` or Entra ID |
| Together AI | `together_ai/` | `TOGETHERAI_API_KEY` |
| Fireworks AI | `fireworks_ai/` | `FIREWORKS_AI_API_KEY` |
| Groq | `groq/` | `GROQ_API_KEY` |
| DeepInfra | `deepinfra/` | `DEEPINFRA_API_KEY` |
| OpenRouter | `openrouter/` | `OPENROUTER_API_KEY` |
| Hugging Face Inference Providers | `huggingface/` | `HF_TOKEN` |

`os.environ/NAME` tells LiteLLM to read the value from the environment at startup, so the file itself contains no secrets.

Fallbacks and budgets (excerpt; full file in the template):

```yaml
router_settings:
  fallbacks:
    - chat: ["chat-overflow", "frontier-chat"]
  context_window_fallbacks:
    - chat: ["frontier-long-context"]
  num_retries: 2
  provider_budget_config:
    openai:
      budget_limit: 200     # USD
      time_period: 1mo
litellm_settings:
  allowed_fails: 3
  cooldown_time: 30
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
```

## How it plugs into the stack

- Endpoint: one base URL for every client, for example `https://llm.example.com/v1`, plus the Anthropic-style `/v1/messages` route for tools that need it.
- Health: `GET /health/liveliness` (process up; `/health/liveness` is an alias) and `GET /health/readiness` (ready; reports database status). Both are unauthenticated and low-detail by default.
- Auth: clients use LiteLLM virtual keys or the master key; provider keys stay in the gateway's environment.
- API coverage: OpenAI Chat Completions, Responses and Embeddings, and Anthropic Messages, translated to each provider (details in `llm-gateway`).

## Operating

- **Fallback design.** Order fallbacks from closest behavior to furthest: same open model elsewhere, then a different model. Never add a cloud fallback to an alias that carries data restricted to your own hardware; give that data its own alias with no fallbacks (`private` in the template) and a key that can only reach it.
- **Timeouts.** A short `stream_timeout` on the local deployment lets a stuck local box fail over quickly. Serverless backends need timeouts longer than their cold start, or a quick fallback.
- **Budgets.** Three layers: provider (`provider_budget_config`, USD per period), deployment (`max_budget` + `budget_duration` in `litellm_params`), and keys/teams/global (`litellm_settings.max_budget`, virtual keys). Key, team and global budgets are read from the database: with no database they do not cap anything. Provider and deployment spend is shared across instances only through Redis.
- **Cloud budgets too.** Gateway budgets track estimated spend; the cloud and provider consoles are the billing truth. Set both (`cost-and-quotas.md`).
- **Testing fallbacks.** The proxy ignores mock-fallback flags on requests; trigger a real error in a non-production environment (for example, point a test deployment at a closed port).

## Tuning knobs worth knowing

- `num_retries`, `allowed_fails`, `cooldown_time`: how fast a failing deployment is skipped.
- `timeout` / `stream_timeout` per deployment.
- `rpm` / `tpm` per deployment to stay under provider rate limits.
- `routing_strategy` for several deployments in one group (`simple-shuffle` default; latency-based and usage-based options exist).

## Known pitfalls

- Same alias for two deployments in different trust zones: load balancing will send restricted data to the cloud. Use fallbacks, not shared groups, across trust zones.
- Budgets configured but no database: they silently do not enforce.
- Provider model IDs without a date or version in production aliases.
- Gateway in a different region from the hyperscaler endpoint: extra latency, extra egress, a second data path.

## Official links

- LiteLLM proxy config: https://docs.litellm.ai/docs/proxy/configs
- LiteLLM config settings: https://docs.litellm.ai/docs/proxy/config_settings
- LiteLLM fallbacks: https://docs.litellm.ai/docs/proxy/reliability
- LiteLLM provider budgets: https://docs.litellm.ai/docs/proxy/provider_budget_routing
- LiteLLM budgets and rate limits: https://docs.litellm.ai/docs/proxy/users
- LiteLLM health checks: https://docs.litellm.ai/docs/proxy/health
- LiteLLM providers: https://docs.litellm.ai/docs/providers
