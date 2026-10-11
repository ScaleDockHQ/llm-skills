# Modal vLLM

A stack recipe for a private, scale-to-zero, OpenAI-compatible LLM: vLLM on Modal (your own `@app.server` or a Dedicated Endpoint) behind a LiteLLM gateway that holds the proxy token, with timeouts, retries, a fallback and teardown. It links the `modal`, `vllm` and `litellm` skills instead of repeating them.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill modal-vllm
```

## Rules

- **Ask before billing.** State GPU, max containers, region and stop time first.
- **Private by default.** Never set `unauthenticated` without approval; require a proxy token.
- **Pin versions.** `modal`, `vllm` (from Modal's current example), CUDA image and model revision.
- **Keep secrets out of sight.** The gateway builds the proxy token in an environment variable; `HF_TOKEN` lives in a Modal Secret.
- **Retry through cold starts.** Expect 503 and set a long gateway timeout.
- **Always tear down.** Apps, Endpoints, Volumes, Secrets and tokens.

## References

- [`references/recipe.md`](references/recipe.md): Server or Endpoint, deploy and smoke test.
- [`references/gateway.md`](references/gateway.md): LiteLLM entry, proxy token, timeouts, fallback.
- [`references/operations.md`](references/operations.md): cost watching, updates, teardown.

## Companion skills

- `modal`: all Modal detail.
- `vllm`: engine flags and tuning.
- `litellm`: gateway install, keys, budgets.
- `llm-gateway`: gateway design.
- `choosing-hardware`: GPU sizing.
- `cloud-llms`: other providers and fallbacks.

## License

MIT
