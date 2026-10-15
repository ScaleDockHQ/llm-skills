---
name: replicate
description: Replicate predictions API, Cog and deployments - run hosted models over HTTP or the replicate Python/Node clients, push your own with Cog, run always-on deployments, control spend and delete. Use for "Replicate", "replicate.run", "r8_" tokens, REPLICATE_API_TOKEN, "cog push", r8.im, prediction webhooks, cold boot, E6716 or E1001 errors. Now part of Cloudflare, brand and API unchanged. No OpenAI endpoint - use llm-gateway. Cloud comparisons - cloud-llms.
license: MIT
compatibility: macOS or Linux shell with curl and jq. Cog needs Docker and, for GPU builds, an NVIDIA-capable build path. Needs a Replicate account and an API token in a 0600 file or REPLICATE_API_TOKEN. Deployments, always-on instances and prepaid top-ups cost money and need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Replicate

Run models on Replicate through its predictions API, package your own with Cog, keep the bill bounded and delete what you stop using. Replicate joined Cloudflare in November 2025 and remains its own brand with an unchanged API.

**Scope:**

- In: API token, creating and polling predictions, webhooks, official and community models, deployments, Cog push, data retention, billing semantics, deletion, LiteLLM routing.
- Out: picking a provider (`cloud-llms`, `choosing-llm-hosting`), gateway config (`llm-gateway`), image and video model choice and local serving (`self-hosted-genmedia`), serving LLMs on your own GPUs (`self-hosted-llms`), evals (`llm-evals`).

Replicate documents no OpenAI-compatible chat endpoint. Do not claim one. Use LiteLLM's `replicate/` provider for chat models.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Print variable names only.

```bash
env | cut -d= -f1 | grep -iE '^REPLICATE' || echo "no REPLICATE_* vars"
command -v cog && cog --version
command -v replicate && replicate --version
pip show replicate 2>/dev/null | head -2
curl -sS https://api.replicate.com/v1/account -H "Authorization: Bearer $REPLICATE_API_TOKEN" | jq 'keys'
curl -sS https://api.replicate.com/v1/deployments -H "Authorization: Bearer $REPLICATE_API_TOKEN" | jq '.results | length'
```

Existing deployments with a minimum instance count above zero are billing around the clock. Report them first.

## Decision flow

1. A public model, bursty use: call the model by `owner/name`. Public models bill active time only, and a cold boot may take minutes.
2. Latency matters or you need your own capacity: create a deployment with `min_instances >= 1`. It bills setup, idle and active time.
3. Your own weights or code: package with Cog, push to `r8.im`, then deploy it.
4. Long jobs or many jobs: use webhooks with a verified signature, not a polling loop.
5. Chat through a gateway: `references/litellm-and-clients.md`.

## Rules

- **Ask before creating billable resources.** Deployments, private models, minimum instances above zero and credit top-ups need approval with the hardware and bounds shown.
- **Secrets never print.** The token starts with `r8_`. Keep it in a `0600` file or `REPLICATE_API_TOKEN`. Replicate auto-disables tokens leaked to GitHub.
- **Pin versions.** Community models need `owner/name:<version-id>`. Pin the Cog and client versions.
- **Spend controls before traffic.** Use prepaid credit with a low balance, cap `max_instances`, and send `Cancel-After` on requests (`references/billing-and-teardown.md`).
- **Mind data retention.** API inputs, outputs and files are deleted after an hour by default. Save outputs you need.
- **Always tear down.** Delete deployments, private models and versions you created, then verify.
- **Look prices up** on the model page or the pricing page. Do not store rates.

## Workflows

### 1. Account and auth

- [ ] Create a token at https://replicate.com/account/api-tokens. See `references/setup-and-auth.md`.

### 2. Call a model

- [ ] Choose the endpoint form for official, community or deployed models. See `references/predictions-api.md`.

### 3. Deploy

- [ ] Create or push a model, then a deployment with hardware and bounds, after approval. See `references/deployments-and-cog.md`.

### 4. Connect to LiteLLM

- [ ] Add a `replicate/` model entry. See `references/litellm-and-clients.md`.

### 5. Scale

- [ ] Patch `min_instances` and `max_instances`. See `references/deployments-and-cog.md`.

### 6. Monitor cost

- [ ] Use the billing page and account endpoints. See `references/billing-and-teardown.md`.

### 7. Update

- [ ] Push a new version, patch the deployment's version, verify, delete the old version.

### 8. Tear down

- [ ] Delete deployments (offline first), then versions, then models. See `references/billing-and-teardown.md`.

### 9. Troubleshoot

- [ ] Map the error in `references/troubleshooting.md`.

## Reference index

- `references/setup-and-auth.md`: token, clients, CLI, MCP.
- `references/predictions-api.md`: endpoints, headers, files, streaming, webhooks, retention.
- `references/deployments-and-cog.md`: deployments API, hardware, Cog push.
- `references/billing-and-teardown.md`: billing rules, rate limits, spend controls, deletion.
- `references/litellm-and-clients.md`: LiteLLM, Cloudflare AI Gateway, SDK use.
- `references/troubleshooting.md`: error codes and cold starts.

## Companion skills

- `cloud-llms`: compare Replicate with other cloud options. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM routing and budgets. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `self-hosted-genmedia`: run image, video and audio models on your own GPUs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `choosing-llm-hosting`: laptop, owned GPUs or cloud. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`.
- `llm-observability`: traces and cost. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
