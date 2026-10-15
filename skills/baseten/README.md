# Baseten

Helps an agent use Baseten: call hosted Model APIs (OpenAI Chat Completions and Anthropic Messages), deploy dedicated models with the `baseten` CLI and Truss (Engine-Builder or a vLLM Docker server), connect them to LiteLLM, control scale and cost, and tear everything down. It does not cover Baseten Training, Chains or Sandboxes.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill baseten
```

## Rules

- **Ask before creating billable resources.** Deploys, replica floors and GPU changes need approval.
- **Secrets never print.** Keys come from `0600` files or environment variables. Never `cat ~/.trussrc`.
- **Pin versions.** Base image tags, Hugging Face revisions and the Truss version.
- **Spend controls before traffic.** Monthly budget, replica ceiling. Enforce budget covers Model APIs only.
- **Prefer inference-only keys** in apps and gateways.
- **Always tear down.** Deactivate or delete what you created and verify.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): CLI install, login, key types, headers.
- [`references/model-apis.md`](references/model-apis.md): hosted endpoints, limits, budgets, usage.
- [`references/dedicated-deploy.md`](references/dedicated-deploy.md): `config.yaml` examples, push, endpoints.
- [`references/lifecycle-and-teardown.md`](references/lifecycle-and-teardown.md): autoscaling, promote, deactivate, delete, billing.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM, OpenAI and Anthropic SDKs.
- [`references/troubleshooting.md`](references/troubleshooting.md): status codes and deploy errors.

## Companion skills

- `cloud-llms`: compare Baseten with other options.
- `llm-gateway`: LiteLLM routing, fallbacks and budgets.
- `self-hosted-llms`: vLLM and SGLang flags and sizing.
- `llm-observability`: traces and cost.
- `llm-evals`: check a model before shifting traffic.
- `llm-clients`: point apps and agents at the endpoint.

## License

MIT
