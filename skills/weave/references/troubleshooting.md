# Weave troubleshooting

> Verified against weave 0.53.12 and Weave docs (OTel, tracing, self-managed), 2026-10-11

| Symptom                                | Cause                                                                                | Fix                                                                                             |
| -------------------------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| No traces, no link printed             | `weave.init` not called, or `WEAVE_DISABLED=true`                                    | Call `weave.init` before the work; unset the variable                                           |
| Calls to the local server not traced   | Client created before `weave.init`, or `from litellm import completion` import style | Init first; `import litellm` and call `litellm.completion`                                      |
| Not logged in / auth error             | No `WANDB_API_KEY` and no `~/.netrc` entry                                           | `wandb login` or export the key from a file; set `WANDB_BASE_URL` for Dedicated or Self-Managed |
| Traces land in the wrong project       | Missing entity                                                                       | Use `entity/project`                                                                            |
| OTLP 401 or 403                        | Missing or wrong `wandb-api-key` header                                              | Fix header; API key must be valid for that entity                                               |
| OTLP 400 or "unsupported"              | JSON or gRPC sent                                                                    | Use HTTP protobuf exporter                                                                      |
| Spans accepted but nothing in project  | Missing `wandb.entity` or `wandb.project` resource attributes                        | Set on TracerProvider or the Collector `resource` processor                                     |
| Doubled path `/v1/traces/v1/traces`    | `OTEL_EXPORTER_OTLP_ENDPOINT` set to the full path                                   | Use the base `.../otel` for the env var; full path only for explicit `endpoint=`                |
| LiteLLM `weave_otel` startup error     | `WANDB_API_KEY` or `WANDB_PROJECT_ID` missing                                        | Set both (`<entity>/<project>`); `WANDB_HOST` for non-cloud                                     |
| Content visible despite settings       | Redaction is Python SDK only, or Presidio not installed                              | Install Presidio; strip at the Collector for other languages                                    |
| `redact_pii` slow                      | Presidio processing                                                                  | Expected; redact fewer fields or filter yourself                                                |
| No cost shown for a local model        | Model not in the price table                                                         | Add a custom cost in the platform; see the costs guide                                          |
| Process hangs at exit or memory growth | Large call queue or slow network                                                     | Lower volume with sampling, raise `WEAVE_HTTP_TIMEOUT`, check `WEAVE_MAX_CALLS_QUEUE_SIZE`      |
| Self-managed: traces fail              | ClickHouse or weave-trace pod unhealthy, license lacks Weave                         | Check pods in `wandb` and `clickhouse` namespaces; ask W&B Support about the license            |

## Diagnose

```bash
scripts/check.sh
WEAVE_LOG_LEVEL=DEBUG python3 your_app.py 2>&1 | head -60
docker logs --tail 80 otel-weave
```

## Official links

- Docs: https://docs.coreweave.com/products/wandb/weave/reference
- Issues: https://github.com/wandb/weave/issues
