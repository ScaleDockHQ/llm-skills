# Hyperbolic

Helps an agent rent, use and tear down Hyperbolic GPUs (on-demand, spot and reserved virtual machines and bare metal) to self-host LLMs, and wire the box into a LiteLLM gateway. It also records that Hyperbolic's serverless inference API and playground are retired, so old `api.hyperbolic.xyz` inference code needs a different provider.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill hyperbolic
```

## Rules

- **Ask before creating billable resources.** Rentals, reservations, volumes and auto top-up need an explicit yes.
- **Secrets never print.** The API key lives in a `0600` file or an environment variable.
- **Check the balance and hourly rate first.** Rentals end when the balance is no longer positive.
- **Pin engine images and model revisions.** Do not touch the preinstalled GPU drivers.
- **Onboard NVMe is scratch.** Keep weights and checkpoints on a volume or object storage.
- **Always tear down.** Terminate, remove gateway entries, delete unused volumes, verify the active list is empty.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): account tiers, API key, SSH keys, hosts and auth header.
- [`references/rentals-api.md`](references/rentals-api.md): v2 endpoints, create-rental fields, spot and reserved.
- [`references/serving-and-gateway.md`](references/serving-and-gateway.md): serving on the box and the LiteLLM entry.
- [`references/billing-and-teardown.md`](references/billing-and-teardown.md): billing rules, spend control, terminate and verify.
- [`references/inference-retired.md`](references/inference-retired.md): the retired serverless API and migration paths.
- [`references/troubleshooting.md`](references/troubleshooting.md): connection, instance, API and billing failures.

## Companion skills

- `cloud-llms`: hosted APIs and other cloud tiers.
- `llm-gateway`: LiteLLM in front of the rented box.
- `self-hosted-llms`: vLLM, SGLang and sizing on a GPU server.
- `choosing-llm-hosting`: pick between laptop, owned GPUs and cloud.
- `llm-observability`: traces and spend.

## License

MIT
