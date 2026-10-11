# Langfuse side: LiteLLM callbacks

> Verified against LiteLLM v1.105.0 (docs: observability/opentelemetry_v2, observability/langfuse_integration) and Langfuse v4.56.0 (GitHub release 2026-10-09), 2026-10-11

## Recommended: the `langfuse_otel` preset

Upstream recommends the OpenTelemetry v2 preset for Langfuse v3 and v4. OTel v2 is off by default: "nothing in it runs until you set `LITELLM_OTEL_V2=true`", and it is separate from the older OpenTelemetry integration, so choose one.

```yaml
# litellm-config.yaml
litellm_settings:
  callbacks: ["prometheus", "langfuse_otel"]
  turn_off_message_logging: true # metadata only; see privacy-and-cost.md
```

Environment for the LiteLLM container (names only; values in the `0600` env file):

```text
LITELLM_OTEL_V2=true
LANGFUSE_PUBLIC_KEY=
LANGFUSE_SECRET_KEY=
LANGFUSE_HOST=            # self-hosted URL, or https://cloud.langfuse.com (EU)
```

- The preset builds HTTP Basic auth from the key pair; you never set the header yourself.
- The preset's default destination is the US cloud (`https://us.cloud.langfuse.com`); set `LANGFUSE_HOST` for EU cloud or self-hosting. `LANGFUSE_OTEL_HOST`, if set, wins over `LANGFUSE_HOST`.
- Self-hosted: use a Langfuse server version that serves the OTLP route (`/api/public/otel/v1/traces`); v3.63.0 or newer per the integration docs. From inside a Compose network use the service URL, for example `http://langfuse-web:3000`, and put both stacks on one Docker network.
- Several destinations at once: list more presets, for example `["langfuse_otel", "arize"]`; each adds an exporter.

## Alternative: SDK callback

```yaml
litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]
```

Needs the Langfuse Python SDK v4 in the proxy environment (`langfuse>=4.7,<5`). It exports through LiteLLM's OTel pipeline and uses the SDK's REST client for prompt management. Do not combine it with `langfuse_otel` for the same traffic: you will get duplicate traces.

## Per-team or per-key projects

Team defaults live in the trusted `config.yaml` with `os.environ/NAME` references; per-key callbacks are provisioned through `/key/generate` or `/key/update` and are stored settings on the key. Per-request credentials in request bodies exist for SDK use but must not be accepted from untrusted callers on a shared gateway. See LiteLLM docs `proxy/team_logging`.

## Check

```bash
docker compose exec litellm env | cut -d= -f1 | grep -E '^(LITELLM_OTEL_V2|LANGFUSE_)'   # names only, no values
docker compose logs --since 10m litellm | grep -i -E 'langfuse|otel|401|404' | tail
```

Then send one request (`verify-and-troubleshoot.md`) and look for a trace in the Langfuse UI whose model is your alias.
