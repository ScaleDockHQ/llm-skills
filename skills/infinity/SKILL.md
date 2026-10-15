---
name: infinity
description: Run Infinity (michaelfeil/infinity, infinity_emb), a Python REST server for embeddings, rerankers, CLIP/CLAP and ColBERT models, with several models per process. Use for infinity_emb v2, michaelf34/infinity images, INFINITY_* env vars, --model-id repeated, /embeddings, /rerank, /classify, ONNX or CPU embedding serving, LiteLLM infinity/ entries. For Rust-based Qwen3-class serving prefer text-embeddings-inference; for chat use vllm.
license: MIT
compatibility: Linux with Docker (NVIDIA GPU, ROCm, or CPU), or pip on Python 3.9 to 3.13, macOS via pip with MPS, bash, curl and jq. Installing, starting containers or opening ports needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Infinity

Serve one or several embedding, rerank, classification or multimodal models behind one REST port, secure it, and register it in LiteLLM beside your chat models.

**Scope:** Infinity only. Compare with `text-embeddings-inference` (TEI) in the decision flow. Storage is in the vector store skills.

**Maintenance note:** at the 2026-10-11 check the repo is not archived and has commits in 2026, but the last tagged release is 0.0.77 (2025-08-22). Pin the version, test new model architectures before committing to it, and keep TEI as the fallback.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Nothing here prints a key.

```bash
command -v docker infinity_emb 2>/dev/null; pip show infinity_emb 2>/dev/null | sed -n 1,2p
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i infinity || true
nvidia-smi --query-gpu=name,compute_cap,memory.total,memory.used --format=csv 2>/dev/null
curl -fsS http://127.0.0.1:7997/health 2>/dev/null; echo
curl -fsS http://127.0.0.1:7997/models 2>/dev/null | jq '.data[]|{id,stats:.stats}' 2>/dev/null
ss -ltnp 2>/dev/null | grep ':7997\b' || true
```

## Decision flow

1. Need several small models (embedder plus reranker) in one process and one port: Infinity (`--model-id` repeated).
2. Need Qwen3-Embedding or Gemma3-based embedders with the best GPU throughput: check the Infinity README model list first; if not listed, use `text-embeddings-inference`.
3. Need CLIP, CLAP, ColBERT or ColPali: Infinity (TEI does not list them).
4. AMD GPU or ONNX/TensorRT: Infinity images `-amd` and `-trt-onnx` exist (not built by CI, pin the exact version).
5. CPU only: `latest-cpu` image with `--engine optimum` (ONNX).
6. Behind LiteLLM: `references/combos/litellm.md`. Behind llama-swap: only if VRAM is scarce (`references/combos/llama-swap.md`).

## Rules

- **Ask before changing the system.** Pulling images, starting containers, binding ports and gateway edits need approval and an undo path.
- **Secrets never touch output.** `INFINITY_API_KEY` and `HF_TOKEN` go in a `0600` env file, never on a visible command line.
- **Bind narrowly.** The default host is `0.0.0.0`. Publish `127.0.0.1:7997:7997`, and set an API key.
- **`/health` and `/` are not protected by the API key.** Do not treat them as proof that auth works; test `/embeddings` without a token.
- **Pin versions.** Releases are infrequent and images (`-amd`, `-trt-onnx`) are not CI-built; use `0.0.77` style tags, not `latest`, in production.
- **One dimension per index.** Changing model or `--embedding-dtype` means re-embedding.
- **Telemetry.** Anonymous usage stats are on by default; set `INFINITY_ANONYMOUS_USAGE_STATS=0` on private networks.
- **Verify upstream.** Flags and defaults come from the CLI source and README read on the writing date.

## Workflows

- [ ] Pick install path and image -> `references/install.md`
- [ ] Configure models and flags -> `references/serve-config.md`, `templates/docker-compose.yml`
- [ ] Size memory and batches -> `references/sizing.md`
- [ ] Call the API -> `references/api.md`
- [ ] Secure it -> `references/security.md`
- [ ] Register in LiteLLM or llama-swap -> `references/combos/litellm.md`, `references/combos/llama-swap.md`
- [ ] Update or tear down -> `references/updating.md`
- [ ] Debug -> `references/troubleshooting.md`
- [ ] Verify: `/models` lists the intended model IDs, an embedding via LiteLLM has the expected dimension, a request without a token returns 401, VRAM is stable.

## Reference index

- `references/install.md`: pip, Docker images and tags, local models.
- `references/serve-config.md`: CLI and env variables, multi-model rules.
- `references/sizing.md`: memory, batch size, vector storage.
- `references/api.md`: routes and examples.
- `references/security.md`: API key, binding, telemetry.
- `references/updating.md`: upgrade, rollback, teardown.
- `references/troubleshooting.md`: symptom to fix.
- `references/combos/litellm.md`, `references/combos/llama-swap.md`, `references/combos/open-webui.md`.

## Companion skills

- `text-embeddings-inference`: the Rust alternative. Install: `npx skills add ScaleDockHQ/llm-skills --skill text-embeddings-inference`.
- `litellm`: the gateway. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llama-swap`: on-demand loading. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `vllm`: chat models. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
