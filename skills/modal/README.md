# Modal

Helps an agent run LLMs on Modal's serverless GPUs: deploy a vLLM Server with `@app.server`, create managed Shared or Dedicated Endpoints, protect them with proxy auth tokens, cache weights in Volumes, scale with `max_containers`, connect through OpenAI-compatible clients and LiteLLM, control spend, and stop everything when done. It covers the `modal` CLI and Python SDK and the common error codes.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill modal
```

## Rules

- **Ask before billing.** Deploys, GPU runs, Dedicated Endpoints and warm containers cost money; get approval first.
- **Keep secrets out of sight.** Tokens come from `0600` files, stdin or environment variables and are never printed.
- **Stay private.** Keep proxy auth on; never publish an endpoint without approval.
- **Pin versions.** Pin `modal`, `vllm`, the CUDA image and the model revision.
- **Cap spend first.** Set `max_containers`, a short `scaledown_window` and a workspace budget before traffic.
- **Always tear down.** Stop apps and Endpoints, delete Volumes and tokens, and verify.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): install, tokens, environments, Secrets.
- [`references/vllm-server.md`](references/vllm-server.md): `@app.server` vLLM, deploy, rollback, web functions.
- [`references/endpoints.md`](references/endpoints.md): Shared and Dedicated Endpoints, proxy tokens, client integrations.
- [`references/scaling-and-volumes.md`](references/scaling-and-volumes.md): autoscaling, cold starts, GPUs, Volumes, budgets.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM entries and client setup.
- [`references/teardown.md`](references/teardown.md): stop every billable resource and verify.
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
