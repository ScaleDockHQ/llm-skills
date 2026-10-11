# MLflow Tracing

An agent skill for running MLflow as a self-hosted LLM trace store and sending traces to it. It covers installing the Tracking Server with pip, Docker, Compose with PostgreSQL and Helm, storage and authentication, Host validation, the OTLP endpoint at `/v1/traces` and the `mlflow.*.autolog()` SDK, LiteLLM, vLLM and OpenAI-compatible endpoints, masking, archival and deletion, upgrades with schema migration, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill mlflow-tracing
```

## Rules

- **Ask before changing the system.** Installs, exposure, auth, archival, upgrades and deleting traces need approval and a backup.
- **Secrets never touch output.** Admin password, Flask secret key, database URLs and tokens live in `0600` env files or Kubernetes secrets.
- **OTLP needs a SQL store, HTTP and the experiment header.** gRPC is not supported; the header takes the numeric experiment ID.
- **Set `--allowed-hosts`** for any Host other than localhost or a private IP, or requests fail with 403.
- **Auth and telemetry are decisions.** Auth is off and usage telemetry is on by default.
- **Verify upstream.** Versions, flags and variables come from mlflow.org/docs and releases at use time.

## References

- [`references/install.md`](references/install.md): pip, Docker, Compose, Helm.
- [`references/configuration.md`](references/configuration.md): stores, hosts, auth, workspaces, telemetry.
- [`references/tracing.md`](references/tracing.md): autolog, OTLP ingest, Collector, export.
- [`references/gateways-and-engines.md`](references/gateways-and-engines.md): LiteLLM, vLLM, Ollama, OpenAI-compatible.
- [`references/privacy-retention.md`](references/privacy-retention.md): masking, archival, deletion, canary.
- [`references/updating.md`](references/updating.md): upgrades and schema migration.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

**Assets and scripts:**

- [`assets/docker-compose.yaml`](assets/docker-compose.yaml): MLflow with PostgreSQL and basic auth, loopback only.
- [`scripts/check.sh`](scripts/check.sh): read-only health, version, experiments and OTLP route check.

## Companion skills

- `llm-observability`: choosing a stack.
- `opentelemetry-genai`: semantic conventions and Collector.
- `litellm`, `vllm`: gateway and engine.
- `arize-phoenix`, `langfuse`: alternative backends.

## License

MIT
