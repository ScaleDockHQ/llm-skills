# Sentry AI monitoring: cost, dashboards and alerting

> Verified against Sentry docs "Model Costs", "Agents Dashboards", "Naming Your Agents" and "Alerts", 2026-10-11

## Cost for self-hosted models

Sentry prices a span from `gen_ai.request.model` or `gen_ai.response.model` plus token counts, using per-token prices from models.dev and OpenRouter. If no tokens are reported, or the model name matches nothing (self-hosted, fine-tuned or brand-new models), cost is zero. Non-token costs are not included.

Send your own cost on each AI span, in USD, as numbers:

| Attribute                                                                                                               | Meaning                                                                           |
| ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `gen_ai.cost.total_tokens`                                                                                              | Total cost. Required: without it Sentry may overwrite your values with estimates. |
| `gen_ai.cost.input_tokens`                                                                                              | Input cost including cache read and creation                                      |
| `gen_ai.cost.output_tokens`                                                                                             | Output cost including reasoning                                                   |
| `gen_ai.cost.cache_read.input_tokens`, `gen_ai.cost.cache_creation.input_tokens`, `gen_ai.cost.reasoning.output_tokens` | Breakdown parts                                                                   |

Sentry keeps breakdown fields you provide but does not derive missing ones from the total. Do not add cache costs to input or reasoning to output; those totals already contain them. Use `0` for sunk-cost hardware or an amortized per-token figure. These attributes are Sentry extensions to the OTel conventions. Token attributes must be set correctly (input and output are totals; cached, cache-write and reasoning tokens are subsets), or costs can go negative.

Auto-instrumented spans come from the integration; to attach custom cost, wrap the call in your own span and set the attributes (`references/setup-and-sdks.md`). Whether the integrations expose a hook to set cost on their spans was not verified.

## Dashboards

Agents dashboards: Overview (agent runs, LLM calls, duration average and p95, calls by model, tokens, tool calls, and a traces table with errors, tokens and cost), Models (model cost, tokens used, token types), Tools (tool calls and errors). Agents are grouped by `gen_ai.agent.name`. The AI Spans tab in the Trace Explorer shows agent invocations, generations, tool calls, handoffs and errors. The Conversations tab replays chats grouped by `gen_ai.conversation.id`.

## Alerting

Sentry's alerting is organization-level (Monitors, Alerts). What is supported by the docs:

- Failures in LLM calls that raise exceptions become issues (for example OpenAI exceptions are reported), so ordinary issue alerts apply.
- Per-agent alerts need agent names (`gen_ai.agent.name`).
- Alerts and monitors on span data (latency, error rate, token or cost trends) exist in Sentry's Monitors product. The exact configuration for AI span metrics was not verified; check the Monitors docs at use time.

Useful signals to watch: error rate per agent, p95 agent duration, tokens per run, cost per day (only meaningful with correct prices), and a drop to zero runs. Engine queue depth, KV cache and GPU alerts belong in Prometheus: `prometheus-grafana-llm` and `dcgm-exporter`.

## Evaluations

Sentry's manual instrumentation defines an `evaluate` operation (`gen_ai.operation.name: "evaluate"`) so evaluation spans can be recorded and distinguished from chat calls. It is not an evaluation framework; for method and runners use `llm-evals`.
