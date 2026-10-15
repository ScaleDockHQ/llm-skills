---
name: openrouter
description: Use OpenRouter, a hosted gateway with one OpenAI-compatible API for hundreds of models, provider routing, fallbacks, presets, BYOK and spend controls. Use when asked about OpenRouter, openrouter.ai, OPENROUTER_API_KEY, `openrouter/` LiteLLM models, provider order or sort, `models` fallbacks, `:nitro` or `:free`, `@preset/`, guardrails, ZDR, or 402, 403, 429 errors. No self-hosting; for a self-run gateway use litellm, for the choice use llm-gateway.
license: MIT
compatibility: Any OS with bash, curl and jq. Needs an OpenRouter API key in an env var or 0600 file and credits for paid models. Creating keys, adding credits, BYOK keys, guardrails and ZDR changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# OpenRouter

Call hundreds of models through one OpenAI-compatible endpoint, control which providers serve them, add fallbacks and spend limits, wire it into clients and a LiteLLM gateway, and clean up keys.

**Scope:** the OpenRouter hosted service: API, keys, routing, presets, BYOK, guardrails and data controls, caching, broadcast, limits. It cannot be installed or self-hosted, so there is no install workflow; the lifecycle is keys, credits and workspace settings. Out of scope: choosing a gateway (`llm-gateway`), running your own gateway (`litellm`, `portkey`, `envoy-ai-gateway`, `kong-ai-gateway`), provider accounts directly (`cloud-llms`).

Work through the steps in order. Load a reference only when a step names it. Docs were read on 2026-10-11; the model catalog and prices change daily, so list models from the API and never copy IDs or prices from examples.

## Discover first

Read-only. Key values never print.

```bash
env | cut -d= -f1 | grep -iE 'openrouter|openai_(api|base)|anthropic_(base|auth)'

# Key valid? Shows limit, remaining credit, effective budget (no key echoed)
curl -fsS https://openrouter.ai/api/v1/key -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  | jq '.data | {label, limit, limit_remaining, usage_daily, usage_monthly, is_free_tier, effective_budget}'

# Models this key can use (text models by default), and one model's endpoints
curl -fsS https://openrouter.ai/api/v1/models -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq -r '.data[].id' | head -20
curl -fsS "https://openrouter.ai/api/v1/models?output_modalities=all" | jq '.data | length'
curl -fsS "https://openrouter.ai/api/v1/models/<author>/<slug>/endpoints" | jq '.data.endpoints | length'   # inspect one entry before filtering fields
```

Ask only what discovery cannot show: workloads, whether data may leave to third-party providers, monthly spend limit, who needs keys (people, CI, apps), and whether existing provider keys should be reused (BYOK).

## Decision flow

1. **No key yet:** create one with a credit limit. -> `references/setup-and-auth.md`
2. **Any call fails:** read `error.code` and `error.metadata.limit_source`. -> `references/troubleshooting.md`
3. **Need predictable providers or latency:** `provider` object, `sort`, `:nitro`, `:floor`, `order`/`only`. -> `references/routing-and-fallbacks.md`
4. **Need failover across models:** `models` array (or `fallbacks` on `/messages`). -> `references/routing-and-fallbacks.md`
5. **Prompts are sensitive:** `data_collection: "deny"`, `zdr: true`, guardrails, regional domains. -> `references/data-controls.md`
6. **Spending control for people, CI or agents:** per-key limits, guardrail and workspace budgets. -> `references/limits-and-budgets.md`
7. **Own provider contracts or rate limits:** BYOK. -> `references/data-controls.md`
8. **Several apps share one configuration:** presets, caching, plugins. -> `references/features.md`
9. **Agent or IDE client, or a gateway in front:** -> `references/litellm-and-clients.md`
10. **Traces and cost reporting:** Broadcast or `/generation`. -> `references/observability.md`
11. **Done with it:** `references/teardown.md`.

## Rules

- **Ask before spending or retaining.** Adding credits, auto top-up, BYOK keys, guardrails and ZDR changes need approval. A key with no limit can spend the whole balance including auto top-ups.
- **Secrets never touch output.** Read `OPENROUTER_API_KEY` from the environment or a 0600 file. Management keys (admin-only, cannot call completions) stay separate and carry an expiry.
- **Limit every key.** Set a credit limit with a reset interval per app, environment and agent. One key per workload.
- **Pin what you can.** Model IDs get renamed and retired; pass explicit IDs, avoid `latest` aliases and routers like `openrouter/auto` where reproducibility matters, and check the `model` field of responses to see what served the call.
- **Be explicit about data.** Default routing may use providers that retain or train on prompts. Set `data_collection`, `zdr` or a guardrail before sending anything sensitive.
- **Route with intent.** Setting `order` or `sort` turns off default price-weighted load balancing; `allow_fallbacks: false` means a provider outage is an error.
- **Never hardcode prices or free quotas.** Read them from `/models`, the endpoint listing and `GET /api/v1/key`.
- **Verify features per model.** Tools, structured outputs and reasoning differ by model and provider; use `require_parameters: true` when a request depends on them.

## Workflows

### First request

- [ ] Create a key with a credit limit; store it in a 0600 file -> `references/setup-and-auth.md`.
- [ ] Run the discovery key check, then one chat call with an explicit model ID.
- [ ] Confirm `model` and provider in the response, and `usage` fields.

### Make routing and fallbacks predictable

- [ ] Choose `sort` or `order`, decide `allow_fallbacks`, add `models` fallbacks -> `references/routing-and-fallbacks.md`.
- [ ] Add `require_parameters: true` for tool calls or `response_format`.

### Lock down data and spend

- [ ] Choose a data posture (ZDR, `data_collection`, regional domain) -> `references/data-controls.md`.
- [ ] Set per-key limits and, for teams, guardrail or workspace budgets -> `references/limits-and-budgets.md`.

### Connect clients

- [ ] Base URL `https://openrouter.ai/api/v1` for OpenAI-style clients; `https://openrouter.ai/api` for Anthropic-style clients -> `references/litellm-and-clients.md`.
- [ ] Smoke test streaming and a tool call through the client.

### Observe and review

- [ ] Fetch cost by generation id, or enable Broadcast -> `references/observability.md`.

### Tear down

- [ ] Delete keys, BYOK keys and presets you no longer need; confirm by listing -> `references/teardown.md`.

## Verify before done

- [ ] `GET /api/v1/key` shows the expected limit and no unexpected `effective_budget`.
- [ ] A real request succeeded and its `model` and provider match the intent.
- [ ] Data posture is explicit, and no key was printed or committed.
- [ ] A fallback or failure test was run when fallbacks were configured.

## Reference index

- `references/setup-and-auth.md`: account, keys, headers, SDKs, management keys.
- `references/api-and-models.md`: endpoints, model IDs and variants, parameters, errors.
- `references/routing-and-fallbacks.md`: provider object, sort, `models`, routers.
- `references/data-controls.md`: ZDR, data collection, guardrails, BYOK, regions.
- `references/limits-and-budgets.md`: credit, budget and rate limits, workspaces.
- `references/features.md`: presets, response caching, structured outputs, tools, plugins.
- `references/observability.md`: Broadcast, generation stats, router metadata.
- `references/litellm-and-clients.md`: LiteLLM, Claude Code, SDKs.
- `references/teardown.md`: keys, BYOK, presets, credits.
- `references/troubleshooting.md`: symptoms, causes and fixes.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-gateway`: choose between OpenRouter, LiteLLM, Portkey, Envoy and Kong.
- `litellm`: self-hosted gateway that can front OpenRouter.
- `cloud-llms`: direct provider accounts and cost model.
- `llm-clients`: pointing agents, IDEs and SDKs at a gateway.
- `llm-observability`: Langfuse and other trace sinks.
