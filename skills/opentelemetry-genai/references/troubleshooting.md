# GenAI telemetry troubleshooting

> Verified against opentelemetry-python-genai 1.2b0, opentelemetry-util-genai 1.2b0 (utils.py behavior), OpenTelemetry Collector contrib 0.162.0, 2026-10-11

Start with `scripts/check.sh`. Then use a `debug` exporter on the Collector or `OTEL_TRACES_EXPORTER=console` in the app to see what is emitted.

| Symptom                                                  | Cause                                                                                                  | Fix                                                                                                                                               |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| No `gen_ai` spans at all                                 | Instrumentor not loaded, wrong package for the client library, or client created before `instrument()` | `opentelemetry-instrument` or call `Instrumentor().instrument()` early; check `pip list` for the package and that the library version is in range |
| Spans exist but no prompts or completions                | Capture mode is `NO_CONTENT` (default), or content stripped by the Collector                           | Intended? If not: set `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=span_only` for the test and check `transform` statements                |
| Warning: not a valid option for the content variable     | Typo or value like `true`                                                                              | Use `span_only`, `event_only`, `span_and_event` or `no_content`                                                                                   |
| Content missing with `event_only`                        | No logs exporter or pipeline                                                                           | `OTEL_LOGS_EXPORTER=otlp` and a logs pipeline in the Collector, or use `span_only`                                                                |
| Old attribute names (`gen_ai.system`, `gen_ai.prompt.0`) | Still on `opentelemetry-instrumentation-openai-v2` without the opt-in flag, or another library         | Migrate (`instrumentation.md`)                                                                                                                    |
| 404 from the OTLP endpoint                               | Base URL with `/v1/traces` appended twice, or backend lacks OTLP ingest                                | Use the base URL with `OTEL_EXPORTER_OTLP_ENDPOINT`; see `backends-and-gateways.md`                                                               |
| 415 or protocol errors against Langfuse or MLflow        | App exports gRPC                                                                                       | `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf` or route through the Collector's `otlphttp`                                                           |
| 401/403                                                  | Missing or wrong header                                                                                | Check header name and scheme (`Bearer` vs `Basic`); Collector exporters read `${env:...}`                                                         |
| Collector refuses to start                               | Config error or component missing from the distribution                                                | `validate`; use the contrib image                                                                                                                 |
| Collector drops everything                               | `tail_sampling` too strict, or `memory_limiter` refusing data                                          | Check Collector logs and metrics (`:8888`); loosen probabilistic share                                                                            |
| Partial traces after tail sampling                       | Spans of one trace reach different Collector instances, or `decision_wait` shorter than the trace      | Single instance or load-balancing tier; raise `decision_wait`                                                                                     |
| Duplicate LLM spans or doubled token counts              | App instrumentation plus gateway callback                                                              | One layer owns each call                                                                                                                          |
| Disconnected traces across app, gateway and engine       | `traceparent` not propagated                                                                           | Instrument the HTTP client and server frameworks; check propagators (`OTEL_PROPAGATORS`)                                                          |
| Metrics errors in logs                                   | Backend takes traces only                                                                              | `OTEL_METRICS_EXPORTER=none`                                                                                                                      |
| Token counts empty for a self-hosted model               | Server omits `usage`                                                                                   | Enable usage in streaming (`stream_options`) or accept missing tokens                                                                             |
| Dashboards broke after upgrade                           | Renamed metrics or attributes                                                                          | `updating.md` rename list                                                                                                                         |

## Evidence

```bash
scripts/check.sh
docker logs otelcol 2>&1 | tail -50                          # Collector errors; no secrets are logged by default
curl -sS -o /dev/null -w '%{http_code}\n' -X POST "$OTEL_EXPORTER_OTLP_ENDPOINT/v1/traces" -H 'Content-Type: application/x-protobuf' --data-binary ''
```

The last command sends an empty body without credentials: 200 or 400 means the route exists, 401 or 403 means auth is required, 404 means the base URL is wrong.
