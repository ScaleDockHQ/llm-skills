# TEI with llama-swap

> Verified against text-embeddings-inference v1.9.4 and llama-swap v263 (README and config.example patterns used by the llama-swap skill), 2026-10-11

Usually do not. An embedder is small and always wanted by RAG ingestion and query, so keep TEI running beside the swapped chat models and reserve its VRAM. Use llama-swap only when VRAM is too tight to keep it resident.

If you do, treat TEI as a container engine entry, like the pattern in the `llama-swap` skill's template (`templates/llama-swap-snippet.yaml`):

```yaml
models:
  "embed-qwen3":
    proxy: "http://127.0.0.1:${PORT}"
    cmd: |
      docker run --name ${MODEL_ID} --init --rm --gpus all --env-file ${env.TEI_ENV_FILE}
      -p 127.0.0.1:${PORT}:80 -v ${env.TEI_DATA}:/data
      ghcr.io/huggingface/text-embeddings-inference:89-1.9
      --model-id Qwen/Qwen3-Embedding-0.6B
    cmdStop: docker stop ${MODEL_ID}
    checkEndpoint: /health
    ttl: 600
```

- A cold start downloads or loads weights; raise `healthCheckTimeout` and LiteLLM's timeout.
- llama-swap routes by the `model` field. Whether it forwards `/v1/embeddings` to a given entry follows its OpenAI-compatible routing; confirm with `curl -s $LLAMA_SWAP/v1/models | jq` and a test request.
- Put the group as `swap: false` so loading the embedder does not evict the chat model.
- Never let LiteLLM health checks hit every entry; see the `litellm` skill.
