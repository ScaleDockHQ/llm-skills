---
name: langfuse
description: Langfuse, open-source LLM observability with traces, prompt management, evals and scores. Use to self-host it (Docker Compose, Helm), send traces from Python/JS SDKs, OTLP or LiteLLM, manage prompts and datasets, set retention and masking, upgrade v3 to v4, or fix 404 on /api/public/otel, gRPC unsupported, Not enough privileges, NEXTAUTH_URL loops. Not for choosing a tracing stack (llm-observability).
license: MIT
compatibility: Commands assume bash, curl, jq, openssl and Docker Compose (Helm path covered). Needs ~4 cores and 16 GiB for self-hosting. Installs, exposure, upgrades and data deletion need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Langfuse

A working Langfuse (`langfuse/langfuse`, images `langfuse/langfuse` and `langfuse/langfuse-worker`, MIT core with an Enterprise `ee/` license) that receives traces from apps and gateways, stores prompts and datasets, runs evaluators, and is operated safely: private, with retention and masking decided, and upgrades planned.

**Scope:** this one product: install, ingest, prompts and evals, privacy and retention, update, troubleshoot. Choosing between Langfuse, Phoenix, OpenLLMetry or plain OpenTelemetry, Prometheus metrics, GPU metrics and alerting belong to the `llm-observability` skill. Running the LiteLLM proxy belongs to the `litellm` skill.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -Ei 'langfuse|clickhouse|minio|redis|postgres' || true
helm list -A 2>/dev/null | grep -i langfuse || true
find ~ -maxdepth 4 \( -name 'docker-compose*.y*ml' -o -name 'langfuse*.env*' \) 2>/dev/null | xargs grep -li langfuse 2>/dev/null | head
env | cut -d= -f1 | grep -E '^(LANGFUSE|NEXTAUTH|OTEL_EXPORTER)' || true          # names only
curl -fsS -m 5 "${LANGFUSE_HOST:-http://localhost:3000}/api/public/health"          # web
curl -fsS -m 5 http://localhost:3030/api/health                                       # worker
gh api repos/langfuse/langfuse/releases/latest --jq .tag_name                         # newest release
```

Ask only what discovery cannot show: Cloud or self-hosted, one VM or Kubernetes, who sends traces (Python, JS, LiteLLM, OTel), whether prompts may be stored at all and for how long, whether an Enterprise license exists.

## Decision flow

1. **No instance, no infrastructure appetite:** Langfuse Cloud (EU, US, Japan, HIPAA regions are separate accounts); self-host only if data must stay on your network.
2. **Self-host, trial or one team:** Docker Compose from `assets/`, no HA, no backups. -> `references/install.md`
3. **Self-host, production:** Helm with managed Postgres, ClickHouse and S3. -> `references/install.md`
4. **Instance up, no traces:** SDK, OTLP, Collector or LiteLLM callback. -> `references/tracing.md`, `references/combos/litellm.md`, `references/combos/otel-collector.md`
5. **Prompts, datasets, scores, judges:** -> `references/prompts-evals-scores.md`
6. **Content, retention, access:** decide before real traffic. -> `references/privacy-retention.md`
7. **Env vars, auth, SSO, ports, health:** -> `references/configuration.md`
8. **New release or a v3 install:** -> `references/updating.md`
9. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, exposure, upgrades, retention settings and any data deletion need approval and an undo path (backup, recorded image digest).
- **Secrets never touch output.** Keys, `SALT`, `ENCRYPTION_KEY`, `NEXTAUTH_SECRET` and store passwords live in `0600` env files or Kubernetes secrets; generate with `scripts/gen-env.sh`, check presence by name only.
- **Never change `SALT`** after API keys exist; keep a copy of `ENCRYPTION_KEY`, losing it breaks stored encrypted secrets.
- **Pin the image.** Exact tags (`4.56.0`), not `latest`; record digests before upgrades. Upstream's floating `:4` upgrades silently.
- **Prompts are sensitive data.** Content capture is a written decision per environment. Retention is Enterprise when self-hosted; without it data is kept forever, so mask at the client or keep content out.
- **Expose only the web container.** Put TLS in front of port 3000; keep Postgres, ClickHouse, Redis, the worker and the MinIO console private. MinIO's S3 port must be browser-reachable only if you use media uploads.
- **HTTP only for OTLP.** gRPC is not supported; the endpoint is `<host>/api/public/otel` with Basic auth and `x-langfuse-ingestion-version: 4`.
- **Verify upstream.** Versions, env vars and defaults come from langfuse.com docs (append `.md` to any page) and GitHub releases at use time, not memory.

## Workflows

### Install and first trace

- [ ] Choose Cloud, Compose or Helm -> `references/install.md`.
- [ ] Compose: copy `assets/docker-compose.yaml`, run `scripts/gen-env.sh`, `docker compose up -d`, wait for "Ready".
- [ ] `LANGFUSE_HOST=... scripts/check.sh`; sign up (or headless init), create a project, store its keys in a `0600` file.
- [ ] Send one trace from the SDK or OTLP -> `references/tracing.md`; find it in Observations.

### Connect a gateway or app

- [ ] LiteLLM: `callbacks: ["langfuse_otel"]` with keys and `LANGFUSE_OTEL_HOST` -> `references/combos/litellm.md`.
- [ ] Other OTel sources or content stripping: Collector -> `references/combos/otel-collector.md`.
- [ ] Put user, session and tags on every span.

### Prompts and evals

- [ ] Create a prompt with a `production` label, fetch it from the app -> `references/prompts-evals-scores.md`.
- [ ] Build a dataset, run an experiment, add an evaluator; give evaluators an LLM API they can reach.

### Privacy and retention

- [ ] Fill the decision record: content on or off, masking mode, retention, who has access -> `references/privacy-retention.md`.
- [ ] Disable open sign-up or enforce SSO -> `references/configuration.md`.
- [ ] Run the canary test; repeat after every upgrade.

### Update

- [ ] Minor: back up, bump the pinned tag, `docker compose pull && up -d`, run `scripts/check.sh` -> `references/updating.md`.
- [ ] v3 to v4: infrastructure first, then server in a chosen write mode, then SDKs and cutover -> `references/updating.md`.

## Reference index

| File                                  | Read when                                                         |
| ------------------------------------- | ----------------------------------------------------------------- |
| `references/install.md`               | Architecture, Compose, Helm, ports, headless init, sizing         |
| `references/configuration.md`         | Env vars, auth and SSO, networking, health endpoints, EE features |
| `references/tracing.md`               | Python and JS SDKs, OTLP, attributes, masking hooks, pitfalls     |
| `references/prompts-evals-scores.md`  | Prompt management, scores, datasets, evaluators, API and CLI      |
| `references/privacy-retention.md`     | Content stores, retention, masking, access, canary test           |
| `references/updating.md`              | Releases, pinning, upgrades, Helm chart v2, v3 to v4              |
| `references/troubleshooting.md`       | Symptom to cause to fix                                           |
| `references/combos/litellm.md`        | LiteLLM proxy traces and costs in Langfuse                        |
| `references/combos/otel-collector.md` | Collector in front of Langfuse, content stripping, fan-out        |

Templates: `assets/docker-compose.yaml`, `assets/langfuse.env.example`, `assets/otel-collector.yaml`. Scripts: `scripts/gen-env.sh` (random secrets, mode 0600), `scripts/check.sh` (health and key check).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-observability`: choosing and combining tracing backends, plus Prometheus, Grafana, GPU metrics and alerting around Langfuse.
- `litellm`: the gateway whose callbacks send traces here.
- `llm-gateway`: whether to use a gateway and which one.
- `llm-evals`: eval methodology and golden sets that datasets and scores implement.
