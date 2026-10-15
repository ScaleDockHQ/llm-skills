# CoreWeave

Helps an agent run LLMs on CoreWeave: choose between Serverless Inference (per-token, OpenAI-compatible), Dedicated Inference (your weights behind a gateway, managed with `cwic`) and your own serving on CKS managed Kubernetes, with SUNK for Slurm. Covers tokens and kubeconfig, deploy flows, LiteLLM wiring, quotas, cost and teardown.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill coreweave
```

## Rules

- **Ask before creating billable resources.** Clusters, Node Pools, capacity claims, gateways and deployments cost money.
- **Secrets never touch output.** `CW-SECRET-` tokens, kubeconfigs (they embed a token) and Forge keys stay in `0600` files or env vars.
- **Never install the NVIDIA GPU Operator on CKS.** CoreWeave manages it.
- **Dedicated Inference cannot scale to zero**, and managed capacity claims bill while idle.
- **Tear down in order.** Deployments before gateways, Node Pools before clusters.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): tokens, kubeconfig, `cwic`, Forge keys, IAM roles.
- [`references/serverless-inference.md`](references/serverless-inference.md): base URL, headers, models, limits.
- [`references/dedicated-inference.md`](references/dedicated-inference.md): gateways, deployments, scaling, capacity claims.
- [`references/cks-gpu-clusters.md`](references/cks-gpu-clusters.md): CKS, Node Pools, vLLM manifest, spot, SUNK.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries and OpenAI SDK settings.
- [`references/limits-and-billing.md`](references/limits-and-billing.md): quotas, caps, billing, spend checks.
- [`references/teardown.md`](references/teardown.md): delete order and verification.
- [`references/troubleshooting.md`](references/troubleshooting.md): error strings, causes, fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow.
- `llm-gateway`: LiteLLM gateway.
- `self-hosted-llms`: vLLM and Kubernetes serving.
- `choosing-llm-hosting`: pick where to host.
- `fine-tuning-llms`: produce weights to deploy.
- `llm-evals`: quality and latency checks.
- `llm-observability`: traces and metrics.

## License

MIT
