# Langfuse

An agent skill for installing, operating and integrating Langfuse, the open-source LLM observability, prompt management and evaluation platform. It covers self-hosting the v4 stack (web, worker, ClickHouse, Redis, Postgres, S3-compatible storage) with Docker Compose or Helm, sending traces from the Python and JS/TS SDKs, raw OTLP, OpenTelemetry Collectors and LiteLLM, prompts, scores, datasets and evaluators, privacy, masking and retention, upgrades including v3 to v4, and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill langfuse
```

## Rules

- **Ask before changing the system.** Installs, exposure, upgrades, retention and deletion need approval and an undo path.
- **Secrets never touch output.** Keys and passwords live in `0600` files; `scripts/gen-env.sh` generates them without printing.
- **Pin the image.** Exact tags and recorded digests, not floating tags.
- **Prompts are sensitive data.** Content capture, masking and retention are written decisions; retention is Enterprise when self-hosted.
- **Expose only the web container**, behind TLS. OTLP is HTTP only; gRPC is not supported.
- **Verify upstream.** Versions and variables come from the Langfuse docs and releases at use time.

## References

- [`references/install.md`](references/install.md): architecture and minimum versions, Compose, Helm, ports, headless init.
- [`references/configuration.md`](references/configuration.md): environment variables, auth and SSO, networking, health endpoints, Enterprise features.
- [`references/tracing.md`](references/tracing.md): Python and JS SDKs, OTLP, attribute propagation, masking hooks, pitfalls.
- [`references/prompts-evals-scores.md`](references/prompts-evals-scores.md): prompt management, scores, datasets, evaluators, API and CLI.
- [`references/privacy-retention.md`](references/privacy-retention.md): where content lands, retention, masking, access, canary test.
- [`references/updating.md`](references/updating.md): releases, pinning, upgrades, Helm chart v2, v3 to v4 migration.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm.md`](references/combos/litellm.md): LiteLLM proxy traces and costs in Langfuse.
- [`references/combos/otel-collector.md`](references/combos/otel-collector.md): Collector in front of Langfuse.

**Templates and scripts:**

- [`assets/docker-compose.yaml`](assets/docker-compose.yaml): hardened single-host stack (validated with `docker compose config`).
- [`assets/langfuse.env.example`](assets/langfuse.env.example): environment file template.
- [`assets/otel-collector.yaml`](assets/otel-collector.yaml): Collector config that strips GenAI content.
- [`scripts/gen-env.sh`](scripts/gen-env.sh): writes a `0600` env file with random secrets.
- [`scripts/check.sh`](scripts/check.sh): read-only health and key check.

## Upstream credits

- [Langfuse](https://github.com/langfuse/langfuse) (MIT core, Enterprise `ee/`), maintained by the Langfuse team at ClickHouse, Inc.
- [Langfuse Helm chart](https://github.com/langfuse/langfuse-k8s), [Python SDK](https://github.com/langfuse/langfuse-python), [JS/TS SDK](https://github.com/langfuse/langfuse-js).

## Companion skills

- `llm-observability`: choosing tracing backends, Prometheus, Grafana, GPU metrics and alerting.
- `litellm`: the gateway whose callbacks send traces to Langfuse.
- `llm-gateway`: whether to use a gateway and which one.
- `llm-evals`: eval methodology and golden sets.

## License

MIT
