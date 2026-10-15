---
name: arize-phoenix
description: Arize Phoenix, open-source LLM tracing, evals and prompt playground (arize-phoenix, arizephoenix/phoenix, phoenix serve). Use to self-host it (Docker, Postgres, Helm), send OpenInference or OTLP traces from apps, LiteLLM and vLLM, set auth, retention and content hiding, upgrade, or fix 401 on /v1/traces, empty projects, lost SQLite data. Not for choosing a tracing stack (llm-observability).
license: MIT
compatibility: Commands assume bash, curl, jq and Docker (Helm and pip paths covered). Production wants PostgreSQL 14 or newer. Installs, exposure, auth changes, upgrades and data deletion need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Arize Phoenix

A working Phoenix server (`Arize-ai/phoenix`, image `arizephoenix/phoenix`, PyPI `arize-phoenix`, Elastic License 2.0) that receives OpenTelemetry/OpenInference traces over HTTP and gRPC, stores them in SQLite or PostgreSQL, and is run safely: authenticated, with retention and content hiding decided, and upgrades planned.

**Scope:** this one product: install, ingest, privacy and retention, update, troubleshoot. Choosing between Phoenix, Langfuse, OpenLLMetry, MLflow or plain OpenTelemetry, Prometheus metrics and GPU metrics belong to the `llm-observability` skill. Running the LiteLLM proxy belongs to `litellm`, the engine to `vllm`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i phoenix || true
helm list -A 2>/dev/null | grep -i phoenix || true
command -v phoenix && pip show arize-phoenix 2>/dev/null | sed -n '1,2p'
env | cut -d= -f1 | grep -E '^(PHOENIX|OTEL_EXPORTER|OPENINFERENCE)' || true     # names only
curl -fsS -m 5 "${PHOENIX_COLLECTOR_ENDPOINT:-http://localhost:6006}/healthz"       # liveness
curl -fsS -m 5 "${PHOENIX_COLLECTOR_ENDPOINT:-http://localhost:6006}/arize_phoenix_version"
gh api repos/Arize-ai/phoenix/releases/latest --jq .tag_name                         # newest release
```

Ask only what discovery cannot show: laptop trial or shared server, SQLite or PostgreSQL, who sends traces (Python, JS, LiteLLM, vLLM, OTel Collector), whether prompts may be stored and for how long, whether the UI is reachable beyond the host.

## Decision flow

1. **Trial on one machine:** `phoenix serve` (pip) or one Docker container with a volume. -> `references/install.md`
2. **Shared or production:** Docker Compose with PostgreSQL, or Helm; auth on, pinned image. -> `references/install.md`, `references/configuration.md`
3. **Server up, no traces:** pick the sender. -> `references/tracing.md`, `references/combos/litellm.md`, `references/combos/vllm-and-openai-compatible.md`
4. **Content, retention, access:** decide before real traffic. -> `references/privacy-retention.md`
5. **New release:** -> `references/updating.md`
6. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, port exposure, enabling auth, upgrades, retention and deletes need approval and an undo path (database backup, recorded image digest).
- **Secrets never touch output.** `PHOENIX_SECRET`, system API keys, the admin password and database URLs live in `0600` env files or Kubernetes secrets; check presence by name only.
- **Pin the image.** Exact tags (`20.21.0`), not `latest`; migrations run on first start of a new major and are not reversed on rollback, so back up PostgreSQL first.
- **Auth is off by default.** Anyone who can reach port 6006 can read every prompt and write traces. Enable auth or keep the port on a private network behind TLS. Turning auth on stops anonymous trace ingestion until clients send a system API key.
- **Persist the data.** The default SQLite file lives in a temporary folder unless `PHOENIX_WORKING_DIR` or `PHOENIX_SQL_DATABASE_URL` is set; a container without a volume loses everything on recreate.
- **Retention is infinite by default** (`PHOENIX_DEFAULT_RETENTION_POLICY_DAYS=0`). Content capture is a written decision per environment; hide content at the instrumentor if it must not be stored.
- **Use the right path.** HTTP: `<host>:6006/v1/traces` (full path in code), gRPC: `<host>:4317`. `PHOENIX_COLLECTOR_ENDPOINT` takes a base URL for the env-driven helpers.
- **Verify upstream.** Versions, env vars and defaults come from arize.com/docs/phoenix (append `.md` to a page) and GitHub releases at use time, not memory.

## Workflows

### Install and first trace

- [ ] Choose pip, Docker, Compose or Helm -> `references/install.md`.
- [ ] Start it with a persistent volume or PostgreSQL; `scripts/check.sh` must print health and version.
- [ ] Send one trace from `phoenix.otel.register(...)` plus an OpenInference instrumentor -> `references/tracing.md`; find it in the project's Traces tab.

### Connect a gateway or engine

- [ ] LiteLLM proxy: `callbacks: ["arize_phoenix"]` with `LITELLM_OTEL_V2=true` -> `references/combos/litellm.md`.
- [ ] vLLM or other OpenAI-compatible servers: trace the client or gateway; vLLM's own spans via `--otlp-traces-endpoint` -> `references/combos/vllm-and-openai-compatible.md`.
- [ ] Route to a project with the `x-project-name` header (server 15.5.0+); never rely on a caller-chosen name for tenants.

### Privacy and retention

- [ ] Fill the decision record (content on/off, retention days, who has access) -> `references/privacy-retention.md`.
- [ ] Enable auth and create a system API key per sender -> `references/configuration.md`.
- [ ] Run the canary test; repeat after every upgrade.

### Update

- [ ] Read `MIGRATION.md` for the span between versions, back up, bump the pinned tag -> `references/updating.md`.

## Reference index

| File                                              | Read when                                                               |
| ------------------------------------------------- | ----------------------------------------------------------------------- |
| `references/install.md`                           | pip, Docker, Compose, Helm, ports, storage, sizing                      |
| `references/configuration.md`                     | Env vars, auth and API keys, reverse proxy, network egress, metrics     |
| `references/tracing.md`                           | `phoenix.otel`, OpenInference, raw OTLP, projects, GenAI semconv ingest |
| `references/privacy-retention.md`                 | Hide-content switches, retention policy, canary test, access            |
| `references/updating.md`                          | Releases, pinning, migrations, rollback limits, Kubernetes upgrades     |
| `references/troubleshooting.md`                   | Symptom to cause to fix                                                 |
| `references/combos/litellm.md`                    | LiteLLM proxy and SDK traces in Phoenix                                 |
| `references/combos/vllm-and-openai-compatible.md` | vLLM and self-hosted OpenAI-compatible endpoints                        |

Templates: `assets/docker-compose.yaml` (Phoenix plus PostgreSQL), `assets/otel-collector.yaml` (strip content, route to a project). Script: `scripts/check.sh` (read-only health, version and auth probe).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-observability`: choosing and combining tracing backends, plus Prometheus, Grafana and GPU metrics.
- `opentelemetry-genai`: the GenAI semantic conventions and Collector patterns Phoenix ingests.
- `openllmetry`: an alternative instrumentation library that can also send here.
- `litellm`: the gateway whose callback sends traces here.
- `vllm`: the engine that can emit its own spans.
- `langfuse`: the other self-hosted LLM tracing backend.
