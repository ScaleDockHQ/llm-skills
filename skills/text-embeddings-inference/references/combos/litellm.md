# TEI with LiteLLM

> Verified against text-embeddings-inference v1.9.4 and LiteLLM v1.105.0 (docs providers huggingface_rerank, openai_compatible), 2026-10-11

LiteLLM is the single authenticated front door. It does not store vectors; it only proxies embedding and rerank calls to TEI. Use `templates/litellm-snippet.yaml`.

```yaml
model_list:
  - model_name: embed-default # public name clients use
    litellm_params:
      model: openai/Qwen/Qwen3-Embedding-0.6B # openai/<name>, routes to TEI's /v1/embeddings
      api_base: http://tei-embed:80/v1 # container name on a shared network; or http://127.0.0.1:8080/v1
      api_key: os.environ/TEI_API_KEY
    model_info:
      mode: embedding

  - model_name: rerank-default
    litellm_params:
      model: huggingface/BAAI/bge-reranker-large
      api_base: http://tei-rerank:80 # TEI serves /rerank at the root
      api_key: os.environ/TEI_API_KEY
```

- The `openai/` route sends `POST {api_base}/embeddings`; keep `/v1` in `api_base`.
- The `huggingface/` rerank provider with a custom `api_base` is the documented route for a self-hosted reranker (LiteLLM's HuggingFace Rerank docs list a "Custom Endpoint" example). Verify the exact path it calls against your LiteLLM version with a test request; the mapping to TEI's `texts` field is done by LiteLLM.
- Client call: `curl $LITELLM/v1/embeddings -H "Authorization: Bearer $LITELLM_API_KEY" -d '{"model":"embed-default","input":["hi"]}'`; rerank at `$LITELLM/rerank` with `query`, `documents`, `top_n`.
- Put TEI and LiteLLM on one Docker network; do not publish TEI's port to the host if only LiteLLM needs it.
- Exclude embedding models from LiteLLM health checks that spend GPU time only if that matters; TEI health is cheap.
- Install the `litellm` skill for virtual keys and budgets.

Verify:

```bash
curl -fsS $LITELLM/v1/embeddings -H "Authorization: Bearer $LITELLM_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"embed-default","input":["ping"]}' | jq '.data[0].embedding|length'
```
