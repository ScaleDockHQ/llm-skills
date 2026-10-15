---
name: fireworks-ai
description: Use Fireworks AI for open-model APIs - serverless chat, tool calling, structured outputs, batch, fine-tuning, on-demand GPU deployments. Use when asked about Fireworks, api.fireworks.ai, FIREWORKS_API_KEY, firectl, `accounts/fireworks/models/...`, firectl deployment create, deployment shapes, Fireworks batch or LoRA/SFT jobs, `fireworks_ai/` LiteLLM models, spend limit or 429/503 errors, or deleting Fireworks deployments. For cross-provider choice use cloud-llms or choosing-llm-hosting.
license: MIT
compatibility: Any OS with bash, curl and jq. The `firectl` CLI (Homebrew or direct download) is optional but needed for deployments, batch, datasets and training. Needs a Fireworks API key in an env var or 0600 file. Creating deployments, jobs or reservations bills the account, so ask the user first.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Fireworks AI

Call open models on Fireworks AI through its OpenAI- and Anthropic-compatible API, run on-demand GPU deployments with `firectl`, use batch and fine-tuning, wire it into clients and a LiteLLM gateway, set spend limits, and tear down every billable resource.

**Scope:** the Fireworks platform: serverless inference, on-demand deployments, Batch API, supervised fine-tuning and LoRA deployment, API keys, quotas and spend limits, cleanup. Out of scope: cross-provider choice (`cloud-llms`), gateway design (`llm-gateway`), self-hosted engines (`self-hosted-llms`), training methodology (`fine-tuning-llms`). Fireworks Nexus (FireConnect, FireRouter) is newer; read https://docs.fireworks.ai/nexus before advising on it.

Work through the steps in order. Load a reference only when a step names it. Docs were read on 2026-10-11; re-check flags with `firectl <command> --help`.

## Discover first

Every command is read-only and never prints a secret.

```bash
command -v firectl && firectl version        # deployment shapes need firectl 1.8.8 or newer
env | cut -d= -f1 | grep -iE 'fireworks|openai_(api|base)'
firectl whoami                                # identity and account
firectl account get
firectl quota list                            # rate limits, GPU quotas, spend limit, usage

# What exists and may bill
firectl deployment list
firectl batch-inference-job list
firectl supervised-fine-tuning-job list
firectl model list                            # your models and LoRAs
firectl api-key list

# Serverless catalog (key stays in the header)
curl -s https://api.fireworks.ai/v1/accounts/fireworks/models -H "Authorization: Bearer $FIREWORKS_API_KEY" | jq -r '.. | .name? // empty' | head
```

If `deployment list` shows deployments you did not create, stop and ask before touching them.

## Decision flow

1. Variable or small traffic, model validation: serverless. Per-token billing, nothing to delete. See `references/serverless-api.md`.
2. Offline bulk work: Batch API, discounted on serverless prices. See `references/batch-and-finetuning.md`.
3. Steady traffic, a model not on serverless, or fine-tuned models: on-demand deployments, billed by GPU-second. See `references/deployments.md`.
4. Reliability under peak load without owning GPUs: Priority tier or reserved throughput. See `references/serverless-api.md` and `references/limits-and-spend.md`.
5. Custom behavior: supervised fine-tuning, then deploy. See `references/batch-and-finetuning.md`.
6. Always set guardrails first: `references/limits-and-spend.md`.

## Rules

- **Ask before creating billable resources.** Deployments, batch jobs, training jobs, reservations and credit purchases need approval, with the delete or stop command stated up front.
- **Secrets never touch output.** Read `FIREWORKS_API_KEY` from the environment or a 0600 file. Do not `echo` it or pass it as a literal on the command line. `firectl` also reads `~/.fireworks/auth.ini`.
- **Pin versions.** Pin model IDs (`accounts/fireworks/models/<name>`), `firectl` and the SDK. The Python SDK is documented as alpha (`pip install --pre fireworks-ai`).
- **Budget controls before traffic.** Set the monthly spend limit (`firectl quota update monthly-spend-usd --value <USD>`) and use scale-to-zero on every deployment. Reaching the limit pauses all API usage.
- **Always pass a deployment shape.** `--deployment-shape default` (or a matched shape). Shapeless deployments fail more often.
- **Always tear down.** Deployments scale to zero when idle but are only auto-deleted after 7 days of no traffic; delete them yourself and verify with `firectl deployment list`.
- **Verify upstream.** Prices, GPU quotas and limits change. Read https://fireworks.ai/pricing and `firectl quota list` instead of quoting numbers.

## Workflows

### Account and key setup

- [ ] Create an API key in the dashboard or `firectl api-key create --key-name <name> --expire-time <YYYY-MM-DD>`; prefer service accounts for CI. -> `references/setup-and-auth.md`
- [ ] Install `firectl`, run `firectl signin`, then `firectl whoami`.
- [ ] Verify: the models call above returns names.

### Call serverless

- [ ] Use the OpenAI SDK with base URL `https://api.fireworks.ai/inference/v1` or the Anthropic SDK with `https://api.fireworks.ai/inference`. -> `references/serverless-api.md`
- [ ] Add tools or `response_format` json_schema; always put the schema in the prompt too.

### Deploy on demand

- [ ] Get approval, then `firectl deployment create accounts/fireworks/models/<model> --deployment-shape default --min-replica-count 0 --max-replica-count 1 --scale-to-zero-window 5m --wait`. -> `references/deployments.md`
- [ ] Query with the deployment-qualified model string; retry on 503 while it scales from zero.

### Connect to LiteLLM and clients

- [ ] LiteLLM: `fireworks_ai/accounts/fireworks/models/<model>` with `FIREWORKS_AI_API_KEY`. -> `references/litellm-and-clients.md`

### Batch and fine-tune

- [ ] Batch: create dataset, `firectl batch-inference-job create`, download the output dataset. -> `references/batch-and-finetuning.md`
- [ ] Fine-tune: `firectl sftj create`, deploy the output model, delete when done.

### Scale and monitor cost

- [ ] Tune `--load-targets`, windows and replica bounds. -> `references/deployments.md`
- [ ] Review spend, quotas and tiers. -> `references/limits-and-spend.md`

### Tear down

- [ ] Follow `references/teardown.md`: deployments, batch jobs, training jobs, datasets, models, keys.

### Troubleshoot

- [ ] `references/troubleshooting.md` (429 vs 503, scale-from-zero, quota, spend limit pause).

## Reference index

- `references/setup-and-auth.md`: keys, service accounts, `firectl` install and auth, roles.
- `references/serverless-api.md`: OpenAI and Anthropic compatibility, tools, structured outputs, service tiers, data handling.
- `references/deployments.md`: shapes, `firectl deployment`, autoscaling, preemptible, LoRA hosting, reservations.
- `references/batch-and-finetuning.md`: Batch API, datasets, SFT jobs and deploying results.
- `references/limits-and-spend.md`: adaptive rate limits, tiers, monthly spend limit, GPU quotas.
- `references/litellm-and-clients.md`: LiteLLM entries and SDK configuration.
- `references/teardown.md`: deleting and stopping everything that bills, key revocation, verification.
- `references/troubleshooting.md`: symptoms, causes and fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow and cost model. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM-style gateway, fallbacks and budgets. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `fine-tuning-llms`: data and method choices before paying for training. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `llm-evals`: compare Fireworks models with your current one. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `llm-observability`: traces and per-request cost. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
- `llm-clients`: SDK and client wiring. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-clients`.
- `choosing-llm-hosting` and `self-hosted-llms`: when to move off a managed API. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`.
