# Milvus basics: REST v2 and pymilvus

> Verified against Milvus v3.0.2 (milvus-docs v3.0.x create-collection, single-vector-search), 2026-10-11

Read the token from a `0600` file, never type it inline.

```bash
set -a; . ~/milvus/client.env; set +a        # MILVUS_TOKEN=root:<password>, MILVUS_URL=http://127.0.0.1:19530
H=(-H "Authorization: Bearer $MILVUS_TOKEN" -H 'Content-Type: application/json')

curl -fsS "${H[@]}" -X POST $MILVUS_URL/v2/vectordb/collections/list -d '{}' | jq
curl -fsS "${H[@]}" -X POST $MILVUS_URL/v2/vectordb/collections/create \
  -d '{"collectionName":"docs","dimension":1024}' | jq              # quick setup: id + vector fields
curl -fsS "${H[@]}" -X POST $MILVUS_URL/v2/vectordb/entities/insert \
  -d "{\"collectionName\":\"docs\",\"data\":[{\"id\":1,\"vector\":$V}]}" | jq
curl -fsS "${H[@]}" -X POST $MILVUS_URL/v2/vectordb/entities/search \
  -d "{\"collectionName\":\"docs\",\"data\":[$V],\"annsField\":\"vector\",\"limit\":3}" | jq
```

`$V` is a JSON array from LiteLLM `/v1/embeddings` (see `combos/llm-stack.md`). The quick-setup form of `collections/create` with only `dimension` is shown in upstream's quick-start; for custom fields, schema and `indexParams` use the full form from the create-collection guide (the same endpoint with a `schema` and `indexParams` body).

pymilvus equivalent:

```python
from pymilvus import MilvusClient
c = MilvusClient(uri="http://127.0.0.1:19530", token="root:<password>")
c.create_collection("docs", dimension=1024)
```

Health and metrics: `GET :9091/healthz`, Prometheus metrics at `:9091/metrics`; WebUI at `:9091/webui/`.

Consistency, partitions and partition keys, hybrid search, full-text BM25 and sparse vectors are covered in the upstream user guide; load a collection before searching (quick setup loads automatically; custom setups need `load`).
