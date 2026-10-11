# Weave

An agent skill for tracing and evaluating LLM apps and agents with W&B Weave. It covers `weave.init` and ops, tracing self-hosted OpenAI-compatible endpoints (vLLM, llama.cpp, Ollama) and LiteLLM, OTLP with a validated OpenTelemetry Collector, the LiteLLM `weave_otel` callback, PII and key redaction, evaluations, the hosting options (Cloud, Dedicated, Self-Managed), SDK updates and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill weave
```

## Rules

- **Ask before sending data off the machine.** Weave Cloud is third-party hosting.
- **Secrets never touch output.** `WANDB_API_KEY` in `0600` files only.
- **Content capture is a decision.** Redact, post-process or strip before real traffic.
- **OTLP is HTTP protobuf**, with `wandb-api-key` and `wandb.entity`/`wandb.project`.
- **Pin the SDK**; PyPI is ahead of the GitHub releases page.
- **Verify upstream.** Docs now live on docs.coreweave.com.

## References

- [`references/hosting-and-auth.md`](references/hosting-and-auth.md): Cloud, Dedicated, Self-Managed, keys.
- [`references/tracing-and-integrations.md`](references/tracing-and-integrations.md): init, ops, local endpoints, settings.
- [`references/otlp-and-gateways.md`](references/otlp-and-gateways.md): OTLP, Collector, LiteLLM proxy.
- [`references/privacy.md`](references/privacy.md): redaction and content control.
- [`references/evaluations.md`](references/evaluations.md): evaluations and scorers.
- [`references/updating.md`](references/updating.md): versions and deprecations.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-proxy.md`](references/combos/litellm-proxy.md): LiteLLM proxy into Weave.

**Templates and scripts:** [`assets/otel-collector.yaml`](assets/otel-collector.yaml), [`assets/litellm-weave.yaml`](assets/litellm-weave.yaml), [`scripts/check.sh`](scripts/check.sh).

## Upstream credits

- [Weave](https://github.com/wandb/weave) by Weights & Biases (Apache-2.0).

## Companion skills

- `llm-observability`: choosing a stack, metrics, gateway logging.
- `langfuse`: self-hostable alternative.
- `litellm`: gateway that exports to Weave.
- `llm-evals`: eval methodology.

## License

MIT
