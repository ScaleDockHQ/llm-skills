# Hugging Face

Helps an agent work with Hugging Face: manage tokens and the local cache, download and upload models with the `hf` CLI, call Inference Providers through the OpenAI-compatible router, and create, scale, pause and delete Inference Endpoints. Spaces and Jobs are covered briefly.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill hugging-face
```

## Rules

- **Ask before billable resources.** Endpoints, Spaces hardware, Jobs, credits.
- **Never print tokens.** Use `HF_TOKEN` or a `0600` file; prefer fine-grained tokens.
- **Pin revisions and images.** Branches and `latest` move.
- **Scale-to-zero is not off.** It still counts against quota and returns 502 while waking.
- **Always tear down.** Pause or delete endpoints, cancel Jobs, pause Spaces, prune the cache.

## References

- [`references/hub-cli-and-tokens.md`](references/hub-cli-and-tokens.md): `hf` CLI, tokens, download, upload, cache.
- [`references/inference-providers.md`](references/inference-providers.md): router, provider policies, billing routes.
- [`references/inference-endpoints.md`](references/inference-endpoints.md): deploy, status, scale, pause, delete.
- [`references/spaces-and-jobs.md`](references/spaces-and-jobs.md): Spaces and Jobs lifecycle.
- [`references/limits-and-billing.md`](references/limits-and-billing.md): credits, quotas, spend visibility.
- [`references/litellm-and-clients.md`](references/litellm-and-clients.md): LiteLLM and OpenAI clients.
- [`references/teardown.md`](references/teardown.md): stop and delete.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

- `cloud-llms`, `choosing-llm-hosting`: choose where to run.
- `llm-gateway`, `litellm`: gateway in front of Hugging Face.
- `self-hosted-llms`, `vllm`: serve downloaded weights yourself.
- `fine-tuning-llms`, `model-quantization`: produce and shrink weights.
- `llm-evals`, `llm-observability`: quality and cost.
- `local-llms`: laptop inference.

## License

MIT
