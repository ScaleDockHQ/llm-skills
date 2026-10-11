# Infinity API

> Verified against infinity_emb 0.0.77 (infinity_server.py), 2026-10-11

Routes (all under `--url-prefix`, except `/health` and `/`): `GET /models`, `POST /embeddings` (OpenAI-shaped), `POST /rerank`, `POST /classify`, `POST /embeddings_image`, `POST /embeddings_audio`, `GET /health`, OpenAPI at `/docs` and `/openapi.json`. With `--api-key`, every route except `/health` and `/` requires `Authorization: Bearer`.

```bash
set -a; . ~/infinity/infinity.env; set +a
B=http://127.0.0.1:7997
curl -fsS $B/health
curl -fsS $B/models -H "Authorization: Bearer $INFINITY_API_KEY" | jq '.data[].id'
curl -fsS $B/embeddings -H "Authorization: Bearer $INFINITY_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"BAAI/bge-small-en-v1.5","input":["hello"]}' | jq '.data[0].embedding|length'
curl -fsS $B/rerank -H "Authorization: Bearer $INFINITY_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"mixedbread-ai/mxbai-rerank-xsmall-v1","query":"capital of France","documents":["Paris","Berlin"],"top_n":2}' | jq
```

- With no `--url-prefix`, the OpenAI route is `/embeddings`, not `/v1/embeddings`. Either set `--url-prefix /v1` or give clients a base URL without `/v1`.
- Rerank takes `documents` (Cohere style), unlike TEI's `texts`.
- `model` must match a served model name when several models are loaded.
- `/metrics`: the server instruments with a Prometheus instrumentator; the exact exposure was not confirmed in the source read, so check `/openapi.json` and your build.
