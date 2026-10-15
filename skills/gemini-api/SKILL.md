---
name: gemini-api
description: Use the Google Gemini API directly (generativelanguage.googleapis.com) - keys, projects, generateContent, Interactions API, OpenAI compatibility, streaming, tools, structured output, Batch, context caching, Files, tiers, spend caps, paid vs free data use. Use for GEMINI_API_KEY, google-genai SDK, AI Studio, 429 RESOURCE_EXHAUSTED, 402 Payment Required, LiteLLM gemini/ routes. Cross-provider choice goes to cloud-llms; Vertex AI goes to google-vertex-ai; gateway to llm-gateway.
license: MIT
compatibility: Any OS with bash, curl and jq; optional google-genai SDK (Python, Node, Go, Java) or the openai SDK. Needs network access to generativelanguage.googleapis.com and a key in an environment variable or 0600 file. Creating keys, projects, billing, credits, caches, files or batches needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Gemini API

Call Gemini models through the Google AI Studio / Gemini Developer API safely: a restricted key per app, billing and spend caps understood before traffic, the right endpoint, and a clean teardown.

**Scope:** the Gemini Developer API: keys and projects, billing plans and tiers, `generateContent`, the newer Interactions API, OpenAI compatibility, streaming, function calling, structured output, Batch, context caching, Files, rate and spend limits, paid vs unpaid data use, LiteLLM and client config. **Out of scope:** Gemini on Google Cloud with IAM and regions (`google-vertex-ai`), tier choice across providers (`cloud-llms`, `choosing-llm-hosting`), gateway setup (`llm-gateway`, `litellm`), open Gemma weights on your own hardware (`self-hosted-llms`), evals (`llm-evals`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect before changing anything. Every command is read-only and never prints a secret.

```bash
# Is a key available? Names only, never values (GOOGLE_API_KEY wins over GEMINI_API_KEY in the SDKs)
env | cut -d= -f1 | grep -E '^(GEMINI|GOOGLE)_' || echo "no GEMINI_* or GOOGLE_* variables"

# SDK versions (any that exist)
pip show google-genai 2>/dev/null | sed -n '1,2p'
npm ls @google/genai 2>/dev/null | grep genai

# Does the key work, and which models can it see? (free call)
curl -sS "https://generativelanguage.googleapis.com/v1beta/models" -H "x-goog-api-key: ${GEMINI_API_KEY:?}" \
  | jq -r '.models[] | [.name, ((.supportedGenerationMethods // []) | join(","))] | @tsv' | head -40
```

Tier, limits and spend caps are in AI Studio (Dashboard > Projects, Usage, Spend, Billing); see `references/limits-and-budgets.md`.

## Decision flow

1. No key, or unrestricted standard keys: create an **auth key** in a dedicated project; restrict it to the Gemini API (`references/setup-and-auth.md`).
2. Paid use planned: understand Prepay vs Postpay, the 402 at zero balance, and set a project spend cap first (`references/limits-and-budgets.md`).
3. New app: choose the native API (`generateContent` is the long-standing path; the Interactions API is the newer one and has gaps) per `references/api-and-sdks.md`. OpenAI-format clients use the compatibility base URL.
4. Non-interactive bulk work: Batch API at a discount, its own limits (`references/features.md`).
5. Sensitive data: only the paid quota keeps prompts out of product improvement; read `references/data-controls.md` first.
6. Gateway or OpenAI-compatible client: `references/litellm-and-clients.md`.
7. Errors: `references/troubleshooting.md`.

## Rules

- **Ask before creating billable or persistent resources.** Keys, projects, billing links, credits, auto-reload, caches, files and batches need approval and a teardown plan.
- **Secrets never touch output.** Keys come from environment variables or `0600` files, sent in the `x-goog-api-key` header. Avoid `?key=` URLs, which land in logs.
- **Never use free quota for sensitive data.** Unpaid services may use content to improve Google products, with human review (check the current terms).
- **Prepay means a zero balance stops every key on the billing account.** Spend caps are experimental and lag by about 10 minutes; batch and agent jobs can overshoot.
- **Never put keys in client apps.** Use a backend proxy or a gateway key.
- **Pin model IDs** and re-list models; preview models have tighter limits and change.
- **Never hardcode prices or limits.** Read the pricing page and AI Studio.
- **Always tear down.** Disable keys, delete files and caches, check batches (`references/teardown.md`).

## Workflows

**Account and auth**

- [ ] Project per environment; auth key restricted to Gemini API; key in a `0600` file -> `references/setup-and-auth.md`
- [ ] Verify with `GET /v1beta/models`.

**Call the API**

- [ ] `generateContent` or Interactions with a pinned model and a token cap -> `references/api-and-sdks.md`
- [ ] Streaming, tools, structured output, caching, Files only as needed -> `references/features.md`

**Connect to a gateway or clients**

- [ ] LiteLLM `gemini/<model>` with `api_key: os.environ/GEMINI_API_KEY`, or the OpenAI SDK base URL -> `references/litellm-and-clients.md`

**Control cost and risk**

- [ ] Billing plan, tier, project spend cap, billing alerts -> `references/limits-and-budgets.md`
- [ ] Paid vs unpaid data use, grounding retention -> `references/data-controls.md`

**Tear down**

- [ ] Delete files and caches; confirm batches ended; disable keys; archive test projects -> `references/teardown.md`

**Troubleshoot**

- [ ] Match the HTTP status and error status string -> `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: key types, AI Studio projects, restrictions, leak response.
- `references/api-and-sdks.md`: generateContent, Interactions API, OpenAI compatibility, model listing.
- `references/features.md`: streaming, tools, structured output, Batch, caching, Files.
- `references/limits-and-budgets.md`: tiers, rate and spend-rate limits, Prepay and Postpay, spend caps.
- `references/data-controls.md`: paid vs unpaid terms, grounding storage, Files retention.
- `references/litellm-and-clients.md`: LiteLLM `gemini/` entries and client base URLs.
- `references/teardown.md`: disable keys and delete stored objects.
- `references/troubleshooting.md`: symptom, cause, fix.

## Companion skills

- `cloud-llms`: choose between frontier APIs, hyperscalers and GPU rental. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: one endpoint, virtual keys and budgets in front of providers. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `litellm`: LiteLLM proxy details. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `google-vertex-ai`: Gemini on Google Cloud with IAM and regions. Install: `npx skills add ScaleDockHQ/llm-skills --skill google-vertex-ai`.
- `openai-api`, `anthropic-api`: the sibling frontier APIs. Install: `npx skills add ScaleDockHQ/llm-skills --skill openai-api`.
- `structured-outputs`, `llm-clients`: schema-constrained output and client config. Install: `npx skills add ScaleDockHQ/llm-skills --skill structured-outputs`.
- `llm-evals`, `llm-observability`: measure quality and trace calls. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `choosing-llm-hosting`, `self-hosted-llms`: when the data class rules out an API. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`.
