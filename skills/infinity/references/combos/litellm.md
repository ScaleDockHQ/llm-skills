# Infinity with LiteLLM

> Verified against infinity_emb 0.0.77 and LiteLLM v1.105.0 (docs providers infinity and openai_compatible), 2026-10-11

LiteLLM is the authenticated front door; it proxies embeddings and rerank to Infinity and never stores vectors. Use `templates/litellm-snippet.yaml`.

```yaml
model_list:
  - model_name: embed-bge
    litellm_params:
      model: openai/BAAI/bge-small-en-v1.5 # openai/<served model name>
      api_base: http://infinity:7997 # no /v1: Infinity's route is /embeddings
      api_key: os.environ/INFINITY_API_KEY
    model_info:
      mode: embedding

  - model_name: rerank-mxbai
    litellm_params:
      model: infinity/mixedbread-ai/mxbai-rerank-xsmall-v1
      api_base: http://infinity:7997
      api_key: os.environ/INFINITY_API_KEY
```

- LiteLLM documents an `infinity/` provider for `/rerank` and `/embeddings`. Its docs example uses `model: infinity/rerank`; whether the part after `infinity/` must be the served model id is not stated, so test with `GET /models` ids first and fall back to the exact docs form.
- If you start Infinity with `--url-prefix /v1`, set `api_base: http://infinity:7997/v1` for the `openai/` route.
- Infinity-specific rerank params (for example `raw_scores`) pass through unmapped params as-is per the LiteLLM docs.

Verify:

```bash
curl -fsS $LITELLM/v1/embeddings -H "Authorization: Bearer $LITELLM_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"embed-bge","input":["ping"]}' | jq '.data[0].embedding|length'
curl -fsS $LITELLM/rerank -H "Authorization: Bearer $LITELLM_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"rerank-mxbai","query":"capital of France","documents":["Paris","Berlin"],"top_n":1}' | jq
```
