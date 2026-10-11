# Runpod Serverless vLLM

A stack recipe for a scale-to-zero, OpenAI-compatible LLM endpoint: vLLM (worker-vllm) on Runpod Serverless behind a LiteLLM gateway, with spend caps, cold-start handling and teardown. It links the `runpod`, `vllm` and `litellm` skills instead of repeating them.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill runpod-serverless-vllm
```

## Rules

- **Ask before billing.** State GPU, max workers, model and stop time first.
- **Cap workers before traffic.** `--workers-max` is the spend cap; keep active workers at 0.
- **Pin versions.** worker-vllm release tag and model revision, never `latest`.
- **Keep secrets out of sight.** Restricted key from a `0600` file; `HF_TOKEN` as a Runpod secret.
- **Long gateway timeout.** The first request after idle waits for a cold start.
- **Always tear down.** Endpoint, template and volumes.

## References

- [`references/recipe.md`](references/recipe.md): deploy and smoke test.
- [`references/gateway.md`](references/gateway.md): LiteLLM entry, timeouts, fallback.
- [`references/operations.md`](references/operations.md): cost watching, updates, teardown.

## Companion skills

- `runpod`: all Runpod detail.
- `vllm`: engine flags and tuning.
- `litellm`: gateway install, keys, budgets.
- `llm-gateway`: gateway design.
- `choosing-hardware`: GPU sizing.
- `cloud-llms`: other providers and fallbacks.

## License

MIT
