---
name: google-vertex-ai
description: Use Google Cloud Vertex AI, renamed Gemini Enterprise Agent Platform in 2026, for Gemini, Claude and open Model Garden models via gcloud and ADC, the OpenAI-compatible endpoint, custom GPU endpoints, quotas, batch, private access and teardown. Use for Vertex AI, Agent Platform, aiplatform.googleapis.com, generateContent, rawPredict, gcloud ai, Resource exhausted 429, PERMISSION_DENIED on aiplatform, LiteLLM vertex_ai/. For cross-provider choices use cloud-llms, for gateways use llm-gateway.
license: MIT
compatibility: Needs gcloud, bash, curl and jq, plus network access to Google Cloud. Creating endpoints, enabling partner models, budgets, billing or project changes need the user's explicit approval. Works on macOS and Linux.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Google Vertex AI (Gemini Enterprise Agent Platform)

Call Gemini, Claude and open models on Google Cloud, or serve your own model on a managed GPU endpoint, behind Application Default Credentials, with budgets set before traffic and a verified teardown.

**Naming (verified 2026-10-11):** Google renamed Vertex AI to **Gemini Enterprise Agent Platform** ("Agent Platform"). It is a brand change: the API host (`aiplatform.googleapis.com`), the `gcloud ai` commands, model IDs and the `vertex_ai/` LiteLLM prefix are unchanged. Old docs, errors and tools still say "Vertex AI". Treat both names as the same product.

**Scope:** Agent Platform model APIs (Gemini, partner models such as Claude, open models as managed APIs), Model Garden self-deploy to endpoints, quotas and consumption options, batch inference, private access, data retention, cost controls, teardown.

Out of scope: choosing between clouds or tiers (`cloud-llms`, `choosing-llm-hosting`), gateway features (`llm-gateway`), the Gemini Developer API with an AI Studio key (a different product), the serving engine itself (`self-hosted-llms`), evals (`llm-evals`), tracing (`llm-observability`).

Work through the steps in order. Load a reference only when a step names it. Take flags and URLs from the references or the linked docs, never from memory.

## Discover first

Read-only. No command prints a secret.

```bash
command -v gcloud && gcloud --version | head -1
gcloud auth list --format='value(account,status)' 2>/dev/null
gcloud config list --format='value(core.account,core.project,ai.region)' 2>/dev/null
gcloud auth application-default print-access-token >/dev/null 2>&1 && echo "ADC: ok" || echo "ADC: missing"

P=$(gcloud config get-value project 2>/dev/null)
gcloud services list --enabled --project="$P" --filter='name:aiplatform.googleapis.com' --format='value(name)'
gcloud billing projects describe "$P" --format='value(billingEnabled)' 2>/dev/null

# Existing billable serving resources (replace region)
gcloud ai endpoints list --project="$P" --region=us-central1 2>/dev/null
gcloud ai models list --project="$P" --region=us-central1 2>/dev/null

# Env var NAMES only
env | cut -d= -f1 | grep -E '^(GOOGLE_|CLOUDSDK_|VERTEX|LITELLM)' | sort
```

Note: project, billing state, whether the API is on, any existing endpoints (they bill per replica-hour), and whether ADC works. Ask only for what is missing: workload, data residency, budget ceiling, whether a Gemini, Claude or open model is wanted.

## Decision flow

1. Gemini or another Google model, serverless: `references/api-and-models.md` (generateContent or the OpenAI-compatible endpoint).
2. Claude or Mistral through Agent Platform: partner model (MaaS); enable in Model Garden first (`references/api-and-models.md`).
3. Open model as a managed API (Llama, Qwen, DeepSeek, gpt-oss and others): MaaS chat-completions endpoint (`references/api-and-models.md`).
4. A model the APIs do not host, a fine-tune or custom weights: Model Garden deploy or your own container on an endpoint (`references/custom-endpoints.md`).
5. Offline bulk work: batch inference at a discount (`references/api-and-models.md`).
6. Traffic must stay private or data must not be retained: `references/private-access-and-data.md`.
7. Existing contract absent and only a quick test needed: the cheaper path may be a direct provider API (`cloud-llms`).

## Rules

- **Ask before creating billable resources.** Endpoints, Provisioned Throughput orders, batch jobs, partner-model enablement, budgets and billing changes need approval and an undo path.
- **Prefer ADC and service-account impersonation over key files.** Never download service-account keys into repos or images. API keys are for testing only.
- **Secrets never touch output.** Tokens come from `gcloud auth print-access-token` inline in a header or from env vars or `0600` files. Never echo them or put them in config.
- **Budget alerts and quota check before traffic.** A Cloud Billing budget only alerts; it does not cap spend (`references/limits-and-budgets.md`).
- **Pin model IDs.** Use explicit versions, not aliases such as `latest`, in anything serving users; track retirement notices.
- **Pick the location on purpose.** `global` routes for capacity; a region or multi-region keeps residency. Do not use `global` for regulated data.
- **Always tear down.** An endpoint with a deployed model bills while idle. Undeploy, delete, verify (`references/teardown-and-troubleshooting.md`).
- **Verify upstream.** Docs move fast and the platform was just renamed; re-read the linked page before relying on a flag.

## Workflows

### Set up a project and auth

- [ ] Project with billing, Agent Platform API enabled, `roles/aiplatform.user` granted -> `references/setup-and-auth.md`
- [ ] `gcloud auth application-default login` (or impersonation / Workload Identity Federation for CI)
- [ ] Verify: the `generateContent` curl in `references/api-and-models.md` returns text.

### Call a model

- [ ] Choose Gemini, Claude or open MaaS -> `references/api-and-models.md`
- [ ] Use the global endpoint and retry 429s with truncated exponential backoff
- [ ] Verify: response has content and `usageMetadata` (or `usage`).

### Connect to the gateway and OpenAI clients

- [ ] LiteLLM `vertex_ai/<model>` with `vertex_project` and `vertex_location`, or OpenAI SDK against `endpoints/openapi` -> `references/litellm-and-clients.md`
- [ ] Mind the one-hour OpenAI-compat token: refresh programmatically.
- [ ] Verify: alias answers through the gateway `/v1/chat/completions`.

### Deploy a custom or open model

- [ ] Check GPU quota and pick accelerator -> `references/limits-and-budgets.md`
- [ ] `gcloud ai model-garden models deploy` or `deploy-model` -> `references/custom-endpoints.md`
- [ ] Test `/chat/completions` on the endpoint, then add to the gateway.
- [ ] Verify: describe shows the deployed model; note replica minimum (bills per hour).

### Scale and control cost

- [ ] Move steady load to Provisioned Throughput only when measured; use Priority PayGo for steadier performance -> `references/limits-and-budgets.md`
- [ ] Batch offline work; request quota early.
- [ ] Budget with Pub/Sub notifications; optional kill-switch (`references/limits-and-budgets.md`).

### Go private

- [ ] Private Service Connect for Google APIs plus VPC Service Controls, or dedicated PSC endpoints -> `references/private-access-and-data.md`

### Update

- [ ] Deploy the new version beside the old, split traffic (`--traffic-split`), then undeploy the old one -> `references/custom-endpoints.md`

### Tear down

- [ ] Undeploy, delete endpoints and models, cancel batch jobs, remove budgets or disable billing -> `references/teardown-and-troubleshooting.md`
- [ ] Verify: `gcloud ai endpoints list` empty in every region used.

### Troubleshoot

- [ ] Symptom table: 429 `Resource exhausted`, 403, 404 model not found, token expiry -> `references/teardown-and-troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: rename, project setup, ADC, impersonation, roles, API keys, locations.
- `references/api-and-models.md`: Gemini generateContent, OpenAI-compatible endpoint, Claude rawPredict, open MaaS, batch.
- `references/custom-endpoints.md`: Model Garden deploy, `gcloud ai endpoints`, dedicated endpoints, calling them, traffic split.
- `references/limits-and-budgets.md`: Cloud Quotas, consumption options (PayGo tiers, Priority, Provisioned), 429 handling, budgets and kill-switch.
- `references/private-access-and-data.md`: PSC, VPC Service Controls, residency, zero data retention, caching, logging.
- `references/litellm-and-clients.md`: LiteLLM entries, OpenAI SDK, Anthropic SDK and gateway notes.
- `references/teardown-and-troubleshooting.md`: exact teardown commands and error table.

## Companion skills

- `cloud-llms`: cross-provider cloud workflow and cost framework. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: one endpoint, keys, routing and fallbacks. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `choosing-llm-hosting`: decide cloud vs local vs owned GPUs. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`.
- `self-hosted-llms`: the serving stack for custom endpoints. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `llm-evals`: compare models before committing. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `llm-observability`: tracing and cost dashboards. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
