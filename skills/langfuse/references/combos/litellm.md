# Langfuse with LiteLLM

> Verified against Langfuse v4.56.0 (docs: integrations/gateways/litellm, integrations/native/opentelemetry) and LiteLLM v1.105.0 (docs: observability/langfuse_integration, proxy/logging), 2026-10-11

Every call through a LiteLLM proxy becomes a Langfuse generation with model, latency, token usage and cost, attributed by key and team. For running the proxy itself, install the `litellm` skill: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.

## Config (recommended: OTel preset)

```yaml
# litellm config.yaml
litellm_settings:
  callbacks: ["langfuse_otel"] # upstream Langfuse and LiteLLM docs recommend this for Langfuse v3 and v4
  turn_off_message_logging: true # metadata only; set false only after a privacy decision
```

Environment on the proxy container (names; values from the `0600` env file):

```bash
LANGFUSE_PUBLIC_KEY=...             # project keys from Langfuse project settings
LANGFUSE_SECRET_KEY=...
LANGFUSE_OTEL_HOST=http://langfuse-web:3000   # self-hosted URL as the proxy sees it; the preset defaults to the US cloud
LITELLM_OTEL_V2=true                 # required: OTel v2 is off by default, so the langfuse_otel preset does nothing without it; read once at startup, restart the proxy
```

Langfuse's integration page documents `LANGFUSE_OTEL_HOST` (US cloud default `https://us.cloud.langfuse.com`; EU `https://cloud.langfuse.com`). LiteLLM's docs also list `LANGFUSE_HOST`; check `docs.litellm.ai/docs/observability/langfuse_integration` for the proxy version in use.

Classic callback: `success_callback: ["langfuse"]` needs the Langfuse Python SDK v4 (`langfuse>=4.7,<5`) in the proxy image and a Langfuse server >= 3.63.0 (a v2 server answers `404` on the OTLP route).

## Same Docker network

When both stacks run on one host, put the LiteLLM container on the Langfuse network (or publish Langfuse on the host) so `http://langfuse-web:3000` resolves; otherwise use the host's address and port. Do not point the proxy at `localhost` inside its container.

## Per team or per key projects

Team defaults live in trusted `config.yaml`; per-key callbacks are set through the LiteLLM key and team APIs. Do not accept Langfuse credentials from request bodies. Extra attributes (user, session, tags) are passed as request metadata; the exact field names are on LiteLLM's `proxy/logging#langfuse` page (not verified here).

## Verify

1. Send one chat through a LiteLLM virtual key.
2. In Langfuse open Observations and find a generation whose model is your alias; confirm usage and cost columns.
3. No data: `docker compose logs litellm` for 401 (wrong keys), 404 (old Langfuse server or wrong path) or DNS errors; `scripts/check.sh` against the Langfuse host; LiteLLM's `litellm_callback_logging_failures_metric` (needs the `prometheus` callback).
4. Cost shows zero for self-hosted models until `input_cost_per_token` and `output_cost_per_token` are set on the LiteLLM model.

## Using Langfuse as the LiteLLM-hosted judge target

Langfuse evaluators and the playground can call a LiteLLM gateway as an OpenAI-compatible LLM connection; add it as an LLM API in the Langfuse project settings (exact UI path unverified). Keep that traffic on a private network.

## Official links

- https://langfuse.com/integrations/gateways/litellm
- https://docs.litellm.ai/docs/observability/langfuse_integration
- https://docs.litellm.ai/docs/proxy/logging
