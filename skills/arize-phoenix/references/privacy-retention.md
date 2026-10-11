# Phoenix: privacy, content hiding and retention

> Verified against Arize Phoenix v20.21.0 and OpenInference (docs: tracing/how-to-tracing/advanced/masking-span-attributes, settings/data-retention, self-hosting/security/privacy, MIGRATION.md), 2026-10-11

Phoenix stores whatever the spans carry: prompts, completions, tool arguments, retrieved documents, user and session IDs. Treat the database as a content store.

## Where data lands

| Place                               | Contents                                                   | Control                                                                                                             |
| ----------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| SQLite file or PostgreSQL           | Spans, annotations, datasets, experiments, prompts         | Retention policy, backups, access control                                                                           |
| Working dir (`PHOENIX_WORKING_DIR`) | SQLite, exports                                            | Volume permissions                                                                                                  |
| Phoenix agent sessions              | Chats with the built-in assistant (20.0.0+)                | Default: deleted after 30 idle days, max 30 per user; temporary chats after 24 hours; limits in Settings, Assistant |
| Server logs                         | Operational logs                                           | Log rotation; `PHOENIX_LOG_SQL` is off by default                                                                   |
| Arize                               | Nothing from your data when self-hosted; UI analytics only | `PHOENIX_TELEMETRY_ENABLED=false`                                                                                   |

## Hide content at the source (OpenInference)

Instrumentors honour these variables (or a `TraceConfig` in code; precedence is code, then environment, then defaults):

| Variable                                                                               | Hides                                                                               |
| -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `OPENINFERENCE_HIDE_INPUTS`                                                            | Input value, all input messages, embedding input text (also hides tool definitions) |
| `OPENINFERENCE_HIDE_OUTPUTS`                                                           | Output value and all output messages                                                |
| `OPENINFERENCE_HIDE_INPUT_MESSAGES` / `_OUTPUT_MESSAGES`                               | Message lists only                                                                  |
| `OPENINFERENCE_HIDE_INPUT_TEXT` / `_OUTPUT_TEXT`                                       | Text parts, keeps structure                                                         |
| `OPENINFERENCE_HIDE_INPUT_IMAGES`                                                      | Images in input messages                                                            |
| `OPENINFERENCE_HIDE_EMBEDDING_VECTORS`                                                 | Returned vectors                                                                    |
| `OPENINFERENCE_HIDE_LLM_INVOCATION_PARAMETERS`, `_HIDE_LLM_PROMPTS`, `_HIDE_LLM_TOOLS` | Parameters, prompt attributes, tool definitions                                     |
| `OPENINFERENCE_BASE64_IMAGE_MAX_LENGTH`                                                | Truncation size for base64 images (default 32,000)                                  |

```python
from openinference.instrumentation import TraceConfig
from openinference.instrumentation.openai import OpenAIInstrumentor
OpenAIInstrumentor().instrument(tracer_provider=tracer_provider, config=TraceConfig(hide_inputs=True, hide_outputs=True))
```

All variables are booleans defaulting to `False`, so **content is captured by default**. A Collector can strip what instrumentors leave: `assets/otel-collector.yaml` deletes `gen_ai.*` content attributes and the `llm.input_messages`/`llm.output_messages` families before Phoenix. Phoenix converts OTel `gen_ai.*` content into message attributes, so strip before ingest rather than after.

## Retention

- Default is **infinite** (`PHOENIX_DEFAULT_RETENTION_POLICY_DAYS=0`). Retention policies exist since 9.0 and are time-based or trace-count-based; one `Default` policy applies to every project unless a project overrides it in the UI. Cleanup runs on a schedule (weekly by default per the policy).
- Set the deployment default: `PHOENIX_DEFAULT_RETENTION_POLICY_DAYS=30`, or Helm `database.defaultRetentionPolicyDays: 30`. Changing the variable updates the default policy for new projects but does not rewrite existing project-specific policies.
- Retention does not shrink SQLite files by itself; run a vacuum during a maintenance window, and plan PostgreSQL autovacuum.
- You can also delete projects, traces, datasets, experiments and prompts through the UI and REST API. Deletion is not gated and not reversible; back up first.

## Access

- With auth on, roles and system API keys control access; without auth, everyone who reaches the port reads everything. See `configuration.md`.
- Dashboards and shared links expose content to everyone with project access.

## Decision record (fill before real traffic)

- Environment: dev / staging / prod. Content captured: yes / no / hashed. Hiding mechanism: `OPENINFERENCE_HIDE_*` / Collector / none.
- Retention days per project. Backups included? yes / no. Who is an admin. Is the Playground allowed to call external providers.
- Owner and review date.

## Canary test

- [ ] Send a request containing `PRIVACY-CANARY-<date>` and a fake email through each path (app, gateway, engine).
- [ ] Search every sink for the marker: Phoenix span search, the database (`SELECT count(*) FROM spans WHERE attributes::text LIKE '%PRIVACY-CANARY%'` in PostgreSQL, read-only), gateway logs.
- [ ] With content off it must appear nowhere; repeat after every upgrade of Phoenix, instrumentors or gateways.
- [ ] Confirm retention works: the oldest trace date moves forward after the scheduled run.

## Pitfalls

- "Hide inputs" does not remove metadata: user IDs, session IDs, custom attributes and error messages still flow.
- Temporary content capture for debugging becomes permanent; give every "on" decision an end date.
- Secrets pasted into prompts become long-lived stored secrets.
