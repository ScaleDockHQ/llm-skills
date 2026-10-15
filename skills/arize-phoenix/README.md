# Arize Phoenix

An agent skill for installing, operating and integrating Arize Phoenix, the open-source LLM tracing, evaluation and prompt playground server. It covers running it with pip, Docker, Docker Compose with PostgreSQL or Helm, enabling authentication, sending OpenInference or raw OTLP traces from Python and TypeScript apps, LiteLLM and vLLM, routing traces to projects, hiding content, retention, upgrades (including the no-downgrade migration rule) and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill arize-phoenix
```

## Rules

- **Ask before changing the system.** Installs, exposure, enabling auth, upgrades, retention and deletes need approval and an undo path.
- **Secrets never touch output.** `PHOENIX_SECRET`, system API keys, the admin password and database URLs live in `0600` env files or Kubernetes secrets.
- **Pin the image and back up first.** Migrations are not reversed on rollback; restore the backup instead.
- **Auth is off by default.** Enable it or keep port 6006 private behind TLS; auth stops anonymous ingestion until senders carry a key.
- **Persist the data.** Mount a volume or use PostgreSQL; retention is infinite by default.
- **Content capture is a written decision.** Hide it at the instrumentor or a Collector before Phoenix.
- **Verify upstream.** Versions and variables come from the Phoenix docs and releases at use time.

## References

- [`references/install.md`](references/install.md): ports, pip, Docker, Compose with PostgreSQL, Helm, storage.
- [`references/configuration.md`](references/configuration.md): environment variables, auth and API keys, network egress, health endpoints.
- [`references/tracing.md`](references/tracing.md): `phoenix.otel`, OpenInference, raw OTLP, projects, GenAI semconv ingest.
- [`references/privacy-retention.md`](references/privacy-retention.md): `OPENINFERENCE_HIDE_*`, retention policies, canary test.
- [`references/updating.md`](references/updating.md): releases, migrations, Kubernetes initContainer.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm.md`](references/combos/litellm.md): LiteLLM proxy and SDK to Phoenix.
- [`references/combos/vllm-and-openai-compatible.md`](references/combos/vllm-and-openai-compatible.md): vLLM and OpenAI-compatible servers.

**Templates and scripts:**

- [`assets/docker-compose.yaml`](assets/docker-compose.yaml): Phoenix plus PostgreSQL, loopback ports, auth on (validated with `docker compose config`).
- [`assets/otel-collector.yaml`](assets/otel-collector.yaml): Collector that strips content and routes to a project (validated with `otelcol-contrib validate`).
- [`scripts/check.sh`](scripts/check.sh): read-only health, version and API check.

## Companion skills

- `llm-observability`: choosing and combining tracing backends.
- `opentelemetry-genai`: GenAI semantic conventions and Collector patterns.
- `openllmetry`: an alternative instrumentation library.
- `litellm`, `vllm`, `langfuse`.

## License

MIT
