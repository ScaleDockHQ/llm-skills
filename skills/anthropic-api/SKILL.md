---
name: anthropic-api
description: Use the Claude API directly (api.anthropic.com) - keys, workspaces, Messages API, OpenAI SDK compatibility, streaming, tools, structured outputs, Message Batches, prompt caching, Files, rate-limit tiers, spend limits, ZDR, key revocation. Use for ANTHROPIC_API_KEY, anthropic SDK, ant CLI, /v1/messages, x-api-key, anthropic-version, 429 rate_limit_error, 529 overloaded_error, LiteLLM anthropic/ routes. Cross-provider choice goes to cloud-llms; Bedrock to aws-bedrock; gateway to llm-gateway.
license: MIT
compatibility: Any OS with bash, curl and jq; optional anthropic SDK (Python, TypeScript and others) or the ant CLI (brew install anthropics/tap/ant). Needs network access to api.anthropic.com and a key in an environment variable or 0600 file. Creating keys, workspaces, limits or batches needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Anthropic Claude API

Call Claude safely from code or a gateway: workspace-scoped keys with expiry (or federated identity), the native Messages API for full features, spend and rate controls set before traffic, and a clean teardown.

**Scope:** the first-party Claude API: auth (keys, Workload Identity Federation), organizations and workspaces, Messages API, the OpenAI SDK compatibility layer, streaming, tools, structured outputs, Message Batches, prompt caching, Files, rate limits and spend limits, data retention and ZDR, Admin API key management, LiteLLM and client config. **Out of scope:** Claude on Amazon Bedrock (`aws-bedrock`), on Google Cloud (`google-vertex-ai`) or on Microsoft Foundry (`azure-foundry`), provider choice (`cloud-llms`, `choosing-llm-hosting`), gateways (`llm-gateway`, `litellm`), evals (`llm-evals`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect before changing anything. Every command is read-only and never prints a secret.

```bash
# Key present? Names only, never values
env | cut -d= -f1 | grep -E '^ANTHROPIC_' || echo "no ANTHROPIC_* variables"
[ -n "${ANTHROPIC_API_KEY:-}" ] && echo "ANTHROPIC_API_KEY is set" || echo "ANTHROPIC_API_KEY missing"

# SDK and CLI versions (any that exist)
pip show anthropic 2>/dev/null | sed -n '1,2p'
npm ls @anthropic-ai/sdk 2>/dev/null | grep anthropic
command -v ant && ant --version && ant auth status

# Does the key work, and which models are active? (free call)
curl -sS https://api.anthropic.com/v1/models -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  | jq -r '.data[] | [.id, .lifecycle, (.retires_at // "-")] | @tsv'
```

Tier, rate limits and spend caps are on the Console Rate limits and Billing pages; see `references/limits-and-budgets.md`.

## Decision flow

1. No key, or one shared key: make a **workspace** per environment and a personal or service-account key with an expiry, or use Workload Identity Federation for CI and servers (`references/setup-and-auth.md`).
2. A key that works in several workspaces needs the `anthropic-workspace-id` header on every call.
3. Need prompt caching, thinking output, strict schemas, PDFs or citations: use the **native Messages API**, not the OpenAI compatibility layer (`references/api-and-sdks.md`).
4. Existing OpenAI-SDK code to test Claude quickly: compatibility layer with its documented limits (`references/api-and-sdks.md`).
5. Bulk non-interactive work: Message Batches (`references/features.md`).
6. Sensitive data: read ZDR and per-feature eligibility first (`references/data-controls.md`).
7. Gateway or client config: `references/litellm-and-clients.md`.
8. Errors: `references/troubleshooting.md`.

## Rules

- **Ask before creating billable or persistent resources.** Keys, workspaces, batches, uploaded files and spend settings need approval and a teardown plan.
- **Secrets never touch output.** Keys come from environment variables or `0600` files. Never echo or paste them. Rotate after exposure.
- **One workspace and one key per app or environment.** Clients get gateway keys, never provider keys.
- **Set a spend limit before traffic** and know that a limit you set returns HTTP `400`, while the tier cap returns `429` without `retry-after`.
- **Use native features deliberately.** The OpenAI layer ignores `strict`, `response_format` and prompt caching.
- **Pin model IDs** and re-list `/v1/models` for `lifecycle` and `retires_at`.
- **Never hardcode prices or limits.** Read the Console, the models and pricing pages and `anthropic-ratelimit-*` headers.
- **Always tear down.** Disable test keys, delete files and batches, archive test workspaces (`references/teardown.md`).

## Workflows

**Account and auth**

- [ ] Workspace per environment; key with expiry linked to a service account (or WIF) -> `references/setup-and-auth.md`
- [ ] Verify with `GET /v1/models`; send `anthropic-workspace-id` if the key spans workspaces.

**Call the API**

- [ ] Messages call with pinned model and `max_tokens` -> `references/api-and-sdks.md`
- [ ] Streaming, tools, structured outputs, caching only as needed -> `references/features.md`

**Connect to a gateway or clients**

- [ ] LiteLLM `anthropic/<model>` entry -> `references/litellm-and-clients.md`
- [ ] OpenAI-SDK clients through the compatibility layer only for testing -> `references/api-and-sdks.md`

**Control cost and risk**

- [ ] Tier, spend limit, workspace limits, Rate Limits API -> `references/limits-and-budgets.md`
- [ ] Retention, ZDR, 30-day-retention models -> `references/data-controls.md`

**Tear down**

- [ ] Cancel and delete batches, delete files, deactivate keys, archive workspaces -> `references/teardown.md`

**Troubleshoot**

- [ ] Match the status and `error.type` -> `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: key types, expiry, workspaces, WIF, Admin API, `ant` CLI.
- `references/api-and-sdks.md`: Messages API, SDKs, model listing, OpenAI SDK compatibility and its limits.
- `references/features.md`: streaming, tools, structured outputs, Batches, prompt caching, Files.
- `references/limits-and-budgets.md`: tiers, headers, ITPM and OTPM, spend limits, workspace limits.
- `references/data-controls.md`: ZDR, HIPAA readiness, retention per feature, `inference_geo`.
- `references/litellm-and-clients.md`: LiteLLM entries and client base URLs.
- `references/teardown.md`: revoke and delete everything.
- `references/troubleshooting.md`: symptom, cause, fix.

## Companion skills

- `cloud-llms`: choose between frontier APIs, hyperscalers and GPU rental. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: one endpoint, virtual keys and budgets. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `litellm`: proxy details. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `openai-api`, `gemini-api`: sibling frontier APIs. Install: `npx skills add ScaleDockHQ/llms-skills --skill openai-api`.
- `aws-bedrock`: Claude through AWS contracts and IAM. Install: `npx skills add ScaleDockHQ/llms-skills --skill aws-bedrock`.
- `structured-outputs`, `llm-clients`, `llm-evals`, `llm-observability`: schema output, clients, quality, tracing. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`.
- `choosing-llm-hosting`, `self-hosted-llms`: when data rules out an API. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`.
