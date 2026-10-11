---
name: crusoe
description: Run LLMs on Crusoe Cloud, GPU VMs and Managed Kubernetes (CMK) through the crusoe CLI, plus Crusoe Managed Inference (Intelligence Foundry) with an OpenAI-compatible serverless API and self-serve dedicated deployments. Use for "Crusoe", "crusoe compute vms create", "crusoe kubernetes", "Managed Inference", "Intelligence Foundry", "CRUSOE_API_KEY", "bad_credential", quota or capacity errors on Crusoe, or Crusoe in LiteLLM (crusoe/ prefix). For cross-provider choice use cloud-llms, for the gateway llm-gateway, for vLLM self-hosted-llms.
license: MIT
compatibility: Needs bash, curl and jq; the crusoe CLI (optional kubectl) for VMs and Kubernetes. Requires a Crusoe account and project, a CLI access key in ~/.crusoe/config or an Intelligence API key in a 0600 file or env var. Creating VMs, clusters, node pools or deployments bills money and needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Crusoe

Run an LLM on Crusoe with the right surface: rent GPU VMs or Managed Kubernetes with the `crusoe` CLI, or use Managed Inference (serverless per token, or a self-serve dedicated deployment). Both come with cost controls and a verified teardown.

**Scope:** Crusoe Cloud CLI, compute VMs, disks, CMK (Managed Kubernetes), quotas, and Managed Inference / Intelligence Foundry. Out of scope: provider choice and cross-provider flow (`cloud-llms`), gateway (`llm-gateway`), vLLM and engines (`self-hosted-llms`), choosing hosting (`choosing-llm-hosting`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print keys.

```bash
command -v crusoe kubectl jq curl && crusoe --version 2>/dev/null
env | cut -d= -f1 | grep -i -E 'CRUSOE' || echo "no CRUSOE_* env var"
[ -f ~/.crusoe/config ] && echo "crusoe config present" || echo "no ~/.crusoe/config"
crusoe whoami 2>/dev/null || echo "crusoe CLI not configured"
crusoe compute vms list 2>/dev/null          # running VMs (these bill)
crusoe storage disks list 2>/dev/null        # disks bill even when detached
# managed inference reachability (key from env, never echoed)
[ -n "$CRUSOE_API_KEY" ] && curl -sS https://api.inference.crusoecloud.com/v1/models -H "Authorization: Bearer $CRUSOE_API_KEY" | jq -r '.data[:5][].id'
```

## Decision flow

1. Want a hosted model, per-token billing: Managed Inference serverless (`references/managed-inference.md`).
2. Need dedicated GPUs for one model without running servers: self-serve deployment (`references/managed-inference.md`).
3. Want your own engine on a GPU box: VM (`references/vms-and-cli.md`).
4. Several models, autoscaling, K8s tooling: CMK (`references/cmk-kubernetes.md`).
5. Unsure about quota or price: `references/limits-and-billing.md`.

## Rules

- **Ask before creating billable resources.** Show type, count, location and billing rule first.
- **Secrets never touch output.** The CLI keeps an access key in `~/.crusoe/config`; inference uses an Intelligence API key. Keys can contain `$`, so single-quote them in shell. Read from `0600` files or env vars.
- **Model names go stale.** Several hosted models have been deprecated; take ids from `GET /v1/models`, not from examples.
- **Persistent and shared disks bill even when detached.** Delete them explicitly.
- **A VM must be started after creation.** A stopped on-demand VM is not billed and does not count toward quota, but its persistent disks still bill.
- **Ephemeral GPU local disks are wiped on stop.**
- **Always tear down.** Follow `references/teardown.md`.

## Workflows

### Account and auth

- [ ] Install CLI, init config, create an Intelligence API key -> `references/setup-and-auth.md`

### VMs and disks

- [ ] List types and locations, create, start, stop, delete -> `references/vms-and-cli.md`

### Kubernetes

- [ ] Create a CMK cluster and node pool, get credentials -> `references/cmk-kubernetes.md`

### Managed Inference

- [ ] Serverless calls, tools, limits; self-serve deployments -> `references/managed-inference.md`

### Connect to a gateway or client

- [ ] LiteLLM `crusoe/` entries and SDK settings -> `references/litellm-and-clients.md`

### Limits, cost, quotas

- [ ] Rate limits, quota checks, billing behaviour -> `references/limits-and-billing.md`

### Tear down

- [ ] Delete deployments, node pools, clusters, VMs, disks; revoke keys -> `references/teardown.md`

### Troubleshoot

- [ ] Match the symptom -> `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: CLI install and config, Intelligence API keys.
- `references/vms-and-cli.md`: VM and disk lifecycle with the CLI.
- `references/cmk-kubernetes.md`: CMK clusters, add-ons, node pools.
- `references/managed-inference.md`: serverless API and self-serve deployments.
- `references/litellm-and-clients.md`: LiteLLM and OpenAI SDK configuration.
- `references/limits-and-billing.md`: rate limits, quotas, billing.
- `references/teardown.md`: delete order and verification.
- `references/troubleshooting.md`: errors and fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM gateway, fallbacks, budgets. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `self-hosted-llms`: vLLM and engines on your VM or cluster. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `choosing-llm-hosting`: where to host. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`.
- `fine-tuning-llms`: produce weights to deploy. Install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`.
- `llm-evals`: verify quality and speed. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `llm-observability`: traces and metrics. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
