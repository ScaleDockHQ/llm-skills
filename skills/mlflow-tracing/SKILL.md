---
name: mlflow-tracing
description: Self-host MLflow as an LLM tracing backend, with OTLP ingest at /v1/traces and the mlflow.*.autolog SDK. Covers pip, Docker, Compose and Helm installs, auth, sending traces from apps, LiteLLM, vLLM and OpenAI-compatible endpoints, masking, archival, deletion, upgrades. Use for MLflow traces, 403 Invalid Host header, missing x-mlflow-experiment-id, or no spans. Not for model registry or training.
license: MIT
compatibility: Commands assume bash, curl, jq, Python 3.10+ for pip installs and Docker or kubectl and Helm for server deployments. Installing, exposing the server, enabling auth, archival, upgrades and deleting traces need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# MLflow Tracing

A self-hosted LLM trace store: MLflow (Apache-2.0) Tracking Server with its trace UI, search, evaluation and feedback, fed either by MLflow's own SDK (`mlflow.openai.autolog()` and dozens of framework integrations) or by any OpenTelemetry client over OTLP/HTTP at `/v1/traces` (MLflow 3.6.0+).

**Scope:** running the Tracking Server for traces and sending traces to it. Model registry, training runs, the AI Gateway and evaluation workflows are mentioned only where they affect tracing. Backend choice belongs to `llm-observability`; the OTel vocabulary and Collector belong to `opentelemetry-genai`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
pip show mlflow mlflow-tracing 2>/dev/null | grep -E '^(Name|Version)' || true
curl -fsS https://pypi.org/pypi/mlflow/json | jq -r .info.version                  # newest release
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' 2>/dev/null | grep -i mlflow || true
env | cut -d= -f1 | grep -E '^(MLFLOW_|OTEL_EXPORTER)' || true                     # names only
MLFLOW_URL="${MLFLOW_TRACKING_URI:-http://localhost:5000}"
curl -fsS -m 5 "$MLFLOW_URL/version" ; echo; curl -fsS -m 5 -o /dev/null -w 'health %{http_code}\n' "$MLFLOW_URL/health"
```

Ask only what discovery cannot show: single machine or team server, which database (SQLite is fine alone, PostgreSQL for teams), who may read traces, whether apps use the MLflow SDK or OpenTelemetry, whether prompts may be stored, retention needs.

## Decision flow

1. **Install and run the server:** pip, Docker, Compose, Helm. -> `references/install.md`
2. **Configure storage, auth, hosts and network:** -> `references/configuration.md`
3. **Send traces:** SDK autolog or OTLP, experiment IDs, Collector, gRPC limitation. -> `references/tracing.md`
4. **LiteLLM, vLLM, Ollama, OpenAI-compatible endpoints:** -> `references/gateways-and-engines.md`
5. **Content, masking, retention, archival, deletion:** -> `references/privacy-retention.md`
6. **Upgrade:** -> `references/updating.md`
7. **403, 422, no traces, search finds nothing:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, binding beyond localhost, enabling auth or workspaces, archival (irreversible), upgrades and trace deletion (irreversible) need approval and a rollback or backup.
- **Secrets never touch output.** The admin password, `MLFLOW_FLASK_SERVER_SECRET_KEY`, database URLs and tokens live in `0600` env files or Kubernetes secrets, passed with `--env-file` or `valueFrom`.
- **OTLP needs a SQL backend and HTTP.** `/v1/traces` works only with a SQL store, only over OTLP/HTTP (gRPC is not supported), and routes by the `x-mlflow-experiment-id` header, which takes the numeric experiment ID, not the name.
- **Set `--allowed-hosts` when the Host header is not localhost or a private IP.** Otherwise requests fail with 403 "Invalid Host header".
- **Auth is off by default.** Anyone who can reach the port can read traces and write data. Bind to loopback or put authentication in front.
- **Telemetry is on by default.** Open-source MLflow sends anonymized usage data unless `MLFLOW_DISABLE_TELEMETRY=true` or `DO_NOT_TRACK=true` is set on the server and clients; decide and write it down.
- **Do not install `mlflow` and `mlflow-tracing` in the same environment.** Apps that only trace use `mlflow-tracing`.
- **One layer owns each LLM call.** No MLflow autolog plus a gateway callback plus an OTel instrumentation for the same call.
- **Verify upstream.** Versions, flags and variables come from mlflow.org/docs (append `.md`) and the releases at use time.

## Workflows

### First trace (local)

- [ ] `pip install mlflow` in a virtualenv, `mlflow server --host 127.0.0.1 --port 5000` -> `references/install.md`.
- [ ] Create an experiment, note its numeric ID (`curl -sS -X POST "$MLFLOW_URL/api/2.0/mlflow/experiments/create" -H 'Content-Type: application/json' -d '{"name":"llm-app"}'`).
- [ ] App: `mlflow.set_tracking_uri(...)`, `mlflow.set_experiment(...)`, `mlflow.openai.autolog()`; or OTLP variables -> `references/tracing.md`.
- [ ] Make one call and find the trace in the UI.

### Team server

- [ ] PostgreSQL backend, artifact store, `--allowed-hosts`, auth or reverse proxy, TLS -> `references/configuration.md`.
- [ ] Compose or Helm -> `references/install.md`.
- [ ] Telemetry decision, archival and deletion policy -> `references/privacy-retention.md`.

### Privacy and retention

- [ ] Fill the decision record, run the canary test -> `references/privacy-retention.md`.

### Update

- [ ] Backup, pin, read release notes, upgrade, verify -> `references/updating.md`.

## Reference index

| File                                 | Read when                                                                 |
| ------------------------------------ | ------------------------------------------------------------------------- |
| `references/install.md`              | pip, Docker, Compose, Helm, ports, volumes, first start                   |
| `references/configuration.md`        | Backend and artifact stores, auth, hosts, CORS, workspaces, telemetry     |
| `references/tracing.md`              | Autolog, manual tracing, OTLP ingest, Collector, export to other backends |
| `references/gateways-and-engines.md` | LiteLLM proxy and SDK, vLLM, Ollama, OpenAI-compatible servers            |
| `references/privacy-retention.md`    | Content, masking, archival, deletion, canary test                         |
| `references/updating.md`             | Releases, DB migrations, rollback                                         |
| `references/troubleshooting.md`      | Symptom to cause to fix                                                   |

Assets and scripts: `assets/docker-compose.yaml` (MLflow plus PostgreSQL, loopback ports, secrets required), `scripts/check.sh` (read-only health, version, experiments and OTLP route check).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-observability`: choosing and combining tracing backends.
- `opentelemetry-genai`: GenAI semantic conventions and Collector configs in front of MLflow.
- `litellm`, `vllm`: gateway and engine whose calls are traced.
- `arize-phoenix`, `langfuse`: alternative backends.
