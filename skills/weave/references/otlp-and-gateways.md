# Weave: OTLP, Collectors and gateways

> Verified against Weave docs "Send OpenTelemetry Traces to Weave", LiteLLM v1.105.0 source (`weave_otel.py`), collector-contrib 0.162.0, 2026-10-11

Use OTLP for non-Python code, for the LiteLLM proxy, or to keep credentials and content stripping in one place.

## Endpoint and auth

- `POST /otel/v1/traces`, `Content-Type: application/x-protobuf`. Multi-tenant: `https://trace.wandb.ai/otel/v1/traces`. Dedicated or Self-Managed: `https://<subdomain>.wandb.io/traces/otel/v1/traces`.
- Header `wandb-api-key: <key>`; Resource attributes `wandb.entity` and `wandb.project` route spans.
- Only protobuf is accepted: use `@opentelemetry/exporter-trace-otlp-proto` in Node and the proto HTTP exporter in Python.
- Pitfall: the SDK's `OTEL_EXPORTER_OTLP_ENDPOINT` appends `/v1/traces`; it must hold the base (`.../otel`), while an exporter constructed with an explicit `endpoint=` needs the full path.
- Weave interprets attributes with prefixes `gen_ai` and `openinference`; otherwise all attributes show on the span.
- Spans appear in the Traces and Threads views; a separate agents endpoint exists for multi-turn agent spans (see the upstream page).

## OpenTelemetry Collector (recommended in production)

`assets/otel-collector.yaml` (validated with collector-contrib 0.162.0) receives OTLP/HTTP on loopback 4318, inserts `wandb.entity` and `wandb.project`, deletes message-content attributes, batches, and exports with the API key header from the environment.

```bash
docker run -d --name otel-weave --restart unless-stopped --env-file ~/.config/wandb/collector.env \
  -p 127.0.0.1:4318:4318 \
  -v "$PWD/otel-collector.yaml:/etc/otelcol-contrib/config.yaml:ro" \
  otel/opentelemetry-collector-contrib:0.162.0
```

`collector.env` is mode `0600` and holds `WANDB_API_KEY`, `WANDB_OTLP_ENDPOINT`, `DEFAULT_WANDB_ENTITY`, `DEFAULT_WANDB_PROJECT`. Bind `0.0.0.0` in the receiver only on a private network. Apps then set `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318` and need no W&B credentials.

## LiteLLM proxy

```yaml
litellm_settings:
  callbacks: ["weave_otel"]
```

Env (from LiteLLM's source): `WANDB_API_KEY`, `WANDB_PROJECT_ID=<entity>/<project>`, optional `WANDB_HOST` for Dedicated or Self-Managed. LiteLLM sets Basic auth (`api:<key>`) with a `project_id` header for you and maps spans to OpenInference plus Weave display name and session (thread) attributes via metadata (`display_name`, `session_id`). Use `turn_off_message_logging: true` for content-off, and check the Weave UI to confirm content is absent. The `litellm` skill covers the proxy itself.

## Engines

vLLM exports OpenTelemetry traces with `--otlp-traces-endpoint` (see `vllm`); point it at the Collector, not directly at Weave. llama.cpp, SGLang and Ollama have no comparable trace export that was verified here; trace at the client or gateway.

## Read-only checks

```bash
docker logs --tail 40 otel-weave
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:4318/v1/traces -H 'Content-Type: application/json' -d '{}'   # 200 means the Collector accepts
```

## Official links

- OTel guide: https://docs.coreweave.com/products/wandb/weave/guides/tracking/otel
- LiteLLM source: https://github.com/BerriAI/litellm/blob/main/litellm/integrations/weave/weave_otel.py
