# Langfuse: troubleshooting

> Verified against Langfuse v4.56.0 (docs: self-hosting/troubleshooting-and-faq and the linked FAQ pages, health-readiness-endpoints, upgrade-v3-to-v4, integrations/native/opentelemetry), 2026-10-11

Start with `LANGFUSE_HOST=http://localhost:3000 scripts/check.sh`, then `docker compose ps` and `docker compose logs --tail 100 langfuse-web langfuse-worker`.

| Symptom                                                                            | Likely cause and fix                                                                                                                                                                                                   |
| ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UI unreachable or login redirects loop                                             | `NEXTAUTH_URL` must exactly match the URL in the browser, including protocol and port. Set `HOSTNAME=0.0.0.0` if the container is unreachable from outside. For SSO the provider callback must match `NEXTAUTH_URL`.   |
| `docker compose up` fails on `set in .env`                                         | A required secret is missing from `.env`; rerun `scripts/gen-env.sh` or fill the variable.                                                                                                                             |
| Web logs "Ready" only after 2-3 minutes                                            | Normal on first start while migrations run. Persistent restarts mean a dependency is unhealthy: check ClickHouse, Redis, Postgres and MinIO health in `docker compose ps`.                                             |
| DB connection errors with a password containing symbols                            | Special characters in `DATABASE_URL` must be URL-encoded; `scripts/gen-env.sh` uses hex to avoid this. Postgres must be at least 12 per the FAQ; v4 needs 15+.                                                         |
| Traces never appear (SDK)                                                          | `auth_check()` in the Python SDK; wrong `LANGFUSE_BASE_URL`, keys from another project, or missing `flush()`/`shutdown()` in short-lived processes.                                                                    |
| OTLP exporter errors or silence                                                    | Langfuse accepts HTTP only: use `http/protobuf` or `http/json`, never gRPC. Endpoint is `<host>/api/public/otel` (traces: `/api/public/otel/v1/traces`). Check Basic auth is `base64(pk:sk)` without wrapped newlines. |
| Spans appear ~10-15 minutes late                                                   | Missing `x-langfuse-ingestion-version: 4` header on direct OTel, or SDK older than Python 4.7.0 / JS 5.4.0.                                                                                                            |
| `404` on `/api/public/otel/v1/traces`                                              | Server too old: LiteLLM's classic `langfuse` callback needs a Langfuse server >= 3.63.0 for that route.                                                                                                                |
| `404` on `/api/public/traces`, `/observations`, `/sessions`, `/scores`, `/metrics` | Expected on default v4 write mode; migrate to Observations API v2, Scores API v3, Metrics API v2.                                                                                                                      |
| SDK data rejected                                                                  | Python SDK v2 or older, JS/TS v3 or older against a v4 server on `events_only`. Upgrade the SDK, or run `dual` mode temporarily.                                                                                       |
| Events accepted but missing                                                        | Look in web logs for Redis or S3 errors; confirm the event object exists in the bucket under `<projectId>/<type>/<eventId>/<randomId>.json`; check worker logs and `LANGFUSE_S3_EVENT_UPLOAD_*`.                       |
| Media or multimodal traces fail, text works                                        | MinIO is not browser-reachable: set `LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT` to a URL the browser can open, and expose MinIO (host port 9090).                                                                              |
| `Not enough privileges` during v4 migration                                        | The ClickHouse user lacks the v4 grants; apply them from the v3-to-v4 guide (`references/updating.md`).                                                                                                                |
| `Dirty database version N. Fix and force version` (ClickHouse)                     | A migration failed part-way; investigate whether it applied, then force the version with golang-migrate per the upstream FAQ. Take a backup first.                                                                     |
| `socket usage at capacity` warnings                                                | Raise `LANGFUSE_S3_CONCURRENT_WRITES` above 50 or add web replicas; memory use rises with sockets.                                                                                                                     |
| Intermittent 502/504 behind a load balancer                                        | Set `KEEP_ALIVE_TIMEOUT` on web at least 5 seconds above the load balancer idle timeout.                                                                                                                               |
| `JavaScript heap out of memory`                                                    | Set `NODE_OPTIONS=--max-old-space-size=<MiB>` on web and worker to at least the container memory limit.                                                                                                                |
| Disk fills up                                                                      | ClickHouse system logs (no TTL) and Docker json-file logs; configure retention (EE), ClickHouse log TTLs and Docker log rotation. See `references/privacy-retention.md`.                                               |
| Helm install fails on ClickHouse CRDs                                              | Install cert-manager and the ClickHouse operator first, or set `clickhouse.deploy: false` and use an external ClickHouse.                                                                                              |
| Worker health 503 in dual mode                                                     | Event propagation is stuck; check worker logs and ClickHouse health.                                                                                                                                                   |
| Cannot sign in on Langfuse Cloud                                                   | Wrong data region (EU, US, Japan, HIPAA accounts are separate), wrong email, or wrong sign-in method.                                                                                                                  |

Other upstream FAQ topics: forgotten password, PostgreSQL table ownership failures, timezone errors (the shipped Compose sets `TZ=UTC` on Postgres), BullMQ queue management, retention job timeouts. Index: https://langfuse.com/self-hosting/troubleshooting-and-faq.

## Official links

- https://langfuse.com/self-hosting/troubleshooting-and-faq
- https://langfuse.com/faq/all/debug-docker-deployment
- https://langfuse.com/faq/all/self-hosting-missing-events-after-ingestion
- https://langfuse.com/faq/all/self-hosting-502-504-network-errors
- https://langfuse.com/faq/all/self-hosting-javascript-heap-out-of-memory
- https://langfuse.com/faq/all/self-hosting-socket-usage-at-capacity
- https://langfuse.com/faq/all/self-hosting-clickhouse-handling-failed-migrations
