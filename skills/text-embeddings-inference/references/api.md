# TEI API

> Verified against text-embeddings-inference v1.9.4 (openapi.json routes, README), 2026-10-11

Routes in the OpenAPI document: `/embed`, `/embed_all`, `/embed_sparse`, `/v1/embeddings`, `/rerank`, `/predict`, `/similarity`, `/tokenize`, `/decode`, `/health`, `/info`, `/metrics`. Swagger UI is at `/docs`.

Set `H='Authorization: Bearer '"$TEI_API_KEY"` only if you started with `--api-key`. Read the key from the env file, never paste it in the shell history.

```bash
set -a; . ~/tei/tei.env; set +a      # exports API_KEY
BASE=http://127.0.0.1:8080

# Native
curl -fsS $BASE/embed -H "Authorization: Bearer $API_KEY" -H 'content-type: application/json' \
  -d '{"inputs":["What is deep learning?"]}' | jq '.[0]|length'

# OpenAI compatible
curl -fsS $BASE/v1/embeddings -H "Authorization: Bearer $API_KEY" -H 'content-type: application/json' \
  -d '{"model":"tei","input":["What is deep learning?"]}' | jq '.data[0].embedding|length'

# Rerank (reranker model loaded)
curl -fsS $BASE/rerank -H "Authorization: Bearer $API_KEY" -H 'content-type: application/json' \
  -d '{"query":"What is deep learning?","texts":["Deep learning is...","Cats are..."]}' | jq

# Info, metrics
curl -fsS $BASE/info | jq
curl -fsS http://127.0.0.1:9000/metrics | head
```

- Authentication behaviour of `/health` and `/info` with `--api-key` is not documented in the pages read; test it before using `/health` as an unauthenticated probe.
- The rerank request uses `texts`, not Cohere's `documents`. LiteLLM translates (`references/combos/litellm.md`).
- `/embed` accepts `normalize`, `truncate` and prompt options; see `/docs` for the schema of your version.
- `/embed_sparse` works with `--pooling splade` models.
- `/predict` serves sequence-classification models (for example emotion classifiers).
