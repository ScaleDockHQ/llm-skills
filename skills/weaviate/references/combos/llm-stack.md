# Weaviate beside LiteLLM, TEI, llama-swap and Open WebUI

> Verified against Weaviate v1.40.0, LiteLLM v1.105.0 and Open WebUI docs (env-configuration, WEAVIATE_*), 2026-10-11

## LiteLLM `/v1/embeddings`

Unlike the other stores, Weaviate can call the embedding endpoint itself through `text2vec-openai`. It builds `baseURL + endpoint` with `endpoint` defaulting to `/v1/embeddings`, so both LiteLLM (`http://litellm:4000`) and TEI (`http://tei-embed:80`) work as `baseURL`. LiteLLM does not proxy Weaviate; it serves the embedding model.

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

Set `OPENAI_APIKEY` in `weaviate.env` to a LiteLLM virtual key (or send `X-OpenAI-Api-Key` per request), `baseURL` to `http://litellm:4000` in the collection's `text2vec-openai` config, and `model` to `embed-default`. Put Weaviate and LiteLLM on one Docker network. A model or dimension change means a new collection.

To avoid vectorizer modules entirely, create classes with `vectorizer: none` and send vectors computed through LiteLLM (see `api.md`).

## llama-swap

Not applicable: Weaviate is a database. If your embedder sits behind llama-swap, point LiteLLM at that entry; Weaviate's calls then pass through LiteLLM and can trigger a model load on the first request (raise timeouts).

## Open WebUI

Open WebUI supports Weaviate. Variables from its env reference: `VECTOR_DB=weaviate`, `WEAVIATE_HTTP_HOST`, `WEAVIATE_HTTP_PORT`, `WEAVIATE_HTTP_SECURE`, `WEAVIATE_GRPC_HOST`, `WEAVIATE_GRPC_PORT`, `WEAVIATE_GRPC_SECURE`, `WEAVIATE_API_KEY`. Open WebUI computes embeddings itself with its own embedding engine, so Weaviate's vectorizer module is not needed there. Open WebUI's own skill covers RAG settings; re-index after an embedding model change.
