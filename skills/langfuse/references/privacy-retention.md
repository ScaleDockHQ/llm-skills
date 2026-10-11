# Langfuse: privacy, masking and retention

> Verified against Langfuse v4.56.0 (docs: administration/data-retention, security/data-masking, observability/features/masking, license-key, security/telemetry, deployment/infrastructure/blobstorage), 2026-10-11

Langfuse stores everything sent to it: prompts, completions, tool arguments, user IDs, metadata. Treat it as the largest content store in the stack.

## Where data lands

| Place                    | Contents                                                   | Control                                                                |
| ------------------------ | ---------------------------------------------------------- | ---------------------------------------------------------------------- |
| ClickHouse               | Observations (input, output, metadata), scores             | Retention (EE), masking, access control                                |
| S3 / MinIO               | Raw ingested events (written first), media, batch exports  | Retention deletes objects too; versioned buckets need a lifecycle rule |
| Postgres                 | Users, projects, prompts, dataset items, encrypted secrets | Backups, access control                                                |
| Redis                    | Queue references, hashed API keys, cached prompts          | Network isolation, `requirepass`                                       |
| Worker logs, Docker logs | Operational logs                                           | Log rotation; `LANGFUSE_LOG_LEVEL`                                     |
| Telemetry                | Aggregated instance statistics, no content                 | `TELEMETRY_ENABLED=false`                                              |

## Retention

- Project data retention (traces, observations, scores, media) is **Enterprise Edition** when self-hosting. Without it, data is kept **indefinitely**. Minimum value 3 days; deletes run nightly; set per project (UI, Organization Management API, or `LANGFUSE_INIT_PROJECT_RETENTION` for the init project). There is no org-wide policy.
- It deletes traces, observations and scores (even those linked to datasets or experiments) and Langfuse-managed media, but not audit logs, datasets or dataset items. Dataset items keep their saved input and expected output after the source trace expires.
- Self-hosted deletion needs `s3:DeleteObject` on the buckets; Langfuse only issues deletes, so versioned buckets need a lifecycle rule for delete markers and old versions.
- Without a license: keep content out of traces (masking), or run your own deletion jobs against ClickHouse and S3 (test on a copy; ClickHouse deletes are mutations). To preserve data before deleting, use blob storage export.
- ClickHouse system logs (`trace_log`, `text_log`, `query_log` and similar) have no TTL by default and often dominate disk; Langfuse does not read them. See https://langfuse.com/faq/all/reduce-clickhouse-disk-size.

## Masking

| Approach                      | Where it runs                                                                  | Edition    |
| ----------------------------- | ------------------------------------------------------------------------------ | ---------- |
| Client-side SDK masking       | In your app, before data is sent                                               | OSS        |
| Server-side ingestion masking | Worker POSTs each OTel trace object to your callback, then stores the response | Enterprise |

Client-side is the only option that keeps data from ever leaving the application. Python SDK: `mask_otel_spans` (recommended) or legacy `mask`. Server-side variables on the worker: `LANGFUSE_INGESTION_MASKING_CALLBACK_URL`, `_TIMEOUT_MS` (default 500), `_FAIL_CLOSED` (default `false`, meaning events pass through unmasked if the callback fails), `LANGFUSE_INGESTION_MASKING_MAX_RETRIES` (default 1). Set fail-closed when masking is a compliance control. Events sit unmasked in blob storage until the worker processes them.

An OpenTelemetry Collector `attributes` processor can drop `gen_ai.input.messages`, `gen_ai.output.messages` and `gen_ai.system_instructions` before Langfuse (`assets/otel-collector.yaml`). Gateway callbacks have their own switches (LiteLLM `turn_off_message_logging`).

## Access

- Anyone with project access can read full prompts and outputs. Disable open sign-up (`AUTH_DISABLE_SIGNUP=true`), enforce SSO (`AUTH_DOMAINS_WITH_SSO_ENFORCEMENT`), and review members regularly.
- Project RBAC roles and audit logs are Enterprise.
- Keep the web UI behind TLS and, where possible, a VPN or IP allow-list; keep every store on a private network.

## Canary test (run after every change to SDKs, callbacks or masking)

- [ ] Send a request containing a fake marker such as `PRIVACY-CANARY-<date>` and a fake email.
- [ ] Search the Langfuse UI (observations full-text), the S3 event objects and the worker logs for the marker.
- [ ] With content capture off, it must appear nowhere. Record the result in the decision record.

For the cross-stack privacy review (metrics labels, gateway spend logs, llama-swap captures), install `llm-observability`: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.

## Official links

- https://langfuse.com/docs/administration/data-retention
- https://langfuse.com/self-hosting/security/data-masking
- https://langfuse.com/docs/observability/features/masking
- https://langfuse.com/self-hosting/license-key
- https://langfuse.com/self-hosting/security/telemetry
- https://langfuse.com/faq/all/reduce-clickhouse-disk-size
