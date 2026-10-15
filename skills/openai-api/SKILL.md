---
name: openai-api
description: Use the OpenAI API directly (api.openai.com) - keys, projects, Responses and Chat Completions, streaming, tools, structured output, Batch, prompt caching, files, rate-limit tiers, spend limits, data retention and ZDR, key revocation. Use for OPENAI_API_KEY, openai SDK, /v1/responses, /v1/chat/completions, /v1/models, 429 slow_down, organization_spend_limit_exceeded, LiteLLM openai/ routes. Cross-provider choice goes to cloud-llms; Azure goes to azure-foundry; gateway to llm-gateway.
license: MIT
compatibility: Any OS with bash, curl and jq; optional openai SDK (Python, Node) or openai CLI. Needs network access to api.openai.com and an API key in an environment variable or 0600 file. Creating keys, projects, limits or batches needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# OpenAI API

Call OpenAI models safely from code or a gateway: scoped project keys, the right endpoint, spend caps set before traffic, and a clean teardown.

**Scope:** the first-party OpenAI API: auth and projects, Responses and Chat Completions, streaming, function calling, Structured Outputs, Batch, prompt caching, Files, rate limits and tiers, spend limits, data controls (retention, ZDR, residency), Admin API key management, LiteLLM and OpenAI-SDK client config. **Out of scope:** OpenAI models on Azure (`azure-foundry`), tier choice across providers (`cloud-llms`, `choosing-llm-hosting`), gateway setup (`llm-gateway`, `litellm`), open-weight `gpt-oss` models on your own hardware (`gpt-oss`), evals (`llm-evals`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect before changing anything. Every command is read-only and never prints a secret.

```bash
# Is a key available? Names only, never values
env | cut -d= -f1 | grep -E '^(OPENAI|AZURE_OPENAI)_' || echo "no OPENAI_* variables"
[ -n "${OPENAI_API_KEY:-}" ] && echo "OPENAI_API_KEY is set" || echo "OPENAI_API_KEY missing"

# SDK and CLI versions (any that exist)
pip show openai 2>/dev/null | sed -n '1,2p'
npm ls openai 2>/dev/null | grep openai
command -v openai && openai --version

# Does the key work, and which models can it see? (free call)
curl -sS https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY" \
  | jq -r '.data[] | [.id, (.shutdown_date // "-")] | @tsv' | sort | head -40
```

`shutdown_date` in the model list marks announced shutdowns. Limits, tier and spend caps are in the console (Settings > Organization > Limits); see `references/limits-and-budgets.md`.

## Decision flow

1. No key yet, or one shared key everywhere: create a **project** per environment and a project or service-account key with an expiry (`references/setup-and-auth.md`).
2. Production traffic planned: set a spend alert and hard spend limit first (`references/limits-and-budgets.md`).
3. New text app: use `POST /v1/responses`. Existing Chat Completions code can stay; OpenAI-compatible clients and gateways use `/v1/chat/completions` (`references/api-and-sdks.md`).
4. Non-interactive bulk work: Batch API at a discount and its own rate pool (`references/features.md`).
5. Sensitive data: read data controls and ZDR eligibility per endpoint before sending (`references/data-controls.md`).
6. Fronted by a gateway or an OpenAI-compatible client: `references/litellm-and-clients.md`.
7. Errors: `references/troubleshooting.md`.

## Rules

- **Ask before creating billable or persistent resources.** Keys, projects, service accounts, batches, uploaded files, stored responses and fine-tunes need approval and a teardown plan.
- **Secrets never touch output.** Keys come from environment variables or `0600` files. Never echo, log or paste them. Rotate after any exposure.
- **One project and one key per app or environment.** Never ship an org-wide key to clients; clients get gateway keys.
- **Set budget controls before traffic.** Spend alerts do not stop traffic; a hard limit does and returns `429`. Know which you configured.
- **Pin model snapshots** in production; build evals before changing them. Re-list models, since aliases and shutdown dates change.
- **Never hardcode prices or limits.** Read the pricing page, the console Limits page and `x-ratelimit-*` headers.
- **Respect retries.** Follow `Retry-After`; do not retry quota, billing or spend-limit errors.
- **Always tear down.** Revoke test keys, delete files, batches and stored responses (`references/teardown.md`).

## Workflows

**Account and auth**

- [ ] Create a project per environment; create a key with an expiry in that project; export it from a `0600` file -> `references/setup-and-auth.md`
- [ ] Verify with `GET /v1/models`; record org and project in the decision record.

**Call the API**

- [ ] Responses (or Chat Completions) with a pinned model and `max_output_tokens` -> `references/api-and-sdks.md`
- [ ] Add streaming, tools or Structured Outputs only as needed -> `references/features.md`
- [ ] Cache: keep static prompt content first; read `usage` for cached tokens -> `references/features.md`

**Connect to a gateway or clients**

- [ ] LiteLLM `openai/<model>` entry with `api_key: os.environ/OPENAI_API_KEY` -> `references/litellm-and-clients.md`

**Control cost and risk**

- [ ] Spend alert, hard limit, per-project limits, model allowlist -> `references/limits-and-budgets.md`
- [ ] Data retention, ZDR, residency, `store` setting -> `references/data-controls.md`

**Tear down**

- [ ] Delete batches' files, stored responses and conversations; revoke keys; verify with list calls -> `references/teardown.md`

**Troubleshoot**

- [ ] Match the status and `error.code` -> `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: organizations, projects, user and service-account keys, expiry and governance, Admin API key.
- `references/api-and-sdks.md`: Responses and Chat Completions calls, SDK install, `/v1/models`, CLI, migration notes.
- `references/features.md`: streaming, function calling, Structured Outputs, Batch, prompt caching, Files.
- `references/limits-and-budgets.md`: tiers, rate-limit headers, ramp rules, spend alerts and hard limits.
- `references/data-controls.md`: abuse-monitoring retention, Zero Data Retention, `store`, residency, per-endpoint table.
- `references/litellm-and-clients.md`: LiteLLM entries and OpenAI SDK base_url patterns.
- `references/teardown.md`: revoke keys and delete every stored object.
- `references/troubleshooting.md`: symptom, cause, fix.

## Companion skills

- `cloud-llms`: choose between frontier APIs, hyperscalers and GPU rental. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: one endpoint, virtual keys and budgets in front of providers. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `litellm`: LiteLLM proxy details. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `anthropic-api`, `gemini-api`: the sibling frontier APIs. Install: `npx skills add ScaleDockHQ/llm-skills --skill anthropic-api`.
- `structured-outputs`, `llm-clients`: schema-constrained output and client config. Install: `npx skills add ScaleDockHQ/llm-skills --skill structured-outputs`.
- `llm-evals`, `llm-observability`: measure quality and trace calls. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `choosing-llm-hosting`, `self-hosted-llms`: when the data class rules out an API. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`.
