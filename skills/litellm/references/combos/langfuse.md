# LiteLLM with Langfuse

> Verified against LiteLLM v1.105.0 (docs: observability/langfuse_integration, observability/opentelemetry_v2, proxy/logging) and Langfuse v4.56.0 (GitHub release 2026-10-09), 2026-10-11

Send every gateway call to Langfuse as a trace with model, latency, token usage and cost, attributed by key and team.

## Config

```yaml
litellm_settings:
  callbacks: ["langfuse_otel"] # recommended preset for Langfuse v3 and v4
  turn_off_message_logging: false # true = metadata only, no prompts or completions
```

Environment, set in the env file (`chmod 600`), names only here: `LITELLM_OTEL_V2=true` (required: OTel v2 is off by default, nothing in it runs without it, the flag is read once at startup so restart the proxy, and it replaces the v1 `otel` integration rather than adding to it), `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST` (self-hosted URL or `https://cloud.langfuse.com` for EU; the preset defaults to the US cloud, `https://us.cloud.langfuse.com`).

Classic alternative: `success_callback: ["langfuse"]`, which needs Langfuse Python SDK v4 (`langfuse>=4.7,<5`) and a self-hosted Langfuse server of 3.63.0 or newer; a v2 server answers 404 on `/api/public/otel/v1/traces` and traces are rejected.

## Per team or per key projects

Team defaults live in trusted `config.yaml`; per-key callbacks are provisioned via `/key/generate` or `/key/update` (see `proxy/team_logging`). Do not accept Langfuse credentials from request bodies.

## Verify

Send one chat through a virtual key, open the Langfuse traces view and look for a generation with the alias as model. If nothing arrives, check `litellm_callback_logging_failures_metric` (needs the `prometheus` callback) and `docker compose logs litellm` for 401, 404 or DNS errors toward the Langfuse host.

Running Langfuse itself, retention and dashboards: install the `llm-observability` skill (`npx skills add ScaleDockHQ/llm-skills --skill llm-observability`).
