---
name: cerebras
description: Use Cerebras Inference Cloud (api.cerebras.ai) for fast OpenAI-compatible open-model APIs, with key and project setup, model listing, rate limits, prompt caching, batch, dedicated endpoints, LiteLLM and teardown. Use when the user mentions Cerebras, cerebras.ai, CEREBRAS_API_KEY, cerebras-cloud-sdk, wafer-scale inference, gpt-oss-120b or qwen on Cerebras, 429 "uncached" token limits, Cerebras Dedicated Inference, or wiring Cerebras into LiteLLM or a gateway. For provider-neutral choices use cloud-llms; for the gateway use llm-gateway or litellm; for owned GPUs use self-hosted-llms.
license: MIT
compatibility: Any OS with bash, curl and jq; the Python or Node SDK is optional. Needs a Cerebras Cloud account and an API key in an environment variable or a 0600 file. Ask the user before adding credits, creating keys, enabling auto-recharge or requesting Dedicated Inference.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Cerebras Inference

Call open models on Cerebras Inference Cloud through its OpenAI-compatible API, stay inside rate limits and spend, plug it into LiteLLM or any OpenAI client, and clean up keys and projects when done.

**Scope:** the Cerebras Cloud console (organizations, projects, API keys, limits, usage), Shared Inference (`https://api.cerebras.ai/v1`), Dedicated Inference, the Cerebras Python and Node SDKs, and LiteLLM wiring. Out of scope: choosing between providers (`cloud-llms`), gateway design (`llm-gateway`, `litellm`), running models on your own GPUs (`self-hosted-llms`, `vllm`).

Work through the steps in order. Load a reference only when a step names it. The docs are updated often (models were added and retired within months), so list models live instead of trusting any list in this skill.

## Discover first

Read-only. Nothing here prints a key.

```bash
# Key present? Print variable NAMES only
env | cut -d= -f1 | grep -i -E '^(CEREBRAS|OPENAI|LITELLM)' || echo "no Cerebras-related env vars"

# Tools
command -v curl jq python3 node
python3 -c 'import cerebras.cloud.sdk' 2>&1 | tail -1     # SDK installed?

# Which models can this key use? (ids only; shows 401 text if the key is wrong)
curl -sS https://api.cerebras.ai/v1/models -H "Authorization: Bearer $CEREBRAS_API_KEY" | jq -r '.data[].id'
```

Limits and spend are not available through a documented read-only API call. They are in the Cloud Console under Limits, Analytics and Billing (`references/limits-and-quotas.md`).

## Decision flow

1. No key yet: create one in the Cloud Console (`references/setup-and-auth.md`). The free trial needs a verified payment method and the credits expire.
2. Need a model: list `/v1/models`, then read the model page for context, features and per-tier limits (`references/models-and-features.md`).
3. Calling from code: OpenAI SDK with `base_url=https://api.cerebras.ai/v1`, or the Cerebras SDK (`references/api-and-compat.md`). Note the compatibility differences (`n` is 1 only, image URLs must be data URIs, no `tools` plus `response_format` on gpt-oss-120b).
4. Hitting 429: it names which bucket tripped (uncached or total tokens, or requests). Lower `max_completion_tokens`, raise the cache hit rate, or ask for more limits (`references/limits-and-quotas.md`).
5. Need isolation, custom weights or reserved capacity: Dedicated Inference is enterprise-only. Contact Cerebras; this skill only documents the resource model.
6. Through a gateway: use the `cerebras/` prefix in LiteLLM (`references/litellm-and-clients.md`).
7. Finished or rotating: revoke and archive (`references/teardown.md`).

## Rules

- **Ask before creating billable or irreversible things.** Adding credits, auto-recharge, new keys, new projects, Dedicated Inference requests.
- **Secrets never touch output.** Keys come from the `CEREBRAS_API_KEY` variable or a `0600` file. Do not `echo` the key to verify it (the vendor quickstart does; use `[ -n "$CEREBRAS_API_KEY" ]`).
- **Pin the exact model ID.** The docs promise original, unpruned weights for an existing ID and say changes ship as new IDs, but models are retired on a schedule (see deprecations).
- **Budget first.** Free-trial credits expire; paid accounts have no hard spend cap documented on the pages read. Control spend with project-level limits, `max_completion_tokens` and alerts in your own gateway (`references/limits-and-quotas.md`).
- **Always set `max_completion_tokens`.** The rate limiter reserves the estimated maximum output up front, so a huge or unset value burns quota on requests that are short.
- **Separate environments with projects.** One key belongs to exactly one project and inherits its limits.
- **Always tear down.** Delete unused keys, archive unused projects, stop Dedicated deployments you no longer need (`references/teardown.md`).

## Workflows

### 1. Account and key

- [ ] Sign in to the Cloud Console, add a verified payment method if on the free trial, create a key under API Keys (choose the project first on paid accounts) -> `references/setup-and-auth.md`
- [ ] Store it: `umask 077; read -rs CEREBRAS_API_KEY; printf '%s' "$CEREBRAS_API_KEY" > ~/.config/cerebras.key` and export it from that file in the shell that runs the code.
- [ ] Verify: `curl .../v1/models` returns model ids (see Discover first).

### 2. First call and features

- [ ] Chat completion with cURL or SDK -> `references/api-and-compat.md`
- [ ] Streaming, tools, structured outputs, reasoning, images, caching -> `references/models-and-features.md`
- [ ] Verify: a response with `usage` and the expected `model`.

### 3. Connect to LiteLLM or an OpenAI client

- [ ] `model: cerebras/<model-id>` plus `api_key: os.environ/CEREBRAS_API_KEY`; send the vendor's `X-Cerebras-3rd-Party-Integration: litellm` header -> `references/litellm-and-clients.md`
- [ ] Add a fallback deployment from another provider. Provider-neutral fallbacks live in `cloud-llms` and `llm-gateway`.

### 4. Control limits and spend

- [ ] Read the Limits page for your org and project; set project-level limits for non-production work; watch Analytics (Usage, Cached-Usage, Cost) -> `references/limits-and-quotas.md`
- [ ] Batch is a private preview with a separate limit set; Service tiers are a private preview and not available on Shared Inference.

### 5. Update or migrate models

- [ ] Check the Deprecations page, replace retired IDs in configs, rerun your evals (`llm-evals`).

### 6. Tear down

- [ ] Delete keys, archive projects, cancel batches and delete files, turn off auto-recharge -> `references/teardown.md`
- [ ] Verify with a request using the deleted key: expect `401 Unauthorized`.

### 7. Troubleshoot

- [ ] Symptom, cause, fix with the documented error strings -> `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: Cloud Console, organizations, projects, roles, API keys, env vars.
- `references/api-and-compat.md`: base URL, cURL and SDK examples, OpenAI compatibility differences, error classes and retries.
- `references/models-and-features.md`: model catalog and deprecations, reasoning, structured outputs, tool use, prompt caching, batch, service tiers, Dedicated Inference.
- `references/limits-and-quotas.md`: the dual-bucket limit model, tiers, free trial, project limits, usage monitoring.
- `references/litellm-and-clients.md`: LiteLLM `model_list`, OpenAI SDK and tool config.
- `references/teardown.md`: revoke keys, archive projects, batches and files, billing off-switches.
- `references/troubleshooting.md`: symptom to fix table.

## Companion skills

- `cloud-llms`: choose among providers and tiers, hybrid cloud plus local routing. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: one endpoint in front of Cerebras and other backends. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `litellm`: LiteLLM proxy configuration in depth. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `groq`, `together-ai`, `fireworks-ai`: other managed open-model APIs for fallbacks. Install: `npx skills add ScaleDockHQ/llms-skills --skill groq`.
- `llm-evals`: re-check quality when a model ID changes. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `llm-observability`: tracing and cost tracking for gateway traffic. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
- `self-hosted-llms` and `vllm`: run the same open model on your own GPUs. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
