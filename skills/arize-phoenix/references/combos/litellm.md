# Phoenix with LiteLLM

> Verified against Arize Phoenix v20.21.0 and LiteLLM docs 2026-10-10 (observability/phoenix_integration, observability/opentelemetry_integration; latest release v1.105.0), 2026-10-11

Every LiteLLM call becomes a Phoenix span with model, provider, token counts and (when allowed) messages. For running the proxy itself, install `litellm`: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.

## Proxy config (recommended: the `arize_phoenix` preset)

```yaml
# litellm config.yaml
litellm_settings:
  callbacks: ["arize_phoenix"]
  turn_off_message_logging: true # metadata only; set false only after a privacy decision
```

Environment on the proxy (names; values from a `0600` env file):

```bash
LITELLM_OTEL_V2=true                                    # the preset needs OTel v2
PHOENIX_COLLECTOR_ENDPOINT=http://phoenix:6006/v1/traces  # self-hosted; defaults to http://localhost:6006/v1/traces when unset
PHOENIX_PROJECT_NAME=litellm-prod                       # optional; fallback project, default "default"
# PHOENIX_API_KEY=...                                   # required only for Phoenix Cloud per LiteLLM docs; with self-hosted auth on, send the system key
# PHOENIX_COLLECTOR_HTTP_ENDPOINT overrides PHOENIX_COLLECTOR_ENDPOINT when both are set
```

LiteLLM infers the protocol from the endpoint: `grpc://...` or a `:4317` URL without `/v1/traces` exports over gRPC, anything else over HTTP. Self-hosted Phoenix with auth enabled still needs a bearer system API key: LiteLLM documents the key variable only for Phoenix Cloud, so confirm the header reaches Phoenix (`scripts/check.sh`, then a test request) or put a Collector in between (`assets/otel-collector.yaml` adds the header).

Phoenix endpoint shapes: self-hosted `http://host:6006/v1/traces`; Phoenix Cloud uses `https://app.phoenix.arize.com/s/<space>/v1/traces`.

## One Phoenix project per team or key

With `LITELLM_OTEL_V2=true` and the `arize_phoenix` callback, set `phoenix_project_name` in a team's or key's metadata and LiteLLM sends that team's spans with the `x-project-name` header (Phoenix 15.5.0+):

```bash
curl -sS -X POST "$LITELLM_URL/team/new" -H "Authorization: Bearer $LITELLM_KEY" -H 'Content-Type: application/json' \
  -d '{"team_alias":"payments","metadata":{"phoenix_project_name":"payments-prod"}}'
```

The project is taken only from the team or key resolved at auth; a `phoenix_project_name` inside a request body is ignored. Keys without a name use `PHOENIX_PROJECT_NAME`.

## Content capture

- `litellm.turn_off_message_logging=True` (`turn_off_message_logging: true` in `litellm_settings`) forces no content; request metadata is still logged.
- Per-handler policy and the standard variable `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` (`NO_CONTENT`, `SPAN_ONLY`, `EVENT_ONLY`, `SPAN_AND_EVENT`; `true` maps to `EVENT_ONLY`) apply to LiteLLM's generic `otel` callback; the kill switch above overrides them. Check the LiteLLM docs for how the `arize_phoenix` preset resolves them in the version you run.
- Callers can override redaction per request with headers; decide whether clients are trusted (`llm-observability` covers `x-litellm-enable-message-redaction`).

## Generic OTLP instead of the preset

Pointing LiteLLM's `otel` callback (`OTEL_EXPORTER=otlp_http`, `OTEL_ENDPOINT=http://phoenix:6006/v1/traces`) at Phoenix sends only canonical `gen_ai.*` names; Phoenix 15.10.0+ converts them, but the preset names the OpenInference mapper for richer rendering. Prefer the preset.

## LiteLLM SDK in an app

`litellm.callbacks = ["arize_phoenix"]` with the same variables, or the OpenInference route `pip install openinference-instrumentation-litellm` plus `register(auto_instrument=True)` (the Phoenix docs pin `litellm<1.82.7` for that instrumentor, so check compatibility first).

## Same Docker network

Put the proxy and Phoenix on one network and use `http://phoenix:6006`; `localhost` inside the proxy container is the proxy itself.

## Verify

Send one request through the proxy, then `scripts/check.sh` and open the project. The LLM span is named `chat <model>` under the request root.
