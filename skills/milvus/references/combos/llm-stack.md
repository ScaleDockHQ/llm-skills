# Milvus beside LiteLLM, llama-swap and Open WebUI

> Verified against Milvus v3.0.2, LiteLLM v1.105.0 and Open WebUI docs (env-configuration, MILVUS_*), 2026-10-11

## LiteLLM `/v1/embeddings`

LiteLLM does not proxy Milvus; it serves the model that produces the vectors. Register your embedder (see `text-embeddings-inference` or `infinity`) and create the collection with the same dimension:

```yaml
model_list:
  - model_name: embed-default
    litellm_params:
      model: openai/Qwen/Qwen3-Embedding-0.6B
      api_base: http://tei-embed:80/v1
      api_key: os.environ/TEI_API_KEY
    model_info:
      mode: embedding
```

```bash
V=$(curl -fsS $LITELLM/v1/embeddings -H "Authorization: Bearer $LITELLM_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"embed-default","input":["Milvus stores vectors."]}' | jq -c '.data[0].embedding')
echo "$V" | jq length      # must equal the collection dimension
```

## llama-swap

Not applicable: Milvus is a database service. If the embedder runs behind llama-swap, point LiteLLM at that entry.

## Open WebUI

Open WebUI supports Milvus. Variables from its env reference: `VECTOR_DB=milvus`, `MILVUS_URI` (required; a server URL or a local Lite file path), `MILVUS_DB`, `MILVUS_TOKEN` (required for remote connections with authentication), `MILVUS_INDEX_TYPE`, `MILVUS_METRIC_TYPE`, `MILVUS_HNSW_M`, `MILVUS_HNSW_EFCONSTRUCTION`, `MILVUS_IVF_FLAT_NLIST`, `MILVUS_DISKANN_*`, `MILVUS_COLLECTION_PREFIX`. Use a dedicated Milvus user, put the token in an env file, and re-index after changing the embedding model. Open WebUI's own skill covers RAG settings.
