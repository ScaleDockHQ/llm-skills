# Traefik: logs, metrics and health

> Verified against Traefik v3.7.14 (docs for v3.7), 2026-10-11

Sources: reference "Logs and Access Logs", "Metrics", "Healthcheck", "API and dashboard".

- **Logs:** `log.level`, `log.format` (`common` default or `json`), `log.filePath` (stdout by default).
- **Access logs:** `accessLog: {}` for stdout, `filePath`, JSON format via `accessLog.format: json`. Redact the `Authorization` header with `accessLog.fields.headers.names` set to `drop`/`redact` (keep it off by default; never log prompts).
- **Metrics:** `metrics.prometheus: {}` (served on the `traefik` entrypoint unless `metrics.prometheus.entryPoint` is set; check `metrics.md` for the default) or OTLP. Labels for entrypoints, routers and services are toggled by `addEntryPointsLabels`, `addRoutersLabels`, `addServicesLabels`.
- **Health:** `ping` and `traefik healthcheck --ping`.
- **Live view:** `curl -fsS http://127.0.0.1:8080/api/http/routers | jq` and `/api/rawdata` (only where the API is reachable).
- Feed to `llm-observability` for dashboards; request-level token metrics come from LiteLLM, not Traefik.
