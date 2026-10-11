# LiteLLM: observability (Langfuse, OpenTelemetry, Prometheus, logs)

> Verified against LiteLLM v1.105.0 (docs: proxy/logging, proxy/prometheus, observability/langfuse_integration, proxy/debugging, proxy/config_settings), 2026-10-11

LiteLLM emits logs and metrics through named callbacks configured in `litellm_settings`. Callback keys come from the environment; never put them in YAML. Spend and usage are also in the Admin UI (`/ui`) and `GET /global/spend/report` (needs Postgres).

## Which callback

| Need                       | Callback                                | Notes                                                                                                                                                 |
| -------------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Metrics for Prometheus     | `callbacks: ["prometheus"]`             | `/metrics` on the proxy port; image already has `prometheus_client`, the pip CLI needs it installed                                                   |
| Traces to Langfuse (v3/v4) | `callbacks: ["langfuse_otel"]`          | Upstream recommends the OTel v2 preset for Langfuse v3 and v4; needs `LITELLM_OTEL_V2=true` in the proxy env                                          |
| Langfuse SDK callback      | `success_callback: ["langfuse"]`        | Needs Langfuse Python SDK v4 (`langfuse>=4.7,<5`); self-hosted Langfuse must be server 3.63.0 or newer; older v2 servers return 404 on the OTLP route |
| Generic traces             | `callbacks: ["otel"]`                   | Exporter settings via env                                                                                                                             |
| Success or failure only    | `success_callback` / `failure_callback` | `callbacks` runs on both                                                                                                                              |

```yaml
litellm_settings:
  callbacks: ["prometheus", "langfuse_otel"]
  turn_off_message_logging: true # log metadata, not prompts or completions
```

## Langfuse

Env vars (names only): `LITELLM_OTEL_V2=true` (required for `langfuse_otel`: OTel v2 is off by default and the flag is read once at startup, so restart after setting it; OTel v2 and the older `otel` integration are alternatives, pick one), `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST` (takes precedence over `LANGFUSE_BASE_URL`). For the `langfuse_otel` preset (OTel v2 guide) endpoint resolution is `LANGFUSE_OTEL_HOST`, then `LANGFUSE_HOST`, then the US cloud default (`https://us.cloud.langfuse.com`; EU is `https://cloud.langfuse.com`), and auth is built from the key pair. Per-team or per-key Langfuse projects: see `proxy/team_logging`. Combined stack recipe: `combos/langfuse.md`.

## Prometheus

- Scrape `GET /metrics` with a key (`Authorization: Bearer ...`). `general_settings.require_auth_for_metrics_endpoint` controls whether the proxy-port route needs auth; check the default for your version in `proxy/config_settings`.
- Multiple workers: set `PROMETHEUS_MULTIPROC_DIR` to an existing writable directory.
- Since v1.101.0 a dedicated metrics process can serve the same metrics: `--prometheus_metrics_port` or `PROMETHEUS_METRICS_PORT`. The proxy-port `/metrics` stays available. The dedicated listener does not use virtual-key auth: expose it only to trusted scrapers, never through a public ingress.
- `litellm_settings.prometheus_initialize_budget_metrics: true` emits budget metrics for all keys and teams, not only active ones.
- Alert on `litellm_callback_logging_failures_metric` (label `callback_name`) to catch silent callback failures.

## Privacy and per-request control

- `turn_off_message_logging: true` removes prompts and completions from callbacks, not from the proxy's own debug logs.
- Request body `no-log: true` skips logging for that request.
- Header `x-litellm-disable-callbacks: <name>` skips a named callback (Enterprise feature upstream).

## Logs and debug

- `--debug` (INFO) or `--detailed_debug` (DEBUG), or `LITELLM_LOG=INFO|DEBUG|ERROR`. Debug logs can contain prompts and headers: enable briefly.
- `litellm_settings.json_logs: true` for structured logs.
- `docker compose logs --since 30m litellm`.

## Beyond LiteLLM

Dashboards, OTel collectors, retention and alerting across engines and the gateway: install the `llm-observability` skill (`npx skills add ScaleDockHQ/llms-skills --skill llm-observability`).

## Official links

- Logging: https://docs.litellm.ai/docs/proxy/logging
- Prometheus: https://docs.litellm.ai/docs/proxy/prometheus
- OpenTelemetry v2 (Langfuse preset): https://docs.litellm.ai/docs/observability/opentelemetry_v2
- Langfuse integration: https://docs.litellm.ai/docs/observability/langfuse_integration
- Debugging: https://docs.litellm.ai/docs/proxy/debugging
