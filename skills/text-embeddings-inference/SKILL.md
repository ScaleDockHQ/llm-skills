---
name: text-embeddings-inference
description: Run Hugging Face Text Embeddings Inference (TEI), a fast Rust server for embedding, reranking and SPLADE models, beside your LLM stack. Use for TEI, text-embeddings-router, /embed, /rerank, /v1/embeddings, ghcr.io/huggingface/text-embeddings-inference tags, Qwen3-Embedding or bge-reranker serving, max-batch-tokens, LiteLLM embedding entries. Not for chat models (use vllm) or the vector store (use qdrant, pgvector).
license: MIT
compatibility: Linux with Docker (CPU, or NVIDIA GPU with compute capability 7.5+ and driver CUDA 12.2+), macOS Apple Silicon via a local build, bash, curl and jq. Installing, starting containers or opening ports needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Text Embeddings Inference

Serve one embedding or reranker model with TEI, give it a stable `/v1/embeddings` URL, and register it in LiteLLM so RAG apps and vector stores use it next to your chat models.

**Scope:** TEI only: install, run, size, secure, wire into LiteLLM and llama-swap, update, troubleshoot, tear down. For the alternative multi-model embedding server use `infinity`. For storage use the vector store skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Nothing here prints a key.

```bash
command -v docker && docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i -E 'embed|tei' || true
nvidia-smi --query-gpu=name,compute_cap,memory.total,memory.used --format=csv 2>/dev/null
curl -fsS http://127.0.0.1:8080/info 2>/dev/null | jq '{model_id,model_type,max_input_length,max_batch_tokens,version}'
curl -fsS http://127.0.0.1:8080/health -o /dev/null -w 'health %{http_code}\n' 2>/dev/null
ss -ltnp 2>/dev/null | grep -E ':(8080|8081|9000)\b' || true
```

## Decision flow

1. No GPU, or an Apple/ARM CPU box: CPU image (`cpu-1.9`, `cpu-arm64-1.9`). Fine for models under about 150M parameters; slower for 0.6B and up.
2. GPU: pick the image from the compute capability (`references/install.md`). Volta and older (below 7.5) are unsupported.
3. Embeddings and a reranker both needed: run two containers (one `--model-id` each); TEI serves one model per process.
4. GPU is busy with a chat model: size the embedder first (`references/sizing.md`), cap `--max-batch-tokens`, and leave headroom for the LLM's KV cache.
5. Clients speak OpenAI: use `/v1/embeddings` on TEI, front it with LiteLLM (`references/combos/litellm.md`).
6. Models are swapped on demand by llama-swap: only worth it when VRAM is scarce (`references/combos/llama-swap.md`).

## Rules

- **Ask before changing the system.** Pulling images, starting containers, binding ports and editing LiteLLM or llama-swap config need approval and an undo path (`references/updating.md`, teardown).
- **Secrets never touch output.** `API_KEY` and `HF_TOKEN` live in a `0600` env file, not on the command line or in compose files. Do not echo them or print `docker inspect` env.
- **Bind to loopback or a private network.** TEI's default hostname is `0.0.0.0`; publish with `127.0.0.1:8080:80` and add `--api-key` if anything else can reach it.
- **One model per process, one dimension per index.** Changing the embedding model means re-embedding the corpus and rebuilding the index.
- **Match prompts to the model.** Many models need a query or document prefix (`--default-prompt-name`, or the client); wrong prefixes silently cost recall.
- **Verify upstream.** Image tags, flags and defaults come from the TEI docs read on the writing date; re-check them before an upgrade.

## Workflows

- [ ] Choose the image and model -> `references/install.md`
- [ ] Size memory and batch limits -> `references/sizing.md`
- [ ] Start with the compose template -> `templates/docker-compose.yml`, flags in `references/serve-config.md`
- [ ] Call and test the API -> `references/api.md`
- [ ] Secure it -> `references/security.md`
- [ ] Register in LiteLLM (and llama-swap if used) -> `references/combos/litellm.md`, `references/combos/llama-swap.md`
- [ ] Upgrade or tear down -> `references/updating.md`
- [ ] Something is broken -> `references/troubleshooting.md`
- [ ] Verify: `/health` is 200, `/info` shows the intended model, an embedding request through LiteLLM returns the expected dimension, and VRAM use is stable under load.

## Reference index

- `references/install.md`: image tag per GPU architecture, Docker, local build, air-gapped use.
- `references/serve-config.md`: every server flag and env var that matters, with defaults.
- `references/sizing.md`: memory math, batch tokens, throughput and dimension choices.
- `references/api.md`: native routes, the OpenAI route, rerank, sparse, tokenize, metrics.
- `references/security.md`: API key, binding, gated models, supply chain.
- `references/updating.md`: upgrade, rollback, teardown.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/litellm.md`: `model_list` entries for embeddings and rerank.
- `references/combos/llama-swap.md`: running TEI behind llama-swap, and when not to.
- `references/combos/open-webui.md`: pointing Open WebUI's RAG embedding engine at TEI.

## Companion skills

- `litellm`: the gateway in front. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llama-swap`: on-demand model loading. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `vllm`: chat models on the same GPU. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `choosing-hardware`: GPU sizing. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
