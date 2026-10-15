---
name: groq
description: Use GroqCloud for fast open-model inference - OpenAI-compatible chat, Responses API, tools, structured outputs, batch, flex tier, LoRA. Use when asked about Groq, GroqCloud, api.groq.com, GROQ_API_KEY, console.groq.com, `groq/` LiteLLM models, service_tier, `blocked_api_access`, 429 or 498 `capacity_exceeded`, Groq batch jobs, spend limits, or ZDR and data controls. Groq has no dedicated-GPU product to deploy. For cross-provider choice use cloud-llms or choosing-llm-hosting.
license: MIT
compatibility: Any OS with bash, curl and jq. No official Groq CLI exists in the docs; use curl or the groq and OpenAI SDKs. Needs a Groq API key in an env var or 0600 file. Batch, flex and spend limits need a paid plan; LoRA and Prometheus metrics need Enterprise. Ask before enabling paid features.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Groq

Call open models on GroqCloud through its OpenAI-compatible API, use batch and flex processing, set organization spend limits and model permissions, wire it into clients and a LiteLLM gateway, and clean up files, batches and keys.

**Scope:** the GroqCloud API platform: chat, Responses API, speech, tools, structured outputs, service tiers, Batch API and Files API, LoRA inference (Enterprise), projects, spend limits, data controls. There are no self-serve dedicated deployments or CLI to tear down; the cleanup is files, batches, fine-tunes and keys. Out of scope: cross-provider choice (`cloud-llms`), gateway design (`llm-gateway`), self-hosted engines (`self-hosted-llms`).

Work through the steps in order. Load a reference only when a step names it. Docs were read on 2026-10-11; Groq's model list changes often, so list models from the API instead of trusting examples.

## Discover first

Every command is read-only and never prints a secret.

```bash
env | cut -d= -f1 | grep -iE 'groq|openai_(api|base)'

# Does the key work, and which models can it call (key stays in the header)
curl -s https://api.groq.com/openai/v1/models -H "Authorization: Bearer $GROQ_API_KEY" | jq -r '.data[].id'

# Resources that persist or bill
curl -s https://api.groq.com/openai/v1/batches -H "Authorization: Bearer $GROQ_API_KEY" | jq -r '.data[]? | [.id,.status] | @tsv'
curl -s https://api.groq.com/openai/v1/files   -H "Authorization: Bearer $GROQ_API_KEY" | jq -r '.data[]? | [.id,.purpose,.filename] | @tsv'
curl -s https://api.groq.com/v1/fine_tunings   -H "Authorization: Bearer $GROQ_API_KEY" | jq .
```

Current rate limits and the spend limit are console pages: https://console.groq.com/settings/limits and https://console.groq.com/settings/billing/limits. Response headers `x-ratelimit-*` show remaining capacity on each call.

## Decision flow

1. Interactive or agent traffic, low latency: `on_demand` tier (default). See `references/api-and-features.md`.
2. High throughput that tolerates occasional failures: `service_tier: "flex"` (paid, higher limits, may return 498 `capacity_exceeded`) or `"auto"`.
3. Offline bulk work, higher limits, discounted: Batch API. See `references/batch-and-lora.md`.
4. Fine-tuned behavior: Groq runs pre-made LoRA adapters only (Enterprise); it does not fine-tune. Train elsewhere (`fine-tuning-llms`). See `references/batch-and-lora.md`.
5. Need dedicated GPUs, a model Groq does not host, or custom serving: Groq is not the tool; see `choosing-llm-hosting` and `self-hosted-llms`.
6. Always set the spend limit and project structure before traffic: `references/limits-and-spend.md`.

## Rules

- **Ask before creating billable or retained resources.** Batches, files, LoRA adapters and plan upgrades need approval. Batch input and output files are retained for 30 days unless deleted.
- **Secrets never touch output.** Read `GROQ_API_KEY` from the environment or a 0600 file. Never print or commit it.
- **Pin versions.** Pin model IDs (they get retired and renamed) and SDK versions; keep a fallback alias.
- **Budget controls before traffic.** Set a monthly spend limit on a paid plan. It is organization-wide, not per key, and spend updates lag 10 to 15 minutes.
- **Use projects.** One project and key per environment or workload gives separate rate limits, keys and visibility.
- **Verify features per model.** Strict structured outputs, prompt caching, parallel tool use and built-in tools differ by model; check the model page.
- **Always clean up.** Delete batch files, fine-tunes you no longer need and unused keys; verify by listing.

## Workflows

### Account and key setup

- [ ] Create a key at https://console.groq.com/keys inside the right project. Save to a 0600 file. -> `references/setup-and-auth.md`
- [ ] Upgrade to a paid plan only with approval (needed for batch, flex, spend limits).
- [ ] Verify: the models call above returns IDs.

### Call the API

- [ ] OpenAI SDK with `base_url="https://api.groq.com/openai/v1"` or the `groq` SDK. -> `references/api-and-features.md`
- [ ] Choose a tier with `service_tier`; add tools or `response_format` json_schema.

### Batch

- [ ] JSONL, upload with `purpose=batch`, create with `completion_window`, poll, download, delete files. -> `references/batch-and-lora.md`

### Connect to LiteLLM and clients

- [ ] `groq/<model>` with `GROQ_API_KEY`. -> `references/litellm-and-clients.md`

### Limits, spend and cost

- [ ] Set the monthly limit and alerts; review model permissions. -> `references/limits-and-spend.md`

### Tear down

- [ ] Follow `references/teardown.md`: batches, files, fine-tunes, keys, spend backstop.

### Troubleshoot

- [ ] `references/troubleshooting.md` (400 `blocked_api_access`, 429 headers, 498, 403 model blocked).

## Reference index

- `references/setup-and-auth.md`: console, projects, keys, roles, SDKs.
- `references/api-and-features.md`: OpenAI compatibility, Responses API, service tiers, tools, structured outputs, reasoning, caching.
- `references/batch-and-lora.md`: Batch and Files APIs, LoRA inference and the fine-tunings API.
- `references/limits-and-spend.md`: rate limits and headers, spend limits, model permissions, data controls.
- `references/litellm-and-clients.md`: LiteLLM entries and SDK configuration.
- `references/teardown.md`: cleaning up files, batches, fine-tunes and keys.
- `references/troubleshooting.md`: symptoms, causes and fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow and cost model. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM-style gateway, fallbacks and budgets. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `llm-evals`: check quality against your current model. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `llm-observability`: traces and per-request cost. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
- `llm-clients`: SDK and client wiring. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-clients`.
- `fine-tuning-llms`: train adapters before uploading them. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `choosing-llm-hosting` and `self-hosted-llms`: when you need GPUs you control. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`.
