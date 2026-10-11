# OpenRouter data controls, guardrails and BYOK

> Verified against OpenRouter API v1 (docs: features/zdr, privacy/data-collection, features/guardrails, overview/auth/byok, features/in-region-routing), 2026-10-11

## What OpenRouter itself retains

Prompt retention on OpenRouter is opt-in (input/output logging is a setting). Provider behavior differs per endpoint: some do not retain, some retain without training (abuse scanning, legal), some may train on prompts. OpenRouter tracks the policy per endpoint and publishes it at https://openrouter.ai/docs/guides/privacy/provider-logging. Defaults allow providers that may store data. Decide before sending sensitive prompts.

## Controls, narrowest first

1. **Per request:** `provider: {"data_collection": "deny"}` or `provider: {"zdr": true}`.
2. **Per key or member (guardrail):** ZDR enforcement per model group (`enforce_zdr_anthropic`, `enforce_zdr_openai`, `enforce_zdr_google`, `enforce_zdr_xai`, `enforce_zdr_other`), model and provider allowlists, data regions, prompt-injection detection, sensitive-info redaction or blocking, custom regex filters. The legacy `enforce_zdr` is deprecated.
3. **Account:** https://openrouter.ai/settings/privacy applies as a default guardrail for everything.
4. **Region:** `https://eu.openrouter.ai` or `https://us.openrouter.ai` processes entirely in-region (Business and Enterprise). A guardrail can restrict `allowed_data_regions` to `global`, `europe`, `us`.

Preview what ZDR does to availability before enforcing it: `GET https://openrouter.ai/api/v1/endpoints/zdr` lists the ZDR endpoints, so you can confirm your model still has one. A request whose constraints leave no endpoint fails with 503.

## Guardrails

Managed per workspace (dashboard: Workspace, Guardrails). A guardrail can set a budget with daily, weekly or monthly reset, model and provider allowlists, ZDR, data regions, security and sensitive-info filters. Assign one guardrail directly to a member or an API key; keys also follow their owner's guardrail. Combination rules: allowlists intersect, ZDR is OR per model group, so the most restrictive result wins. Only the account-level privacy settings always apply as a default underneath. A block returns 403 with a message such as `Request blocked: prompt injection patterns detected`.

## BYOK (your own provider keys)

Manage in workspace BYOK settings (https://openrouter.ai/integrations). Keys are stored encrypted. Notes from the docs:

- Using BYOK is billed as a percentage of what the same model and provider would cost on OpenRouter, deducted from credits, with a plan-dependent free allowance. Read the current terms on the BYOK page; do not hardcode numbers.
- Each key sits in **Prioritized** (tried before OpenRouter endpoints) or **Fallback** (after) sections, in order, per provider.
- **Shared capacity fallback** per key: default uses OpenRouter capacity when your key fails; "never use shared capacity for models this key applies to", or "for any model on this provider", makes failures surface as errors instead of spending credits. Pick the strict option when contracts or data residency require your own account.
- With `provider.order`, the provider you name is tried first, your BYOK key before OpenRouter capacity inside that provider's slot.
- Regional premium endpoints (for example Bedrock or Vertex region-pinned ones) are skipped on the global API unless targeted; with a prioritized BYOK key the premium is billed to your own provider account.
- BYOK spend is not counted against guardrail budgets unless `include_byok_in_budgets` is on, and key credit limits count it only with `include_byok_in_limit`.

## Verify

- [ ] A test request with the intended constraints succeeds, and one that violates them (disallowed model) returns 403.
- [ ] `GET /api/v1/key` shows the expected budgets. No sensitive prompt was sent before the posture was set.
