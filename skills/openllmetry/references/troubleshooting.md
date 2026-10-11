# OpenLLMetry: troubleshooting

> Verified against OpenLLMetry traceloop-sdk 0.62.4 (source traceloop/sdk/**init**.py, tracing/tracing.py; docs configuration), 2026-10-11

Start with `scripts/check.sh`, then set `disable_batch=True` to see exports immediately.

| Symptom                                                     | Cause                                                                                                                   | Fix                                                                                                             |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Nothing exported, log says Traceloop API key is missing     | Default (`api.traceloop.com`) endpoint with no key makes `init` return without exporting                                | Set `TRACELOOP_BASE_URL` to your backend, or pass `exporter=` / `api_endpoint=`                                 |
| `TRACELOOP_BASE_URL` set, connection refused or 404         | Included `/v1/traces` in the base (SDK appends it), or used a gRPC address with an `http` prefix                        | Base only, for example `http://phoenix:6006`; gRPC addresses have no scheme                                     |
| 401 or 403 from the backend                                 | Header missing, wrong scheme, or `%20` not used for spaces in `TRACELOOP_HEADERS`                                       | `Authorization=Bearer%20<key>`; format is `key=value,key2=value2`                                               |
| Spans arrive, no prompts or completions                     | `TRACELOOP_TRACE_CONTENT=false`, `use_attributes=False` without an event logger, or backend does not map the attributes | Check the variable; check `backends.md`; inspect raw attributes                                                 |
| Short scripts lose their last spans                         | Batch processor not flushed before exit                                                                                 | `Traceloop.init(disable_batch=True)` while testing, or call the provider's flush before exit                    |
| Metrics errors in the log, or backend rejects `/v1/metrics` | SDK also exports metrics to the same base                                                                               | `TRACELOOP_METRICS_ENABLED=false`                                                                               |
| Duplicated LLM spans                                        | Two layers (SDK plus proxy callback, or two instrumentations) trace the same call                                       | One layer owns LLM spans; `block_instruments={Instruments.OPENAI}` in the other (`self-hosted-and-gateways.md`) |
| Disconnected traces across services                         | No `traceparent` propagation                                                                                            | Install HTTP client or server instrumentation; check propagators                                                |
| Errors about image upload                                   | Image uploader posts to `<base>/v2/traces/...`, which self-hosted OTLP backends lack                                    | Content off for multimodal apps, or accept the log noise                                                        |
| Decorator spans have truncated inputs                       | `OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT` is set                                                                         | Raise or unset it                                                                                               |
| No spans for one provider                                   | Provider SDK newer than the instrumentation supports, or instrumentation blocked                                        | `pip show opentelemetry-instrumentation-<provider>`; upgrade `traceloop-sdk`; check `block_instruments`         |
| Duplicate or missing context in thread pools                | Context not carried into worker threads                                                                                 | Wrap submitted callables with the context                                                                       |
| `ImportError` or version conflict after install             | Another package pins an older `opentelemetry-api`                                                                       | `pip check`; align on `>=1.38,<2`                                                                               |

## Collecting evidence

```bash
scripts/check.sh                                                     # variables by name, reachability
curl -sS -o /dev/null -w '%{http_code}\n' -X POST "$TRACELOOP_BASE_URL/v1/traces" -H 'Content-Type: application/x-protobuf' --data-binary ''
```

The second command sends an empty OTLP body without credentials: 200 or 400 means the route exists, 401/403 means it needs a header, 404 means the base URL is wrong. Do not paste headers into tickets.
