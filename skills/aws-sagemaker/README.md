# Amazon SageMaker AI

Helps an agent host your own LLM on Amazon SageMaker AI in your AWS account: deploy JumpStart or Hugging Face models with AWS LMI (vLLM) containers to real-time, asynchronous or inference-component endpoints, scale idle capacity to zero, call endpoints with SigV4 or through LiteLLM, control cost, and delete the endpoint, endpoint config and model afterwards. It uses the `aws sagemaker` and `aws sagemaker-runtime` CLIs for discovery.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill aws-sagemaker
```

## Rules

- **Ask before billing.** Endpoints bill per instance-hour until deleted; state instance type, count and a stop time first.
- **Keep secrets out of sight.** Use IAM roles; read `HF_TOKEN` from a secret store or `0600` file and never print it.
- **Pin versions.** Pin the LMI container tag and model revision; never `latest`.
- **Check quota and budget first.** GPU instance quotas are often zero; set an AWS Budget.
- **Always tear down.** Delete endpoint, endpoint config, model, inference components, autoscaling targets and alarms, then verify in every Region.

## References

- [`references/setup-and-auth.md`](references/setup-and-auth.md): roles, quotas, naming, discovery commands.
- [`references/deploy-llm.md`](references/deploy-llm.md): JumpStart, LMI environment variables, CLI and SDK deploy flows, invocation.
- [`references/scaling-and-cost.md`](references/scaling-and-cost.md): endpoint types, autoscaling, scale to zero, async, serverless limits, budgets.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM `sagemaker_chat/` and `sagemaker/` routes, boto3 invocation.
- [`references/teardown.md`](references/teardown.md): delete every billable resource and verify.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom, cause and fix table.

## Companion skills

- `cloud-llms`: compare providers and set up hybrid cloud routing.
- `llm-gateway`: one authenticated endpoint with keys, budgets and fallbacks.
- `aws-bedrock`: hosted models in the same AWS account.
- `vllm`: engine flags behind the LMI container.
- `choosing-llm-hosting`: decide between local, owned servers and cloud.
- `self-hosted-llms`: run the same stack on your own GPU server.
- `model-quantization`: fit larger models on smaller instances.
- `fine-tuning-llms`: produce the weights you deploy.
- `llm-observability`: trace requests, cost and latency.
- `llm-evals`: compare models before switching.

## License

MIT
