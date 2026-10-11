# Nebius

Helps an agent run LLMs on Nebius: Token Factory (formerly AI Studio) for OpenAI-compatible inference, batch, fine-tuning and dedicated endpoints, and the `nebius` CLI for GPU VMs and Managed Kubernetes. Covers profiles and keys, quotas, LiteLLM wiring, cost and teardown.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill nebius
```

## Rules

- **Ask before creating billable resources.** VMs, node groups, dedicated endpoints and fine-tuning jobs cost money.
- **Secrets never touch output.** Keys come from `0600` files or `NEBIUS_API_KEY`; automation uses service-account key files.
- **Use project-scoped Token Factory keys.** Old AI Studio keys were scheduled to stop on January 31, 2026.
- **Stopped VMs still count toward quota.** Delete what you do not need.
- **Dedicated endpoints bill while their minimum replicas are reserved.**

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): CLI install, profiles, service accounts, keys.
- [`references/token-factory-api.md`](references/token-factory-api.md): inference, tools, embeddings, batch, files, fine-tuning.
- [`references/dedicated-endpoints.md`](references/dedicated-endpoints.md): dedicated endpoint control plane.
- [`references/vms-and-kubernetes.md`](references/vms-and-kubernetes.md): VMs and mk8s node groups.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM and OpenAI SDK.
- [`references/limits-and-billing.md`](references/limits-and-billing.md): limits, quotas, billing.
- [`references/teardown.md`](references/teardown.md): delete order.
- [`references/troubleshooting.md`](references/troubleshooting.md): errors and fixes.

## Companion skills

- `cloud-llms`: cross-provider workflow.
- `llm-gateway`: LiteLLM gateway.
- `self-hosted-llms`: vLLM on your VM or cluster.
- `choosing-llm-hosting`: pick where to host.
- `fine-tuning-llms`: data and training choices.
- `llm-evals`: quality and latency checks.
- `llm-observability`: traces and metrics.

## License

MIT
