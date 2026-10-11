# Chroma API basics

> Verified against Chroma 1.5.9 (docs.trychroma.com deploy, performance, server env vars), 2026-10-11

REST paths are under `/api/v2` (`/api/v2/heartbeat`, `/api/v2/version`). Prefer the official client.

## Connect and create a collection

```python
import os, chromadb
from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction

ef = OpenAIEmbeddingFunction(
    api_key_env_var="LLM_API_KEY",          # env var name holding your gateway key
    model_name="embed-default",              # LiteLLM model_name or TEI model id
    api_base="http://litellm:4000/v1",
)
client = chromadb.HttpClient(host="127.0.0.1", port=8001,
    headers={"Authorization": f"Bearer {os.environ['CHROMA_PROXY_TOKEN']}"})
col = client.get_or_create_collection("docs", embedding_function=ef,
    configuration={"hnsw": {"space": "cosine"}})
col.add(ids=["a"], documents=["hello world"])
print(col.query(query_texts=["hi"], n_results=1))
```

`OpenAIEmbeddingFunction` takes `api_key`, `api_key_env_var` (default `CHROMA_OPENAI_API_KEY`), `model_name`, `api_base`, `dimensions` and `default_headers`. The key goes to your embedder, not to Chroma.

## Index settings

Single-node collections use HNSW: `space` (default `l2`; also `cosine`, `ip`), `ef_construction`, `ef_search`, `max_neighbors`. Match `space` to your embedder (cosine for most text embedders) and set it at creation. Raising `ef_search` improves recall at latency cost.

## Custom embedding function

Implement `EmbeddingFunction` (a `__call__(self, input)` returning vectors) to wrap any endpoint, for example one using the TEI native `/embed` route.
