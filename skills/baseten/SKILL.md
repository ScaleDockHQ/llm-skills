---
name: baseten
description: Baseten model APIs and dedicated GPU deployments - call hosted models over OpenAI or Anthropic-style endpoints, or deploy your own with the baseten CLI and Truss (config.yaml, vLLM or Engine-Builder), scale, monitor cost and tear down. Use for "Baseten", "Truss", "truss push", BASETEN_API_KEY, inference.baseten.co, model-xxxx.api.baseten.co, scale to zero, "model version is deactivated". Not for other hosts (use cloud-llms) or gateway config (use llm-gateway).
license: MIT
compatibility: macOS or Linux shell with curl and jq; the baseten CLI (Homebrew) or truss (uv or pip) for deploys. Needs a Baseten account and API key in a 0600 file or BASETEN_API_KEY. Deploying, scaling above zero and training bill by the minute and need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Baseten

Get a model answering through Baseten, either from the hosted Model APIs or from a dedicated deployment you own, connect it to an OpenAI-compatible client or LiteLLM, keep the bill bounded, and delete what you stop using.

**Scope:**

- In: Baseten account and API keys, Model APIs (pay per token), dedicated deployments with `config.yaml`, autoscaling, deactivate and delete, cost lookup, LiteLLM wiring.
- Out: choosing among providers (`cloud-llms`, `choosing-llm-hosting`), gateway routing and budgets (`llm-gateway`), engine tuning on your own GPUs (`self-hosted-llms`), evals (`llm-evals`), training and fine-tuning theory (`fine-tuning-llms`). Baseten Training, Chains and Sandboxes exist, but this skill does not cover them.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Environment variable names only.

```bash
env | cut -d= -f1 | grep -iE '^BASETEN' || echo "no BASETEN_* vars"
command -v baseten && baseten --version
command -v truss && truss --version
ls -l ~/.trussrc 2>/dev/null                 # expect 0600; never cat it
baseten model list 2>&1 | head -20            # needs auth; lists deployed models
baseten org billing usage 2>&1 | head -20     # last 7 days by default
```

Anything listed under `model list` with replicas up is billing. Report it first.

## Decision flow

1. A hosted open model is enough, no custom weights: Model APIs. No deployment, pay per token (`references/model-apis.md`).
2. Custom weights, private model, fixed capacity or dedicated GPUs: a dedicated deployment (`references/dedicated-deploy.md`).
3. Standard LLM on a known engine: Engine-Builder config. Anything else with an OpenAI-compatible server: a custom Docker server config running vLLM or SGLang.
4. Spiky traffic: scale to zero, accept cold starts. Latency-sensitive: keep at least one replica.
5. Calls from a gateway: `references/litellm-and-clients.md`.

## Rules

- **Ask before creating billable resources.** A dedicated deploy, a replica floor above zero and any GPU change cost money. Show the config, the instance type and the scaling bounds, then wait for approval.
- **Secrets never print.** Keys come from `0600` files or environment variables. Use `baseten auth login` or `BASETEN_API_KEY`. Never `cat ~/.trussrc`.
- **Pin versions.** Pin the base image tag, the Hugging Face revision (`hf://org/model@<sha>`) and the Truss version.
- **Set spend controls before traffic.** A monthly budget with emails, "Enforce budget" for Model APIs, and a replica ceiling. Enforce budget does not stop dedicated deployments (`references/lifecycle-and-teardown.md`).
- **Prefer scoped keys.** Use an inference-only key for apps, not a personal or manage-all key.
- **Always tear down.** Deactivate or delete every deployment you created, then verify with `baseten model list`.
- **Look prices up.** Rates and limits change. Use the CLI, the pricing page and instance-type reference named in the references.

## Workflows

### 1. Account and auth

- [ ] Install the CLI, log in, create a scoped key. See `references/setup-and-auth.md`.

### 2. Call a Model API

- [ ] `baseten model-api list` for what is live, then call `https://inference.baseten.co/v1/chat/completions`. See `references/model-apis.md`.

### 3. Deploy a dedicated model

- [ ] Write `config.yaml`, get approval, run `baseten model push` (or `truss push`), wait for the build and read the logs. See `references/dedicated-deploy.md`.

### 4. Connect to LiteLLM or OpenAI clients

- [ ] Use the `baseten/` LiteLLM provider or an `openai/` entry with the deployment base URL. See `references/litellm-and-clients.md`.

### 5. Scale

- [ ] Set min and max replicas, concurrency target and scale-down delay. Check concurrency on a load test. See `references/lifecycle-and-teardown.md`.

### 6. Monitor cost

- [ ] `baseten org billing usage` and `baseten model-api usage`. See `references/lifecycle-and-teardown.md`.

### 7. Update

- [ ] Push a new deployment, promote it to the environment, keep the old one until traffic is verified, then deactivate it.

### 8. Tear down

- [ ] Deactivate (keeps the config, stops compute) or delete. A model's only or environment-attached deployment cannot be deleted. Delete the model instead. See `references/lifecycle-and-teardown.md`.

### 9. Troubleshoot

- [ ] Map the HTTP status or message in `references/troubleshooting.md`.

## Reference index

- `references/setup-and-auth.md`: CLI install, login, key types, headers, MCP and agent skills.
- `references/model-apis.md`: hosted endpoints, discovery, limits, budgets, usage.
- `references/dedicated-deploy.md`: `config.yaml` examples, push, endpoints, resources, secrets.
- `references/lifecycle-and-teardown.md`: autoscaling, promote, deactivate, delete, billing semantics.
- `references/litellm-and-clients.md`: LiteLLM, OpenAI and Anthropic SDK wiring.
- `references/troubleshooting.md`: status codes and deploy errors.

## Companion skills

- `cloud-llms`: compare Baseten with other hosted and cloud options. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM routing, fallbacks and budgets. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `self-hosted-llms`: vLLM and SGLang flags that also apply in a Baseten Docker server. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `llm-observability`: traces and cost dashboards. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
- `llm-evals`: check a deployed model before shifting traffic. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `llm-clients`: point apps and agents at the endpoint. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`.
