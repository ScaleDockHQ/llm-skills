# Phoenix: troubleshooting

> Verified against Arize Phoenix v20.21.0, arize-phoenix-otel 0.17.2, LiteLLM docs 2026-10-10 (docs: self-hosting/configuration, features/authentication, upgrade/migrations, tracing sampling, litellm phoenix_integration), 2026-10-11

Start with `scripts/check.sh` and `docker logs phoenix --tail 100`.

| Symptom                                                                            | Cause                                                                                   | Fix                                                                                                                     |
| ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Traces stopped after enabling auth; exporter logs 401/403                          | Auth blocks ingestion without an API key                                                | Create a system API key; set `PHOENIX_API_KEY` or `Authorization: Bearer ...` on every sender                           |
| `404` or "connection refused" from the exporter                                    | Wrong path or port: HTTP needs `/v1/traces` on 6006, gRPC is 4317                       | Code `endpoint=` needs the full URL with `/v1/traces`; env `PHOENIX_COLLECTOR_ENDPOINT` takes the base                  |
| Nothing arrives, no error, short script                                            | Batch processor not flushed at exit                                                     | `batch=False` or call `tracer_provider.shutdown()`                                                                      |
| Spans exist but project is `default`                                               | No project name set                                                                     | `register(project_name=...)`, `PHOENIX_PROJECT`, `openinference.project.name` resource attr, or `x-project-name` header |
| `x-project-name` ignored                                                           | Server older than 15.5.0                                                                | Upgrade the server, or set the resource attribute                                                                       |
| Traces from an OTel GenAI library look bare                                        | Server older than 15.10.0 (no GenAI conversion), or the library did not capture content | Upgrade; enable the library's content capture (see `opentelemetry-genai`)                                               |
| Data vanished after container recreate                                             | SQLite in a temporary folder or unmounted `PHOENIX_WORKING_DIR`                         | Mount a volume, or move to PostgreSQL with `PHOENIX_SQL_DATABASE_URL`                                                   |
| Cannot log in as admin; password rejected                                          | `PHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD` is read only when the admin is first created   | Reset through the UI or an admin reset; default is `admin` if it was never set                                          |
| Locked out after failed logins                                                     | Brute-force protection (5 attempts, 5 minutes)                                          | Wait, or tune `PHOENIX_BRUTE_FORCE_LOGIN_PROTECTION_MAX_ATTEMPTS`                                                       |
| Login loops or CSRF errors behind a proxy                                          | Cookies not secure, origin not trusted                                                  | `PHOENIX_USE_SECURE_COOKIES=true`, `PHOENIX_CSRF_TRUSTED_ORIGINS=https://your-host`, correct `PHOENIX_ROOT_URL`         |
| UI blank under a sub-path                                                          | Missing root path                                                                       | `PHOENIX_HOST_ROOT_PATH=/phoenix` and proxy that prefix unchanged                                                       |
| Pod `CrashLoopBackOff` right after upgrade                                         | Long migration exceeds liveness probe                                                   | Run `phoenix db migrate` in an initContainer (`updating.md`)                                                            |
| Server fails after rollback to an older image                                      | New schema, no down-migration                                                           | Restore the pre-upgrade database backup                                                                                 |
| UI loads slowly, SQLite `database is locked`                                       | SQLite with several writers or slow storage                                             | Move to PostgreSQL 14+; keep SQLite on local disk                                                                       |
| Disk grows without bound                                                           | Infinite retention (`0`) and content stored                                             | Set retention days; hide content; vacuum                                                                                |
| Playground cannot reach a provider                                                 | Egress blocked, or provider hidden                                                      | Allow egress to that provider; check `PHOENIX_ALLOWED_PROVIDERS`                                                        |
| Air-gapped host: UI fonts or sandbox fail                                          | External resources on                                                                   | `PHOENIX_ALLOW_EXTERNAL_RESOURCES=false`                                                                                |
| Spans silently dropped by SDK sampler                                              | Sampler set to `always_off` or ratio too low                                            | Check `OTEL_TRACES_SAMPLER` and `_ARG` values                                                                           |
| LiteLLM spans render plainly in Phoenix                                            | Generic OTLP path used instead of the `arize_phoenix` preset                            | See `combos/litellm.md`                                                                                                 |
| `pip install openinference-instrumentation-litellm` conflicts with a newer LiteLLM | The Phoenix page pins `litellm<1.82.7` for that instrumentor                            | Prefer the LiteLLM proxy callback (`arize_phoenix`) for new LiteLLM versions                                            |

## Diagnose from the server side

```bash
scripts/check.sh
curl -fsS http://localhost:6006/readyz                                  # {} means the database answers; 503 means it does not
docker logs phoenix 2>&1 | grep -iE 'error|migrat|unauthor' | tail -20
```

For a sender, run with the exporter's own debug logging (`OTEL_LOG_LEVEL=debug`) or point it at a Collector with a `debug` exporter first to prove spans leave the process.
