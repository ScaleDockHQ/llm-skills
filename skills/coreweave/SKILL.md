---
name: coreweave
description: Run LLMs on CoreWeave, CKS managed Kubernetes GPU clusters and Node Pools, SUNK (Slurm on Kubernetes), Serverless Inference (api.inference.wandb.ai, W&B/Forge) and Dedicated Inference (gateways and deployments via the cwic CLI). Use for "CoreWeave", "CKS", "Node Pool", "cwic", "CW-SECRET token", "kubeconfig CoreWeave", "SUNK", "organization has no GPU quota", "Concurrency limit reached for requests", or wiring CoreWeave into LiteLLM. For cross-provider choice use cloud-llms, for the gateway llm-gateway, for generic Kubernetes serving and vLLM self-hosted-llms.
license: MIT
compatibility: Needs bash, curl, jq and kubectl; optional cwic CLI, Terraform and an S3-capable CLI. Requires a CoreWeave account, API access token or Forge API key kept in 0600 files or environment variables. Creating clusters, Node Pools, gateways, deployments or capacity claims bills money and needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# CoreWeave

Serve an LLM on CoreWeave with the right product, a working OpenAI-compatible endpoint, cost controls and a verified teardown. CoreWeave has three inference paths plus bare-metal Kubernetes and Slurm.

**Scope:** CoreWeave Kubernetes Service (CKS) clusters and Node Pools, SUNK, Serverless Inference, Dedicated Inference (bring your own weights), the `cwic` CLI and the CoreWeave API at `https://api.coreweave.com`. Out of scope: provider choice and cross-provider flow (`cloud-llms`), gateway features (`llm-gateway`), generic vLLM and Kubernetes serving patterns (`self-hosted-llms`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
command -v cwic kubectl terraform jq curl && cwic --version 2>/dev/null
env | cut -d= -f1 | grep -E '^(CW_|COREWEAVE_|KUBECONFIG|WANDB_)' || echo "no CoreWeave env vars"
cwic auth whoami 2>/dev/null || echo "cwic not logged in"
# only if a kubeconfig for CKS is already set up:
kubectl config current-context 2>/dev/null && kubectl get nodepool 2>/dev/null
# only if a token is exported (header read from env, never echoed):
[ -n "$CW_API_TOKEN" ] && curl -sS "${CW_BASE_URL:-https://api.coreweave.com}/v1alpha1/inference/gateways" -H "Authorization: Bearer $CW_API_TOKEN" | jq .
```

## Decision flow

1. Catalog open model, per-token billing, no GPUs to manage: Serverless Inference (`references/serverless-inference.md`). Needs a Forge API key.
2. Your own weights or a fine-tune, managed serving, OpenAI-compatible gateway: Dedicated Inference (`references/dedicated-inference.md`). Needs access enabled, GPU quota and weights in AI Object Storage. No scale-to-zero.
3. Full control of runtime and networking, or non-LLM pipelines: your own serving on CKS (`references/cks-gpu-clusters.md`).
4. Training and batch with Slurm: SUNK on CKS (`references/cks-gpu-clusters.md`).
5. Unsure: read `references/limits-and-billing.md`, then ask which trade-off matters (control, ops, price).

## Rules

- **Ask before creating billable resources.** Clusters, Node Pools, capacity claims, gateways and deployments cost money; show instance type, count, zone and minimum replicas, then wait.
- **Secrets never touch output.** API access tokens start with `CW-SECRET-`; keep them in `0600` files or env vars, not in manifests, and note that kubeconfig files embed a token, so treat them as secrets with `chmod 600`. Tokens expire; set expiry.
- **Do not install the NVIDIA GPU Operator on CKS.** CoreWeave manages it; installing conflicts and is unsupported.
- **Pin versions.** Pin the runtime engine version, the model path and the vLLM image.
- **Set budget controls before traffic.** Serverless has per-tier spending caps; Dedicated and CKS bill GPU hours with no documented hard cap, so use minimum replicas, `targetNodes` and a teardown schedule.
- **Dedicated Inference cannot scale to zero**, and managed capacity claims bill while they exist, even idle.
- **Always tear down.** Delete deployments before gateways, Node Pools before clusters; follow `references/teardown.md`.

## Workflows

### Account and auth

- [ ] Create an API access token (and kubeconfig for a cluster) with an expiry, or a Forge API key -> `references/setup-and-auth.md`
- [ ] Install and log in `cwic` -> `references/setup-and-auth.md`

### Call Serverless Inference

- [ ] Create a Forge key, list models, send a chat completion with the `OpenAI-Project` header -> `references/serverless-inference.md`

### Deploy on Dedicated Inference

- [ ] Check access, quota and role; upload weights; bucket policy -> `references/dedicated-inference.md`
- [ ] Create gateway, then deployment; wait for `STATUS_READY`; test -> `references/dedicated-inference.md`

### Deploy on CKS

- [ ] Create cluster, Node Pool, get kubeconfig, apply a vLLM manifest -> `references/cks-gpu-clusters.md`

### Connect to a gateway or client

- [ ] LiteLLM entries and OpenAI SDK settings for each path -> `references/litellm-and-clients.md`

### Scale, monitor cost, update

- [ ] Scale replicas or `targetNodes`; check spend and quotas -> `references/limits-and-billing.md`
- [ ] Update with a new deployment and traffic weights, not in place -> `references/dedicated-inference.md`

### Tear down

- [ ] Delete in dependency order and verify -> `references/teardown.md`

### Troubleshoot

- [ ] Match the error string -> `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: tokens, kubeconfig, `cwic`, Forge keys, IAM roles.
- `references/serverless-inference.md`: base URL, headers, models, limits, OpenAI client.
- `references/dedicated-inference.md`: gateways, deployments, engines, scaling, capacity claims.
- `references/cks-gpu-clusters.md`: CKS cluster, Node Pools, vLLM manifest, spot, SUNK.
- `references/litellm-and-clients.md`: LiteLLM entries, OpenAI SDK settings.
- `references/limits-and-billing.md`: quotas, caps, billing models, cost checks.
- `references/teardown.md`: delete order and verification.
- `references/troubleshooting.md`: error strings, causes, fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow, tiers, budgets. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM gateway, fallbacks, budgets. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `self-hosted-llms`: vLLM, engines, Kubernetes patterns. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `choosing-llm-hosting`: pick where to host. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`.
- `fine-tuning-llms`: produce weights for Dedicated Inference. Install: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`.
- `llm-evals`: verify quality and latency. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `llm-observability`: traces and metrics. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
