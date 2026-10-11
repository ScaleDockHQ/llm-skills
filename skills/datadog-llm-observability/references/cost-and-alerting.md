# Datadog Agent Observability: cost, metrics and alerting

> Verified against Datadog Agent Observability docs (Cost, Agent Observability Metrics, Evaluations), 2026-10-11

## Cost for self-hosted models

Datadog estimates cost per LLM span from token counts and public provider pricing, for text models from supported providers (the docs cite 800+ models via the `pydantic/genai-prices` list). A locally served model has no public price, so supply cost yourself ("manual"). Cost values are in dollars; Datadog stores the metrics in nanodollars.

```python
from ddtrace.llmobs import LLMObs
LLMObs.annotate(metrics={"input_tokens": 120, "output_tokens": 80, "input_cost": 0.0, "output_cost": 0.0})
```

Rules from the docs: supply the full token breakdown when cache is used (`non_cached_input_tokens`, `cache_read_input_tokens`, `cache_write_input_tokens`; input and total are inferred when all parts are present); if you give only some cost fields Datadog estimates the rest, which can disagree with your numbers. Use `0` for sunk-cost hardware, or an amortized per-token figure.

## Break spend down

Promote bounded span tags to cost and token metrics with the `cost_tags` argument (Python) or `costTags` (Node) on `annotate`, for example `team`, `customer_tier`, `feature`. Do not use user ids or request ids; high-cardinality values are truncated or dropped. Then graph `ml_obs.span.llm.total.cost` grouped by that tag.

## Metrics for dashboards and monitors

`ml_obs.span`, `ml_obs.span.duration` and `ml_obs.span.error` (tags `env`, `error`, `ml_app`, `model_name`, `model_provider`, `service`, `span_kind`, `version`), and token distributions such as `ml_obs.span.llm.input.tokens`, `.output.tokens`, `.total.tokens`, `.input.cache_read.tokens`, plus cost metrics. Metrics are kept 15 months. Only the listed tags are available on them.

## Alerting

Create ordinary Datadog metric monitors on `ml_obs.*`:

- Error rate: `ml_obs.span.error` over `ml_obs.span` by `ml_app`.
- Latency: a percentile of `ml_obs.span.duration` for `span_kind:llm`.
- Spend: `ml_obs.span.llm.total.cost` over a window, by `team`.
- Volume drop: `ml_obs.span` below a floor, to catch a stopped pipeline.

Notification channels, thresholds and mute rules are standard Datadog monitor configuration (see the Monitors docs). Alerting on engine internals (queue, KV cache, GPU) belongs in Prometheus: `prometheus-grafana-llm`, `dcgm-exporter`.

## Evaluations

Managed evaluations (hallucination, language mismatch and others), custom LLM-as-a-judge, external evaluations through the SDK or API, end-user feedback, annotation queues, datasets and experiments exist in the product. Judges need a connected provider account. Method guidance is in `llm-evals`; setup details are in the Evaluations docs and were not verified in depth here.

## Query data programmatically

An Export API searches spans, and Datadog documents an MCP server and Claude Code skills for analyzing traces (see "Build with AI" in the docs). Treat them as production data access: scope the keys.
