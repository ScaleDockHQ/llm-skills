# Vast.ai

Helps an agent rent GPUs on the Vast.ai marketplace to serve LLMs: search offers with the `vastai` CLI, create instances running vLLM, set up Serverless endpoints and workergroups, call them through the OpenAI proxy or LiteLLM, understand marketplace billing and security, and destroy everything when done.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill vast-ai
```

## Rules

- **Ask before billing.** Instances, endpoints, volumes and bids cost money; get approval first.
- **Keep secrets out of sight.** The API key comes from a `0600` file or an env var and is never printed; use scoped keys.
- **Treat hosts as untrusted.** No credentials or sensitive data on rented machines; prefer verified or Secure Cloud offers.
- **Pin versions.** No `latest` images; pin vLLM and model revisions.
- **Destroy, do not stop.** Stopped instances still bill for storage; only destroy ends all billing.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): account, CLI, API keys and scoped permissions.
- [`references/instances.md`](references/instances.md): offers, instances, ports, volumes, lifecycle.
- [`references/serverless.md`](references/serverless.md): endpoints, workergroups, worker billing, OpenAI proxy.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries and client setup.
- [`references/limits-and-costs.md`](references/limits-and-costs.md): billing, instance types, limits, security.
- [`references/teardown.md`](references/teardown.md): destroy every billable resource and verify.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom, cause and fix table.

## Companion skills

- `cloud-llms`: compare providers and set up hybrid cloud routing.
- `llm-gateway`: one authenticated endpoint with keys, budgets and fallbacks.
- `choosing-llm-hosting`: decide between local, owned servers and cloud.
- `self-hosted-llms`: run the same stack on your own GPU server.
- `llm-clients`: connect editors and apps to the endpoint.
- `vllm`: engine flags and tuning.

## License

MIT
