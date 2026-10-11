---
name: sambanova
description: Use SambaNova SambaCloud (api.sambanova.ai) for fast OpenAI- and Anthropic-compatible open-model APIs, with API keys, model listing, rate-limit tiers, prompt caching, deprecations, LiteLLM, Claude Code and OpenAI client wiring, and teardown. Use when the user mentions SambaNova, SambaNova Cloud, SambaCloud, SambaStack, SAMBANOVA_API_KEY, cloud.sambanova.ai, RDU inference, `sambanova/` LiteLLM models, 429 queue_full or insufficient_quota, or 410 model_deprecated. For provider-neutral choices use cloud-llms; for gateways use llm-gateway or litellm; for owned GPUs use self-hosted-llms.
license: MIT
compatibility: Any OS with bash, curl and jq; Python or Node SDKs are optional. Needs a SambaCloud account and an API key in an environment variable or a 0600 file. SambaStack is private infrastructure set up with SambaNova. Ask the user before linking a payment method or creating keys.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# SambaNova

Call open models on SambaNova SambaCloud through OpenAI Chat Completions, Responses or Anthropic Messages, stay inside tier limits and spend, connect it to LiteLLM and coding tools, and revoke keys when finished.

**Scope:** SambaCloud (the hosted API at `https://api.sambanova.ai/v1`) and, briefly, the fact that SambaStack (SambaNova's dedicated or on-prem deployment) uses admin-provided URLs and keys. Out of scope: choosing a provider (`cloud-llms`), gateway design (`llm-gateway`, `litellm`), self-hosting on GPUs (`self-hosted-llms`, `vllm`). Naming: the product is now SambaCloud (earlier "SambaNova Cloud"); the console is `cloud.sambanova.ai`.

Work through the steps in order. Load a reference only when a step names it. Models turn over quickly, so list them live.

## Discover first

Read-only. Nothing here prints a key.

```bash
env | cut -d= -f1 | grep -i -E '^(SAMBANOVA|ANTHROPIC|OPENAI|LITELLM)' || echo "no related env vars"
command -v curl jq python3 node

# Models this key can use (ids only)
curl -sS https://api.sambanova.ai/v1/models -H "Authorization: Bearer $SAMBANOVA_API_KEY" | jq -r '.data[].id'
```

The `/v1/models` response also carries per-model metadata (the caching page says pricing is available there). Inspect it with `jq '.data[0]'` before parsing.

## Decision flow

1. No key: create one in the SambaCloud portal, API section (`references/setup-and-auth.md`). Keys are shown once.
2. Pick a model: Production for real traffic, Preview for experiments only (limited capacity, removable at short notice) (`references/models-and-features.md`).
3. Calling: OpenAI SDK (`/v1/chat/completions`, `/v1/responses`) or Anthropic SDK (`/v1/messages`) (`references/api-and-compat.md`).
4. Hitting 429 or 410: tier limit, queue full or deprecated model (`references/limits-and-quotas.md`, `references/troubleshooting.md`).
5. Through a gateway: `sambanova/<model-id>` in LiteLLM (`references/litellm-and-clients.md`).
6. Need higher limits, retired models or private capacity: contact SambaNova sales, SambaStack is the route.
7. Finished: delete keys (`references/teardown.md`).

## Rules

- **Ask before billable or account changes.** Linking a payment method moves the account from Free to Developer tier; creating keys; contacting sales.
- **Secrets never touch output.** Keys live in `SAMBANOVA_API_KEY` or a `0600` file. Keys cannot be viewed again after creation, so store them right away. Do not echo them.
- **Pin exact model IDs and read the deprecation page.** Production models get at least two to three weeks notice, Preview models may be removed on short notice, and a retired model returns `410 model_deprecated`.
- **Budget first.** Developer tier is capped by requests per minute and day and by a daily token ceiling. Spend alerts or caps are not documented on the pages read; put budgets in your gateway.
- **Keep one key per app or environment** (up to 25 keys per user) so each can be revoked alone.
- **Always tear down.** Delete unused keys and remove them from gateways and CI.

## Workflows

### 1. Account and key

- [ ] Sign in at `cloud.sambanova.ai`, open the API section, generate a key, save it immediately -> `references/setup-and-auth.md`
- [ ] Store: `umask 077; read -rs K; printf '%s' "$K" > ~/.config/sambanova.key; unset K`
- [ ] Verify with `GET /v1/models` (Discover first).

### 2. First call

- [ ] Chat Completions, Responses or Messages example -> `references/api-and-compat.md`
- [ ] Reasoning, tools, vision, structured output, caching -> `references/models-and-features.md`

### 3. Connect to LiteLLM, OpenAI clients and coding tools

- [ ] `model: sambanova/<id>`, `api_key: os.environ/SAMBANOVA_API_KEY` -> `references/litellm-and-clients.md`
- [ ] Anthropic-protocol tools (Claude Code) use the Messages endpoint; see the same file.

### 4. Limits and spend

- [ ] Read tier limits and response headers -> `references/limits-and-quotas.md`
- [ ] Add gateway-side RPM and token caps below the SambaNova limits (`llm-gateway`).

### 5. Update models

- [ ] Check `https://docs.sambanova.ai/docs/en/models/deprecations.md`, swap retired IDs, rerun evals (`llm-evals`).

### 6. Tear down

- [ ] Delete keys in the portal, drop them from configs -> `references/teardown.md`
- [ ] Verify the old key returns `401`.

### 7. Troubleshoot

- [ ] Use the error code table -> `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: SambaCloud versus SambaStack, API keys, tiers, secrets handling.
- `references/api-and-compat.md`: base URLs, OpenAI, Responses and Anthropic compatibility, unsupported params, error format.
- `references/models-and-features.md`: Production and Preview models, deprecation record, caching, features.
- `references/limits-and-quotas.md`: tiers, RPM, RPD, TPD, headers.
- `references/litellm-and-clients.md`: LiteLLM, OpenAI SDK, Claude Code.
- `references/teardown.md`: key revocation and cleanup.
- `references/troubleshooting.md`: error codes and fixes.

## Companion skills

- `cloud-llms`: compare providers and hybrid routing. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: one endpoint in front of SambaNova and others. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `litellm`: proxy configuration in depth. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `cerebras`, `groq`, `together-ai`: other fast managed APIs. Install: `npx skills add ScaleDockHQ/llms-skills --skill cerebras`.
- `llm-evals`: re-check quality after a model swap. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `llm-observability`: cost and trace tracking. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
- `self-hosted-llms`: run open models on owned GPUs. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
