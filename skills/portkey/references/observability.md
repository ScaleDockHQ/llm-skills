# Portkey observability

> Verified against Portkey AI Gateway v1.15.2 (src/start-server.ts, src/middlewares/log, src/globals.ts) and docs.portkey.ai (product/observability), 2026-10-11

## Self-hosted gateway

- **Console:** `http://localhost:8787/public/` shows request logs in memory (live stream at `/log/stream`). It disappears when `NODE_ENV` or `ENVIRONMENT` is `production`, and with `--headless`. Newer source requires `admin_token` in `conf.json`; released 1.15.2 does not.
- **Process logs:** stdout of `node build/start-server.js` or `docker logs`. Do not forward request headers or bodies to shared log stores; they contain provider keys and prompts.
- **Response headers:** `x-portkey-trace-id`, `x-portkey-retry-attempt-count`, `x-portkey-last-used-option-index`, `x-portkey-last-used-option-params`, `x-portkey-cache-status`.
- **Request headers:** `x-portkey-trace-id` to correlate, `x-portkey-metadata` for custom keys.
- `APM_LOGGER` env var selects an APM logger integration; read `src/apm` in your tag.

## Hosted Portkey

Logs, traces, feedback, filters, analytics, alerts and budgets are in the app (plan dependent; retention by plan). Telemetry export to an OpenTelemetry compatible endpoint is marked Enterprise or self-hosted in the docs. Auto-instrumentation and budget-limit pages live under product/observability.

## Sending to your own stack

The open-source gateway has no built-in Prometheus endpoint or OpenTelemetry exporter that this skill could verify. For metrics and traces, put LiteLLM in front (`litellm` skill callbacks, Langfuse via `langfuse`) or measure at the reverse proxy (Caddy access logs without headers or bodies). See `llm-observability` for dashboards.

## Verify

- [ ] One request appears in the console or hosted logs with the expected trace ID.
- [ ] No provider key or prompt content is persisted in a shared log sink.
