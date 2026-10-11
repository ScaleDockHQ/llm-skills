# Xinference observability

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

## Health and status

```bash
curl -s http://127.0.0.1:9997/status                   # liveness, no auth
curl -s -H "Authorization: Bearer $(cat ~/.xinference-key)" http://127.0.0.1:9997/v1/cluster/version
curl -s -H "Authorization: Bearer $(cat ~/.xinference-key)" http://127.0.0.1:9997/v1/cluster/devices | jq .
xinference list -e http://127.0.0.1:9997
```

Startup health checks: `XINFERENCE_HEALTH_CHECK_INTERVAL` (5 s), `XINFERENCE_HEALTH_CHECK_TIMEOUT` (10 s),
`XINFERENCE_HEALTH_CHECK_FAILURE_THRESHOLD` (5), `XINFERENCE_DISABLE_HEALTH_CHECK=1`. A crashed model actor is
recovered automatically up to `XINFERENCE_MODEL_ACTOR_AUTO_RECOVER_LIMIT` (unset means no limit).

## Metrics

Supervisor: `<endpoint>/metrics` with `requests_total_counter`, `responses_total_counter`,
`exceptions_total_counter`, `status_codes_counter`. Workers expose their own exporter on
`--metrics-exporter-host` and `--metrics-exporter-port` (`xinference-local` or `xinference-worker`):
`xinference:generate_tokens_per_s`, `xinference:input_tokens_total_counter`,
`xinference:output_tokens_total_counter`, `xinference:time_to_first_token_ms`. `XINFERENCE_DISABLE_METRICS=1`
turns the exporters off. Metrics are not authenticated by the API key system: keep the exporter ports on a
private network.

## Logs

- Application log: written under `XINFERENCE_HOME/logs` on each node, rotating (size, backup count and retention
  are compiled defaults). `--log-level debug` on `xinference-local`, `xinference-supervisor` and `xinference-worker`.
- Web UI Log Center and `GET /v1/cluster/logs`, `/v1/cluster/logs/correlated`, `/v1/cluster/logs/nodes` (needs a
  logs permission) show runtime logs; request body capture and request IDs exist for model requests. Prompts may
  appear in request logs: restrict access.
- Audit: `/v1/audit/search`, retention `XINFERENCE_AUDIT_LOG_RETENTION_DAYS` (90) (`api-and-auth.md`).
- `xinference service logs` for service installs; `docker logs xinference` for containers.

## Per-launch progress

`GET /v1/models/<uid>/progress` (stages `waiting_for_dependencies`, `installing_dependencies`, `loading`),
`GET /v1/requests/<request_id>/progress`.
