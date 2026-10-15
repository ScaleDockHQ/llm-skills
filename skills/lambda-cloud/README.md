# Lambda Cloud

Helps an agent get an LLM running on Lambda Cloud GPU instances, 1-Click Clusters and filesystems through the Cloud API (`https://cloud.lambda.ai/api/v1`): pick a type and region from live capacity, launch, serve with vLLM, connect the box to a LiteLLM gateway or OpenAI client, control spend and tear everything down. It also records that Lambda's hosted Inference API was announced as sunset.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill lambda-cloud
```

## Rules

- **Ask before creating billable resources.** Instances, filesystems and cluster reservations bill; confirm type, region and count first.
- **Secrets never touch output.** The API key lives in a `0600` file or an environment variable and is never echoed or committed.
- **Terminate, do not shut down.** `shutdown` inside the VM keeps billing; use the API or console.
- **Filesystems attach only at launch** and bill until deleted.
- **Verify upstream.** Prices, capacity and limits come from live API calls and docs, not from memory.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): accounts, workspaces, API and SSH keys, auth header, rate limits.
- [`references/instances-api.md`](references/instances-api.md): instance types, images, launch, list, restart, terminate, firewall.
- [`references/serving-and-litellm.md`](references/serving-and-litellm.md): vLLM on an instance, exposure, OpenAI client, LiteLLM entry.
- [`references/storage-and-clusters.md`](references/storage-and-clusters.md): filesystems and 1-Click Clusters.
- [`references/limits-and-billing.md`](references/limits-and-billing.md): quotas, capacity, billing model, spend checks.
- [`references/teardown.md`](references/teardown.md): stop all billing and verify.
- [`references/troubleshooting.md`](references/troubleshooting.md): error codes, symptoms, Inference API sunset.

## Companion skills

- `cloud-llms`: cross-provider workflow and tiers.
- `llm-gateway`: LiteLLM gateway, fallbacks, budgets.
- `self-hosted-llms`: vLLM and engine tuning and hardening.
- `choosing-llm-hosting`: laptop vs owned GPU vs cloud.
- `llm-evals`: quality and speed checks.
- `llm-observability`: traces and metrics.

## License

MIT
