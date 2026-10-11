# Observability and caching

> Verified against Bifrost gateway v2.2.6, 2026-10-11

Sources: <https://docs.getbifrost.ai/features/observability/default>, `/features/observability/prometheus`, `/features/observability/otel`, `/features/observability/content-logging`, `/features/semantic-caching`.

## Built-in logs

The UI shows request and response logs, latency and analytics, stored in the logs store (SQLite by default; PostgreSQL or ClickHouse for volume). Content logging controls whether prompt and response bodies are stored; read `observability/content-logging` and ask before storing sensitive prompts.

## Prometheus

The telemetry plugin is on by default and serves `GET /metrics` on the main port. With auth enabled, the scraper needs credentials (Basic auth with the admin credentials, or as the docs describe). Example metrics include `bifrost_upstream_requests_total` and `bifrost_upstream_latency_seconds`. Push Gateway mode exists for multi-node setups. Read the metrics page for the full list.

```bash
curl -sS -u "$BIFROST_ADMIN_USER:$BIFROST_ADMIN_PASSWORD" http://localhost:8080/metrics | grep '^bifrost_' | head
```

## OpenTelemetry and exports

OTel collectors, Datadog, Maxim, Kafka, BigQuery, Pub/Sub and Splunk integrations are documented under `features/observability/`. Pick one and follow its page; they are plugin configs in `config.json`.

## Semantic cache ("Local Cache" in the UI)

Same plugin (`semantic_cache`) with two modes: **direct** (exact hash, no embeddings) and **semantic** (embedding similarity). Facts from the docs:

- A **vector store is required for both** modes (Redis/Valkey, Weaviate, Qdrant or Pinecone).
- Caching engages only for requests with a cache key: header `x-bf-cache-key` (or `default_cache_key`). No key, no caching.
- When both modes run, direct is tried first, then semantic on a miss; `x-bf-cache-type` narrows to one.
- Semantic mode costs an embedding call on every direct miss.
- Entries persist across restarts with a per-entry expiry.

A shared cache key across unrelated prompts risks wrong answers; scope keys per equivalent request. Ask before enabling a vector store.
