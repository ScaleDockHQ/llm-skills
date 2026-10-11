# Frontier APIs: OpenAI, Anthropic, Google Gemini

> Verified against OpenAI API docs (rate limits, Batch, prompt caching, data controls), Anthropic Claude Platform docs (OpenAI SDK compatibility, rate limits, Message Batches, prompt caching, API and data retention, data residency), Gemini API docs (OpenAI compatibility, batch mode, caching, rate limits, Additional Terms), 2026-10-11

## What it is and when to choose it

Closed models consumed through the vendor's own API. Choose this tier when only a frontier model passes your eval, volume is low to moderate, and the data class allows it. Consider the same models through a hyperscaler (`hyperscalers.md`) when you need your cloud contract, IAM, private networking or residency.

## Setup

| Provider          | Native API                                                | OpenAI-compatible base URL                                 | Key env var (convention) | Console                      |
| ----------------- | --------------------------------------------------------- | ---------------------------------------------------------- | ------------------------ | ---------------------------- |
| OpenAI            | `https://api.openai.com/v1` (Chat Completions, Responses) | same                                                       | `OPENAI_API_KEY`         | https://platform.openai.com/ |
| Anthropic         | `https://api.anthropic.com/v1/messages` (Messages)        | `https://api.anthropic.com/v1/`                            | `ANTHROPIC_API_KEY`      | https://platform.claude.com/ |
| Google Gemini API | `generateContent` on `generativelanguage.googleapis.com`  | `https://generativelanguage.googleapis.com/v1beta/openai/` | `GEMINI_API_KEY`         | https://aistudio.google.com/ |

Keys:

- Create one key per project or environment, never one shared org-wide key. OpenAI supports projects; Anthropic supports workspaces; Gemini keys belong to a Google Cloud project.
- Store keys in a secret manager and inject them into the gateway only (`security-compliance.md`). Clients get gateway keys.
- The vendors' OpenAI-compatibility layers are convenient for testing, but native APIs expose features first (for example Anthropic's `cache_control`, Gemini's explicit caching). The gateway can call native APIs and still present an OpenAI-compatible endpoint (`gateway-hybrid.md`).

Minimal checks (key read from the environment, never echoed):

```bash
curl -s https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY" | jq -r '.data[].id' | head
curl -s https://api.anthropic.com/v1/models -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" | jq -r '.data[].id' | head
curl -s "https://generativelanguage.googleapis.com/v1beta/openai/models" -H "Authorization: Bearer $GEMINI_API_KEY" | jq -r '.data[].id' | head
```

## How it plugs into the stack

- Add each provider as a deployment in LiteLLM using the native provider prefix (`openai/`, `anthropic/`, `gemini/`), with `api_key: os.environ/...`. See `assets/litellm-hybrid.yaml`.
- Clients call aliases on the gateway. Coding agents that speak the Anthropic Messages API can use the gateway's `/v1/messages` route (details in `llm-gateway`).
- Health: there is no public health endpoint you should poll; use the gateway's health checks and the vendors' status pages.

## Operating

**Rate limits and tiers**

- OpenAI: limits are measured in RPM, RPD, TPM, TPD (and others for images/audio). Some model families share a limit. Paid usage tiers are Build, Launch and Grow, and an organization moves up automatically as credit purchases reach thresholds. See the organization limits page in the console.
- Anthropic: an organization has **spend limits** (maximum monthly cost) and **rate limits** by usage tier; new organizations may start in an Evaluation tier with lower limits. Tier and current limits are on the console Rate limits page.
- Gemini API: limits depend on the model and the project's tier; see the rate limits page.
- All three return HTTP 429 when limited. Configure retries with backoff and a fallback in the gateway; do not retry in a tight loop.

**Batch APIs** (non-interactive work):

- OpenAI Batch: upload a JSONL file, create a batch with `completion_window: "24h"` (the only value today). Discounted versus synchronous calls and a separate, higher rate-limit pool.
- Anthropic Message Batches: up to 100,000 requests or 256 MB per batch, most finish within an hour, results available for 29 days. Discounted versus synchronous.
- Gemini batch mode: 24-hour target turnaround, priced below interactive calls.

Check the current discount on each pricing page; do not hardcode it.

**Prompt caching**

- OpenAI: enabled by default for supported models; reused prefixes are billed at a cached-input rate. Lifetime depends on the model; `prompt_cache_retention` selects extended retention where supported. Keep static content (system prompt, tools, documents) at the start of the prompt.
- Anthropic: add `cache_control` either once at the top level (automatic caching) or on specific content blocks (explicit breakpoints), with 5-minute or 1-hour TTLs.
- Gemini: implicit caching is on by default for Gemini 2.5 and newer models; explicit caches can be created through the `generateContent` API.

**Data retention** (summarize in the decision record; re-read before signing off)

- OpenAI: API data is not used for training unless you opt in. Abuse-monitoring logs may include content and are kept up to 30 days by default. Zero Data Retention and Modified Abuse Monitoring require approval. Data residency is a project option via sales.
- Anthropic: zero data retention (ZDR) and HIPAA-readiness arrangements exist, with per-feature eligibility; retained data is not used for training without permission. `inference_geo` on a request (or a workspace default) controls where inference runs.
- Gemini API: on unpaid use, content may be used to improve Google products and read by human reviewers. Use a Cloud project with billing (paid) for anything not public, or use the hyperscaler route.

## Tuning knobs worth knowing

- Pin dated or versioned model IDs; aliases without a date can change underneath you.
- `max_tokens` / `max_output_tokens`: cap output to bound cost and latency.
- Reasoning effort or thinking budget settings on reasoning models: trade quality for cost and latency.
- Streaming: always stream for interactive use; measure time to first token.
- Service tiers or priority options where offered: check the pricing page before enabling.

## Known pitfalls

- Using a free or unpaid tier for internal data (Gemini unpaid terms allow training use and human review).
- One key for everything: a leak or rate-limit exhaustion takes down every app.
- Retrying 429s without backoff, which extends the throttle.
- Assuming the OpenAI-compatible layer supports every native feature. For example, Anthropic's OpenAI compatibility layer ignores `strict` on function definitions and does not support prompt caching; use the native Messages API (LiteLLM's `anthropic/` prefix does) when you need those.
- Model deprecations: subscribe to deprecation notices and keep a tested fallback alias.

## Official links

- OpenAI rate limits: https://developers.openai.com/api/docs/guides/rate-limits
- OpenAI Batch: https://developers.openai.com/api/docs/guides/batch
- OpenAI prompt caching: https://developers.openai.com/api/docs/guides/prompt-caching
- OpenAI data controls: https://developers.openai.com/api/docs/guides/your-data
- OpenAI pricing: https://developers.openai.com/api/docs/pricing
- Anthropic OpenAI SDK compatibility: https://platform.claude.com/docs/en/api/openai-sdk
- Anthropic rate limits: https://platform.claude.com/docs/en/api/rate-limits
- Anthropic Message Batches: https://platform.claude.com/docs/en/build-with-claude/batch-processing
- Anthropic prompt caching: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- Anthropic API and data retention: https://platform.claude.com/docs/en/build-with-claude/zero-data-retention
- Anthropic data residency: https://platform.claude.com/docs/en/build-with-claude/data-residency
- Anthropic pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Gemini OpenAI compatibility: https://ai.google.dev/gemini-api/docs/openai
- Gemini batch mode: https://ai.google.dev/gemini-api/docs/batch-mode
- Gemini caching: https://ai.google.dev/gemini-api/docs/caching
- Gemini rate limits: https://ai.google.dev/gemini-api/docs/rate-limits
- Gemini API terms: https://ai.google.dev/gemini-api/terms
- Gemini pricing: https://ai.google.dev/gemini-api/docs/pricing
