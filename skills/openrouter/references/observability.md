# OpenRouter observability

> Verified against OpenRouter API v1 (docs: features/broadcast, features/activity, features/logs, input-output-logging, features/router-metadata, api_reference/overview, cookbook/administration/usage-accounting), 2026-10-11

## Per-request cost and usage

Every response carries `usage` with token counts. For cost, tokens and provider details after the fact, read the generation by id:

```bash
curl -fsS "https://openrouter.ai/api/v1/generation?id=$GENERATION_ID" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq .
```

`GET /api/v1/key` gives rolled-up daily, weekly and monthly usage for a key. The dashboard has Activity and Logs pages; prompt/response logging is opt-in (input/output logging setting), so a log entry may have metadata only.

## Routing detail

`X-OpenRouter-Metadata: enabled` (the legacy `X-OpenRouter-Experimental-Metadata` also works) adds `openrouter_metadata` to the response and to error bodies: the requested model, strategy, selected provider, attempts, endpoints considered and the pipeline stages (router, guardrails). Use it to debug why a provider or fallback was chosen.

## Broadcast

Settings, Observability: enable Broadcast and add destinations; OpenRouter then sends traces for all requests to them without code changes. Destinations listed in the docs include Arize AX, Braintrust, ClickHouse, Comet Opik, Datadog, Elastic, Google BigQuery, Grafana Cloud, Hugging Face Storage Buckets, Langfuse, LangSmith, New Relic, OpenTelemetry Collector, PostHog, Raindrop, Ramp, S3, Sentry, Snowflake, W&B Weave and a generic webhook. Each destination has its own page with credentials; keep those in the dashboard, not in repos. Prompts and completions go to the destination, so check data controls first (`data-controls.md`).

For a self-hosted trace store use Langfuse or an OTel collector destination (skill `llm-observability`, and `langfuse` for the Langfuse side).

## Verify

- [ ] A test request shows up at the destination with cost and model, and sensitive fields are as expected.
