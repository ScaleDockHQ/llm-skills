---
name: together-ai
description: Use Together AI for open-model APIs - serverless chat, tools, JSON, batch, fine-tuning, dedicated endpoints. Use when asked about Together AI, api.together.ai, TOGETHER_API_KEY, the `tg` or `together` CLI, `tg beta endpoints deploy`, Together dedicated model inference, Together batch or fine-tune jobs, `together_ai/` LiteLLM models, 429/503, endpoints_v1_create_access_disabled, or tearing down billable Together resources. For cross-provider choice use cloud-llms or choosing-llm-hosting.
license: MIT
compatibility: Any OS with bash, curl and jq. The `tg` CLI (Python, installed with uv) is optional. Needs a Together API key in an env var or a 0600 file. Creating dedicated endpoints, fine-tune jobs, batches or clusters bills the account, so ask the user first.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Together AI

Call open models on Together AI through its OpenAI-compatible API, run dedicated model inference (DMI), batch jobs and fine-tunes, wire it into clients and a LiteLLM gateway, and tear down everything that bills.

**Scope:** the Together AI platform: serverless API, dedicated endpoints and deployments, batch, fine-tuning, projects and API keys, spend controls, cleanup. Out of scope: choosing a provider across clouds (`cloud-llms`), gateway design (`llm-gateway`), running models on your own GPUs (`self-hosted-llms`), training methodology (`fine-tuning-llms`).

Work through the steps in order. Load a reference only when a step names it. Docs were read on 2026-10-11; Together's docs change often, so re-check a command with `tg <command> --help` before relying on a flag.

## Discover first

Every command is read-only and never prints a secret.

```bash
# CLI and SDK
command -v tg && tg --version          # dedicated-endpoint commands need 2.24.0 or later
python3 -c 'import together,sys; print(together.__version__)' 2>/dev/null

# Which key variables exist (names only)
env | cut -d= -f1 | grep -iE 'together|openai_(api|base)'

# Identity and project (the CLI asks for a project when it cannot prompt)
tg whoami

# What already exists and may bill
tg beta endpoints ls
tg batches list 2>/dev/null
tg fine-tuning list 2>/dev/null
tg files list 2>/dev/null

# Serverless catalog; the key stays in the header, never echoed
curl -s https://api.together.ai/v1/models -H "Authorization: Bearer $TOGETHER_API_KEY" | jq -r '.. | .id? // empty' | head
```

If `tg beta endpoints ls` shows endpoints you did not create, stop and ask before touching them.

## Decision flow

1. Variable, bursty or small traffic, or model validation: use the serverless API. Per-token billing, no resources to delete. See `references/serverless-api.md`.
2. Offline, non-urgent bulk work: use the Batch API (separate rate-limit pool, discounted on selected models). See `references/batch-and-finetuning.md`.
3. Steady traffic, a latency or throughput target, a model not served serverless, or a fine-tuned model: use dedicated model inference. It bills per minute per ready replica. See `references/dedicated-inference.md`.
4. Need a custom model: fine-tune a supported base (LoRA by default), then deploy it on DMI. See `references/batch-and-finetuning.md`.
5. Large training or custom workloads on reserved GPUs: Together also sells GPU clusters and container deployments. They are out of depth here; treat them as billable and read the linked docs in `references/teardown.md`.
6. Always set the account guardrails before traffic: `references/limits-and-spend.md`.

## Rules

- **Ask before creating billable resources.** Dedicated deployments, fine-tune jobs, batches, GPU clusters and credit purchases need explicit approval, with the stop command stated up front.
- **Secrets never touch output.** Read `TOGETHER_API_KEY` from the environment or a 0600 file. Never `echo` it, put it in a URL, or commit it. Keys are shown once at creation.
- **Pin versions.** Pin model IDs (they are namespaced, for example `org/model-name`), the SDK (`together>=2.x`) and the CLI. OpenAI model names such as `gpt-4o` return 404.
- **Budget controls before traffic.** Together has prepaid balance cut-off and cost analytics, but per-key limits and project budgets are not available. Use a separate project and key per workload.
- **Always tear down.** Dedicated endpoints bill per minute while replicas run, even idle. Set `--inactive-timeout` and delete when done. Verify with `tg beta endpoints ls`.
- **Check the right base URL.** Serverless and the management APIs use `https://api.together.ai/v1`. Dedicated endpoints serve inference at `https://api-inference.together.ai/v1` with the endpoint string as `model`.
- **Verify upstream.** Prices, hardware, limits and model lists change. Read the pricing page or CLI output instead of quoting numbers.

## Workflows

### Account and key setup

- [ ] Create an API key in a project (API keys settings), name it by workload, set an expiry for test keys. Save it to a 0600 file or secrets manager. -> `references/setup-and-auth.md`
- [ ] Install the CLI if needed (`uv tool install "together[cli]"`) and run `tg whoami`.
- [ ] Verify: the `/v1/models` call above returns IDs.

### Call the serverless API

- [ ] Pick a model ID from `/v1/models`, call chat completions with the OpenAI SDK or the `together` SDK. -> `references/serverless-api.md`
- [ ] Add streaming, tools or `response_format` as needed; test with your real schemas.
- [ ] Verify: `usage` is returned and the model ID is the one you pinned.

### Deploy a dedicated endpoint

- [ ] Get approval, then `tg beta endpoints deploy <model> --endpoint <name> --min-replicas 1 --max-replicas 1 --inactive-timeout 60`. -> `references/dedicated-inference.md`
- [ ] Poll `tg beta endpoints get <endpoint>` until `DEPLOYMENT_STATE_READY`.
- [ ] Call `https://api-inference.together.ai/v1` with `model` set to the endpoint string (`<project_slug>/<endpoint_name>`).

### Connect to the LiteLLM gateway and clients

- [ ] Serverless: `together_ai/<model>` with `TOGETHERAI_API_KEY`. Dedicated: `openai/<endpoint string>` with `api_base`. -> `references/litellm-and-clients.md`
- [ ] Verify: one request through the gateway shows up in cost tracking.

### Batch and fine-tune

- [ ] Batch: prepare JSONL, `tg batches submit`, poll, download output and error files within 7 days. -> `references/batch-and-finetuning.md`
- [ ] Fine-tune: upload, wait for file processing, create job, deploy the result on DMI, then delete the endpoint.

### Scale, monitor cost

- [ ] Autoscale on `inflight_requests` (default) or a latency metric; keep `--min-replicas` honest. -> `references/dedicated-inference.md`
- [ ] Use cost analytics grouped by project and API key. -> `references/limits-and-spend.md`

### Tear down

- [ ] Follow `references/teardown.md`: endpoints, batches, fine-tune jobs, files, then revoke keys. Verify nothing still runs.

### Troubleshoot

- [ ] Symptom to fix table in `references/troubleshooting.md` (429, 503, 404 model, GPU quota, v1 endpoint errors).

## Reference index

- `references/setup-and-auth.md`: projects, API keys, CLI install, SDKs, identity checks.
- `references/serverless-api.md`: OpenAI compatibility, endpoints, streaming, tools, structured outputs, reasoning fields.
- `references/dedicated-inference.md`: endpoints and deployments, profiles, autoscaling, idle shutdown, requests, v1 to v2 migration.
- `references/batch-and-finetuning.md`: Batch API, Files API, fine-tuning lifecycle and deployment.
- `references/limits-and-spend.md`: rate limits, spend controls, cost analytics, GPU quota.
- `references/litellm-and-clients.md`: LiteLLM entries, OpenAI SDK, `together` SDK.
- `references/teardown.md`: stopping and deleting every billable resource, key revocation, verification.
- `references/troubleshooting.md`: symptoms, causes and fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow and cost model. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM-style gateway, fallbacks and budgets. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `fine-tuning-llms`: dataset and training choices before you pay for a job. Install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`.
- `llm-evals`: compare the Together model with your current one. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `llm-observability`: traces and cost per request. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
- `llm-clients`: SDK and client wiring. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`.
- `choosing-llm-hosting` and `self-hosted-llms`: when to leave a managed API. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`.
