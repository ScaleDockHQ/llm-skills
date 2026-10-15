---
name: nebius
description: Run LLMs on Nebius, GPU VMs and Managed Kubernetes (mk8s) through the nebius CLI, plus Nebius Token Factory (formerly AI Studio) for OpenAI-compatible inference, batch, fine-tuning and dedicated endpoints at api.tokenfactory.nebius.com. Use for "Nebius", "nebius compute instance create", "nebius mk8s", "Token Factory", "AI Studio", "NEBIUS_API_KEY", "dedicated endpoint", quota or capacity errors on Nebius, or wiring Nebius into LiteLLM (nebius/ prefix). For cross-provider choice use cloud-llms, for the gateway llm-gateway, for engines and vLLM self-hosted-llms.
license: MIT
compatibility: Needs bash, curl and jq; the nebius CLI (optional kubectl) for VMs and Kubernetes. Requires a Nebius account, project, and a Token Factory API key or CLI profile, kept in 0600 files or environment variables. Creating VMs, clusters, node groups, dedicated endpoints or fine-tuning jobs bills money and needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Nebius

Run an LLM on Nebius with the right surface: rent GPU VMs or Kubernetes with the `nebius` CLI, or call Token Factory's managed OpenAI-compatible API. Both come with cost controls and a verified teardown.

**Scope:** Nebius AI Cloud CLI (`nebius`), Compute VMs, Managed Service for Kubernetes (mk8s), quotas, and Nebius Token Factory (the new name for Nebius AI Studio): serverless inference, batch, fine-tuning, files, dedicated endpoints. Out of scope: provider choice and cross-provider flow (`cloud-llms`), gateway (`llm-gateway`), vLLM and engine tuning (`self-hosted-llms`), picking hosting (`choosing-llm-hosting`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print keys.

```bash
command -v nebius kubectl jq curl && nebius version 2>/dev/null
env | cut -d= -f1 | grep -i -E 'NEBIUS' || echo "no NEBIUS_* env var"
nebius iam whoami 2>/dev/null || echo "nebius CLI not configured"
nebius profile list 2>/dev/null
# running VMs and clusters in the profile's project (these bill)
nebius compute instance list 2>/dev/null
nebius mk8s cluster list 2>/dev/null
# Token Factory reachability (key from env, never echoed)
[ -n "$NEBIUS_API_KEY" ] && curl -sS https://api.tokenfactory.nebius.com/v1/models -H "Authorization: Bearer $NEBIUS_API_KEY" | jq -r '.data[:5][].id'
```

## Decision flow

1. Want a hosted model, per-token billing, no GPUs to run: Token Factory serverless (`references/token-factory-api.md`).
2. Need dedicated capacity, a region choice or custom weights without running servers: Token Factory dedicated endpoints (`references/dedicated-endpoints.md`).
3. Want your own engine on a GPU box: Compute VM (`references/vms-and-kubernetes.md`).
4. Several models, autoscaling, K8s tooling: Managed Kubernetes node group (`references/vms-and-kubernetes.md`).
5. Unsure about price or quota: `references/limits-and-billing.md`.

## Rules

- **Ask before creating billable resources.** VMs, node groups, dedicated endpoints and fine-tuning jobs bill; show platform, preset, count, region and minimum replicas first.
- **Secrets never touch output.** Token Factory keys come from a `0600` file or `NEBIUS_API_KEY`; the CLI profile for automation uses a service account with `--private-key-file`, not pasted keys. Keys are shown once at creation.
- **Use project-scoped keys.** Old AI Studio keys were scheduled to stop working on January 31, 2026; create one key per project and tool.
- **One CLI profile per project.** Region-specific config is tied to the project.
- **Pin versions.** Pin the model id, image family, Kubernetes version and driver preset.
- **Quota counts stopped VMs.** Delete VMs you do not need instead of stopping them.
- **Dedicated endpoints bill per GPU-hour while enabled.** Disable or delete when idle; disabling releases capacity and it may not come back.
- **Always tear down.** Follow `references/teardown.md`.

## Workflows

### Account and auth

- [ ] Install `nebius`, create a profile for the project -> `references/setup-and-auth.md`
- [ ] Create a Token Factory API key in the right project -> `references/setup-and-auth.md`

### Call Token Factory

- [ ] List models, call chat completions, use tools, JSON schema, batch -> `references/token-factory-api.md`

### Dedicated endpoint

- [ ] List templates, create endpoint, wait, call with `routing_key` -> `references/dedicated-endpoints.md`

### GPU VM or Kubernetes

- [ ] List platforms and quotas, create VM or mk8s cluster and node group -> `references/vms-and-kubernetes.md`

### Connect to a gateway or client

- [ ] LiteLLM `nebius/` entries and OpenAI SDK settings -> `references/litellm-and-clients.md`

### Scale, monitor cost, update

- [ ] Replicas, node counts, quota checks, usage view -> `references/limits-and-billing.md`

### Tear down

- [ ] Delete endpoints, node groups, clusters, VMs, disks; revoke keys -> `references/teardown.md`

### Troubleshoot

- [ ] Match the symptom -> `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: CLI install and profiles, service accounts, Token Factory keys, AI Studio rename.
- `references/token-factory-api.md`: base URL, models, chat, tools, structured output, embeddings, batch, files, fine-tuning.
- `references/dedicated-endpoints.md`: control plane API, templates, scaling, stop, delete.
- `references/vms-and-kubernetes.md`: platforms, VM create, mk8s cluster and GPU node groups.
- `references/litellm-and-clients.md`: LiteLLM and OpenAI SDK configuration.
- `references/limits-and-billing.md`: rate limits, quotas, reservations, billing.
- `references/teardown.md`: delete order and verification.
- `references/troubleshooting.md`: errors and fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM gateway, fallbacks, budgets. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `self-hosted-llms`: vLLM and engines on your VM or cluster. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `choosing-llm-hosting`: where to host. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`.
- `fine-tuning-llms`: data and training choices. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `llm-evals`: verify quality and speed. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `llm-observability`: traces and metrics. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
