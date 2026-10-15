# Crusoe

Helps an agent run LLMs on Crusoe Cloud: GPU VMs and Managed Kubernetes (CMK) with the `crusoe` CLI, and Managed Inference (Intelligence Foundry) for OpenAI-compatible serverless calls and self-serve dedicated deployments. Covers keys, quotas, LiteLLM wiring, cost and teardown.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill crusoe
```

## Rules

- **Ask before creating billable resources.**
- **Secrets never touch output.** Single-quote keys that contain `$`; keep keys in `0600` files or env vars.
- **Take model ids from `/v1/models`.** Several models have been deprecated.
- **Persistent disks bill when detached;** stopped VMs do not bill.
- **Delete node pools before clusters.**

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): CLI and API keys.
- [`references/vms-and-cli.md`](references/vms-and-cli.md): VMs and disks.
- [`references/cmk-kubernetes.md`](references/cmk-kubernetes.md): CMK clusters and node pools.
- [`references/managed-inference.md`](references/managed-inference.md): serverless and self-serve deployments.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM and SDKs.
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
