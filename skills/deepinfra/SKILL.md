---
name: deepinfra
description: Use DeepInfra (api.deepinfra.com) for OpenAI- and Anthropic-compatible open-model APIs, private GPU deployments and GPU rentals, with API keys, per-key spend limits, scoped JWTs, batch, LiteLLM and Claude Code wiring, and teardown. Use when the user mentions DeepInfra, DEEPINFRA_API_KEY, deepinfra.com, `deepinfra/` LiteLLM models, a dedicated or custom LLM deployment (`/deploy`), GPU instances (`/v1/containers`), "Rate limited" 429s, or runaway per-GPU-hour bills. For provider-neutral choices use cloud-llms; for gateways use llm-gateway or litellm; for owned GPUs use self-hosted-llms.
license: MIT
compatibility: Any OS with bash, curl and jq; Python or Node SDKs are optional. Needs a DeepInfra account and an API key in an environment variable or a 0600 file. Ask the user before enabling billing, creating private deployments or GPU containers, or changing spend limits. Dedicated deployments bill by the GPU-hour until stopped.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# DeepInfra

Call open models on DeepInfra's shared serverless API, optionally run a private deployment or rent a GPU, keep spend capped, wire it into LiteLLM and coding tools, and shut everything down.

**Scope:** DeepInfra serverless inference (`https://api.deepinfra.com/v1/openai`, Anthropic at `https://api.deepinfra.com/anthropic`), API keys and scoped JWTs, per-key monthly spend limits, Batch API, private Custom LLM deployments (`/deploy/*`) and GPU instances (`/v1/containers`). Out of scope: choosing among providers (`cloud-llms`), gateway design (`llm-gateway`, `litellm`), serving on your own hardware (`self-hosted-llms`, `vllm`), fine-tuning methods (`fine-tuning-llms`).

Work through the steps in order. Load a reference only when a step names it. Model catalogs change fast, so list models live.

## Discover first

Read-only. Nothing here prints a key.

```bash
env | cut -d= -f1 | grep -i -E '^(DEEPINFRA|ANTHROPIC|OPENAI|LITELLM)' || echo "no related env vars"
command -v curl jq python3 node

# Serverless models (ids)
curl -sS https://api.deepinfra.com/v1/openai/models -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq -r '.data[].id' | head -30

# Billable things already running (run these before anything else if the account is not new)
curl -sS https://api.deepinfra.com/deploy/list -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq '.[] | {deploy_id, model_name, status}'
curl -sS https://api.deepinfra.com/v1/containers -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq .
```

`GET /v1/openai/models` also answers without a key. An empty `/deploy/list` and `/v1/containers` means nothing is billing by the hour.

## Decision flow

1. No key: create one in the Dashboard (`references/setup-and-auth.md`). Set a monthly limit on it at once.
2. Pay per token, no infra: serverless chat, embeddings, images, audio (`references/api-and-compat.md`, `references/models-and-features.md`).
3. Third party needs access: scoped JWT with model list, expiry and spend cap.
4. Offline bulk work: Batch API, 20% below real-time, 24 hour window.
5. Custom weights, isolation or fine-tune: private LLM deployment, billed per GPU-hour whether or not traffic arrives (`references/dedicated-and-gpu.md`).
6. Need a raw GPU with SSH: GPU instance container (same file).
7. Gateway: `deepinfra/<model-id>` in LiteLLM (`references/litellm-and-clients.md`).
8. Done or idle: stop or delete deployments and containers, revoke keys (`references/teardown.md`).

## Rules

- **Ask before billable resources.** Deployments, containers, adding funds, raising limits.
- **Secrets never touch output.** `DEEPINFRA_API_KEY` from env or a `0600` file; scoped JWTs are secrets too. Do not paste tokens into chat or logs.
- **Budget before traffic.** Set a monthly limit on the key (`POST /payment/key-limits`) and use payment-settings spending limits. The docs warn that a forgotten 2-GPU deployment over a weekend costs roughly 256 USD.
- **Pin exact model slugs.** Use dated slugs (for example `...-0731`); undated slugs can be older previews that the dated releases supersede.
- **Check what is running before and after.** List `/deploy` and `/v1/containers` at the start and end of every session.
- **Always tear down.** Container termination deletes all data, so save work first; deleting a deployment is permanent.
- **Mind data handling.** Inference input and output are not stored or trained on, except via Google and Anthropic model exceptions the docs list; bulk APIs may store encrypted data briefly (`references/setup-and-auth.md`).

## Workflows

### 1. Account, key, budget

- [ ] Dashboard sign-in, create key, store in a `0600` file -> `references/setup-and-auth.md`
- [ ] Set a monthly per-key limit and account spend limits -> `references/limits-and-spend.md`

### 2. Call the API

- [ ] OpenAI client with `base_url=https://api.deepinfra.com/v1/openai` -> `references/api-and-compat.md`
- [ ] Anthropic clients with `base_url=https://api.deepinfra.com/anthropic` (no `/v1` for Claude Code)
- [ ] Verify: `usage.estimated_cost` appears in responses.

### 3. Connect to LiteLLM and tools

- [ ] `model: deepinfra/<slug>`, `api_key: os.environ/DEEPINFRA_API_KEY` -> `references/litellm-and-clients.md`

### 4. Private deployment or GPU (only with approval)

- [ ] Check GPU availability, create a deployment, wait for `deployed`, set `min_instances` and `max_instances` deliberately -> `references/dedicated-and-gpu.md`
- [ ] Note the stop condition now (time or idle) and set a reminder.

### 5. Monitor cost

- [ ] Usage and key-limit endpoints, Dashboard usage -> `references/limits-and-spend.md`

### 6. Tear down

- [ ] Stop or delete deployments, terminate containers, delete test keys and JWT-issuing keys -> `references/teardown.md`
- [ ] Verify lists are empty and the old key returns 401 or 403.

### 7. Troubleshoot

- [ ] `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: account, API keys, scoped JWTs, data handling.
- `references/api-and-compat.md`: OpenAI and Anthropic endpoints, base URLs, Batch API.
- `references/models-and-features.md`: catalog access, prompt caching, tools, structured output.
- `references/limits-and-spend.md`: concurrency limit, per-key and account spend limits, usage.
- `references/dedicated-and-gpu.md`: private LLM deployments and GPU containers.
- `references/litellm-and-clients.md`: LiteLLM, OpenAI SDK, Claude Code.
- `references/teardown.md`: stop and delete everything billable.
- `references/troubleshooting.md`: symptom to fix.

## Companion skills

- `cloud-llms`: provider choice and hybrid routing. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: one endpoint in front of DeepInfra. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `litellm`: proxy configuration in depth. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `together-ai`, `fireworks-ai`, `groq`: comparable managed APIs. Install: `npx skills add ScaleDockHQ/llm-skills --skill together-ai`.
- `llm-evals`, `llm-observability`: quality and cost checks. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `fine-tuning-llms`: produce the weights you deploy privately. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `self-hosted-llms`, `vllm`: your own GPUs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
