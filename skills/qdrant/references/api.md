# Qdrant REST workflow

> Verified against Qdrant v1.19.2 (docs installation, security, snapshots, monitoring), 2026-10-11

Authenticate with the `api-key` header. Load the key from the env file; never paste it.

```bash
set -a; . ~/qdrant/qdrant.env; set +a
Q=http://127.0.0.1:6333; H="api-key: $QDRANT__SERVICE__API_KEY"

# Health (no auth needed for probes in most setups; test it)
curl -fsS $Q/readyz -o /dev/null -w '%{http_code}\n'

# Create a collection (size must equal the embedding model's dimension)
curl -fsS -X PUT $Q/collections/docs -H "$H" -H 'content-type: application/json' \
  -d '{"vectors":{"size":1024,"distance":"Cosine"}}'

# Embed through LiteLLM, then upsert
V=$(curl -fsS $LITELLM/v1/embeddings -H "Authorization: Bearer $LITELLM_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"embed-default","input":["Qdrant stores vectors."]}' | jq -c '.data[0].embedding')
curl -fsS -X PUT "$Q/collections/docs/points?wait=true" -H "$H" -H 'content-type: application/json' \
  -d "{\"points\":[{\"id\":1,\"vector\":$V,\"payload\":{\"text\":\"Qdrant stores vectors.\"}}]}"

# Query
curl -fsS -X POST $Q/collections/docs/points/query -H "$H" -H 'content-type: application/json' \
  -d "{\"query\":$V,\"limit\":3,\"with_payload\":true}" | jq '.result.points[]|{id,score,payload}'

# Inspect
curl -fsS $Q/collections/docs -H "$H" | jq '.result|{status,points_count,config:.config.params.vectors}'
curl -fsS $Q/collections -H "$H" | jq -r '.result.collections[].name'
```

- Embed queries and documents with the same model and the same prompt conventions.
- Batch upserts (hundreds of points per request) with `wait=true` only when you need read-after-write.
- Snapshots: `POST /collections/{c}/snapshots` creates, `GET` lists, restore via the snapshot upload endpoint with `priority=snapshot` (see `updating.md`).
- Health endpoints: `/healthz`, `/livez`, `/readyz`. Metrics: `/metrics` (Prometheus), `/telemetry`.
