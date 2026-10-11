# Sentry AI monitoring: privacy and sampling

> Verified against Sentry docs "Data Privacy", "Sampling Strategies" and "Naming Your Agents", 2026-10-11

## Decide first

Spans can carry prompts, tool arguments and responses. On Sentry SaaS that is third-party storage. Decide in writing: content on or off, which projects, who can read, how long (retention periods were not verified here).

## Controls, strongest first

1. **Default is metadata only.** With `send_default_pii=False` (Python) or `sendDefaultPii: false` (JS), only model names, token counts, tool names and timings are collected. `True` captures full inputs, outputs, prompts and responses.
2. **Per integration.** Python `OpenAIIntegration(include_prompts=False)` (also `LiteLLMIntegration`) keeps content out even with `send_default_pii=True`, which lets you keep other PII on. JS uses `recordInputs` and `recordOutputs`.
3. **Collector stripping** for OTel: `assets/otel-collector.yaml` deletes `gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`, `gen_ai.tool.call.arguments` and `gen_ai.tool.call.result`.
4. **Server-side scrubbing.** Sentry's built-in data scrubbing catches common patterns (card numbers, SSNs, passwords) in most event data, but these span attributes are not protected by default: `gen_ai.input.messages`, `gen_ai.tool.call.arguments`, `gen_ai.tool.call.result`, `gen_ai.output.messages`, `gen_ai.response.object`. Add an Advanced Data Scrubbing rule at project or organization level targeting `$span.data.'<attribute>'` for each one you need.
5. **LiteLLM exceptions:** `turn_off_message_logging: true` keeps messages out of Sentry events.
6. **Self-host Sentry** if data may not leave your network (`references/setup-and-sdks.md`). Closed-source AI features such as Seer are unavailable there.

Send opaque user ids to `set_user`, not emails; the Conversations User column shows whatever fields exist.

## Sampling

Sentry uses head-based sampling: the decision is made at the root span and every child span, including `gen_ai.*`, inherits it. A 10 percent rate loses 90 percent of agent runs entirely, so sample agent traffic at 100 percent.

```python
def traces_sampler(ctx):
    tx = ctx.get("transaction_context", {})
    attrs = tx.get("data") or {}
    name = tx.get("name", "")
    if attrs.get("gen_ai.operation.name"):
        return 1.0                                   # standalone agent runs
    if tx.get("op") == "http.server" and any(p in name for p in ["/api/chat", "/api/agent"]):
        return 1.0                                   # routes that serve AI features
    parent = ctx.get("parent_sampled")
    if parent is not None:
        return float(parent)
    return 0.2

sentry_sdk.init(dsn=os.environ["SENTRY_DSN"], traces_sampler=traces_sampler)
```

Replace the route names with yours. If 100 percent is not possible, add custom metrics (`Sentry.metrics.distribution("gen_ai.token_usage", ...)`) and structured logs on every LLM call, which are independent of trace sampling.

## Canary test

Send a request containing `CANARY-<random>`, open the span in Explore, Traces, and confirm the string is absent from the input, output and tool attributes.
