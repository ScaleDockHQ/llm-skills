# Amazon Bedrock

Helps an agent call LLMs through Amazon Bedrock in your own AWS account: grant model access, choose between `bedrock-runtime` and `bedrock-mantle`, use Converse, InvokeModel, OpenAI-compatible and Anthropic-compatible APIs, handle inference profiles and cross-Region residency, set up API keys, IAM and VPC endpoints, run batch inference and Custom Model Import, read quotas, connect LiteLLM and tear everything down. It uses the `aws` CLI for read-only discovery.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill aws-bedrock
```

## Rules

- **Ask before billing.** First use of a third-party model subscribes the account; batch jobs, Provisioned Throughput and imports cost money.
- **Keep secrets out of sight.** Prefer IAM roles and short-term keys; read any key from a `0600` file or environment variable and never print it.
- **Pin IDs and Regions.** Use exact model or profile IDs, and verify cross-Region destinations when residency matters.
- **Set quota and budget checks first.** Read applied quotas, set an AWS Budget, cap `max_tokens`.
- **Always tear down.** Delete API keys, Provisioned Throughput, imported models, application profiles and VPC endpoints, then verify.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): model access, IAM actions, API keys, CLI discovery.
- [`references/endpoints-and-apis.md`](references/endpoints-and-apis.md): endpoint and API choice, curl and SDK examples, feature gaps.
- [`references/inference-profiles.md`](references/inference-profiles.md): geographic vs global cross-Region profiles, application profiles, model lifecycle.
- [`references/batch-and-customization.md`](references/batch-and-customization.md): batch inference, Custom Model Import, Provisioned Throughput.
- [`references/limits-and-security.md`](references/limits-and-security.md): quotas, budgets, VPC endpoints, data path.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM routes, OpenAI and Anthropic SDK settings.
- [`references/teardown.md`](references/teardown.md): delete every billable or exposed resource and verify.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom, cause and fix table.

## Companion skills

- `cloud-llms`: compare providers and set up hybrid cloud routing.
- `llm-gateway`: one authenticated endpoint with keys, budgets and fallbacks.
- `aws-sagemaker`: host your own model on SageMaker endpoints.
- `choosing-llm-hosting`: decide between local, owned servers and cloud.
- `self-hosted-llms`: run the same stack on your own GPU server.
- `llm-clients`: connect editors and apps to the endpoint.
- `llm-observability`: trace requests, cost and latency.
- `llm-evals`: compare models before switching.
- `fine-tuning-llms`: produce the weights you may import.

## License

MIT
