# Runpod

Helps an agent run LLMs on Runpod: rent a GPU Pod, deploy a Serverless vLLM endpoint (worker-vllm or a load-balancing endpoint), manage network volumes, call it through OpenAI-compatible APIs and LiteLLM, control spend, and tear everything down. It covers `runpodctl`, API keys and secrets, the REST v1 retirement and the common error strings.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill runpod
```

## Rules

- **Ask before billing.** Pods, endpoints, volumes and active workers cost money; get approval first.
- **Keep secrets out of sight.** Keys come from `0600` files or environment variables and are never printed. Use a Restricted API key.
- **Pin versions.** No `latest` images; pin worker-vllm, vLLM and model revisions.
- **Set budget controls first.** Check the spend limit, cap `max workers`, keep active workers at 0 unless needed.
- **Always tear down.** Stopped Pods and idle network volumes still bill; verify nothing accrues.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): account, API keys, secrets, runpodctl, REST v1/v2 and GraphQL status.
- [`references/pods.md`](references/pods.md): Pods, storage types, vLLM on a Pod, proxy URLs, network volumes.
- [`references/serverless-vllm.md`](references/serverless-vllm.md): worker-vllm, load-balancing endpoints, scaling defaults, cached models.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): calling endpoints, rate limits, LiteLLM and client setup.
- [`references/limits-and-costs.md`](references/limits-and-costs.md): billing model, spend controls, platform limits.
- [`references/teardown.md`](references/teardown.md): delete every billable resource and verify.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom, cause and fix table.

## Companion skills

- `cloud-llms`: compare providers and set up hybrid cloud routing.
- `llm-gateway`: one authenticated endpoint with keys, budgets and fallbacks.
- `choosing-llm-hosting`: decide between local, owned servers and cloud.
- `self-hosted-llms`: run the same stack on your own GPU server.
- `llm-clients`: connect editors and apps to the endpoint.
- `llm-observability`: trace requests, cost and latency.
- `vllm`: engine flags and tuning.

## License

MIT
