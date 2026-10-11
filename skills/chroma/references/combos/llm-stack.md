# Chroma beside LiteLLM, TEI, llama-swap and Open WebUI

> Verified against Chroma 1.5.9 (docs.trychroma.com deploy, performance, server env vars), 2026-10-11

## LiteLLM `/v1/embeddings`

Chroma does not call embedders itself. The embedding function runs in the client (your app) and calls any OpenAI-compatible endpoint, so LiteLLM or TEI fit directly. LiteLLM does not proxy Chroma.

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

Use `OpenAIEmbeddingFunction(model_name="embed-default", api_base="http://litellm:4000/v1", api_key_env_var="LLM_API_KEY")` with a LiteLLM virtual key. Alternatively compute vectors yourself and pass `embeddings=` to `add` and `query`.

## llama-swap

Not applicable: Chroma is a database. If the embedder is behind llama-swap, LiteLLM points at that entry and the first request may load the model (raise client timeouts).

## Open WebUI

Open WebUI supports Chroma and uses a local persistent Chroma by default (SQLite-backed, single process). For multiple workers or replicas, set `CHROMA_HTTP_HOST` (and `CHROMA_HTTP_PORT`, `CHROMA_HTTP_SSL`, `CHROMA_TENANT`, `CHROMA_DATABASE`) to a remote server. Send the proxy token with `CHROMA_HTTP_HEADERS=Authorization=Bearer <token>` (set from a secret, not a literal in compose). `CHROMA_CLIENT_AUTH_PROVIDER` and `CHROMA_CLIENT_AUTH_CREDENTIALS` target legacy server auth that v1 no longer has. Open WebUI embeds with its own engine; its skill covers RAG settings, and an embedding model change needs a re-index.
