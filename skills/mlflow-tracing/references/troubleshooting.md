# MLflow tracing troubleshooting

> Verified against MLflow 3.17.0 (live tests: OTLP ingest, Host validation, basic auth; docs faq and tracking-server), 2026-10-11

Start with `scripts/check.sh`.

| Symptom                                                                        | Cause                                                                                                               | Fix                                                                                              |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| HTTP 403 `Invalid Host header - possible DNS rebinding attack detected`        | Host header (service name, DNS name, non-private IP) not in `--allowed-hosts`                                       | Add the exact `host:port` to `--allowed-hosts`                                                   |
| HTTP 422 on `/v1/traces`                                                       | Missing `x-mlflow-experiment-id` header                                                                             | Add the header with the numeric experiment ID                                                    |
| HTTP 400 `Invalid OpenTelemetry format - no spans found`                       | Empty or non-protobuf body (a probe), or JSON where protobuf is expected                                            | Use OTLP/HTTP protobuf: `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf`                       |
| HTTP 401 on any call                                                           | Basic auth is on                                                                                                    | `MLFLOW_TRACKING_USERNAME`/`PASSWORD` for the SDK, `Authorization=Basic%20<b64>` header for OTLP |
| OTLP exporter errors, gRPC connection failures                                 | The endpoint is OTLP/HTTP only                                                                                      | HTTP protocol; for gRPC apps route through a Collector's `otlphttp` exporter                     |
| OTLP ingest returns errors or traces never appear, file store in use           | OTLP needs a SQL backend store                                                                                      | `--backend-store-uri sqlite:///...` or PostgreSQL                                                |
| Traces go to the wrong experiment or are rejected                              | Header holds the experiment **name**, or the ID of another experiment                                               | Numeric ID; look it up (`tracing.md`)                                                            |
| `The MLflow basic auth app requires the Flask-WTF package`                     | Missing `mlflow[auth]` extra (the official image lacks it)                                                          | `pip install "mlflow[auth]"` or build a derived image                                            |
| Server refuses to start after upgrade (schema out of date)                     | Database not migrated                                                                                               | `mlflow db upgrade <url>` after a backup                                                         |
| No traces from the SDK, no errors                                              | `MLFLOW_TRACING_ENABLED=false`, tracking URI unset (local `./mlruns` or `mlflow.db`), or autolog flavor not enabled | `mlflow.get_tracking_uri()`; call `mlflow.<flavor>.autolog()` before creating the client         |
| Traces missing at process exit                                                 | Async logging queue not flushed                                                                                     | `mlflow.flush_trace_async_logging()` before exit, or disable async for short scripts             |
| `search_traces` finds nothing for `trace.text` or `span.content` on old traces | Payloads archived                                                                                                   | Search metadata, or expect the limitation (`privacy-retention.md`)                               |
| Duplicate spans                                                                | Autolog plus a gateway callback or OTel instrumentation for the same call                                           | One layer owns each call                                                                         |
| vLLM spans do not show token usage                                             | Engine uses older attribute names                                                                                   | Use client or gateway spans for token and content data                                           |
| Both `mlflow` and `mlflow-tracing` installed, odd import errors                | Version conflict between the packages                                                                               | Keep only one per environment                                                                    |
| Database grows quickly                                                         | Traces retained indefinitely                                                                                        | Archival and scheduled deletion                                                                  |

## Evidence

```bash
scripts/check.sh
docker logs mlflow 2>&1 | tail -50          # server errors; no secrets are logged by default
curl -sS -o /dev/null -w '%{http_code}\n' -X POST "$MLFLOW_URL/v1/traces" -H 'Content-Type: application/x-protobuf' -H 'x-mlflow-experiment-id: 0' --data-binary ''
```

The last call: 400 means the route is reachable and unauthenticated (or authenticated by a proxy), 401 means credentials are required, 403 means the Host header is rejected, 404 means the endpoint is missing (version older than 3.6.0 or a proxy path problem). Do not paste headers into tickets.
