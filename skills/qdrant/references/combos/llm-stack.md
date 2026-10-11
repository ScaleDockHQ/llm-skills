# Qdrant beside LiteLLM, llama-swap and Open WebUI

> Verified against Qdrant v1.19.2, LiteLLM v1.105.0 and Open WebUI docs (env-configuration, VECTOR_DB), 2026-10-11

## LiteLLM `/v1/embeddings`

LiteLLM does not proxy Qdrant; it serves the embedding model your app uses to build vectors. Register the embedder (here TEI, see the `text-embeddings-inference` skill) and keep the dimension in step with the collection:

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

Check the dimension: `curl $LITELLM/v1/embeddings ... | jq '.data[0].embedding|length'` and create the collection with that size.

## llama-swap

Not applicable to Qdrant: it is a database, not a model process. If your embedder is behind llama-swap, point LiteLLM at that entry (see the `llama-swap` skill); the vector store stays always on.

## Open WebUI

Open WebUI can use Qdrant as its vector store. Variables from its env reference: `VECTOR_DB=qdrant`, `QDRANT_URI`, `QDRANT_API_KEY`, `QDRANT_ON_DISK` (default false), `QDRANT_PREFER_GRPC` (default false), `QDRANT_GRPC_PORT` (default 6334). Open WebUI's docs recommend a client-server store such as Qdrant for multi-worker deployments instead of the default Chroma `PersistentClient`. Its embedding model and RAG settings belong to Open WebUI's own skill. Changing the embedding model requires re-indexing.

## Network layout

Put Qdrant, TEI/Infinity, LiteLLM and the apps on one Docker network named `llm`; publish only LiteLLM and the front end.
