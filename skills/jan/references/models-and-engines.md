# Jan: models and engines

> Verified against Jan v0.8.6 (docs jan.ai/docs/desktop), 2026-10-11

Sources: jan.ai/docs/desktop manage-models, local-engine/llama-cpp, local-engine/mlx, model-parameters, v0.8.x changelogs.

## Getting models

- **Hub** tab: curated downloads, including Jan's own models.
- **Hugging Face:** paste a repo or use "Use this model on Hugging Face"; a Hugging Face token may be needed for gated models.
- **Import** a local `.gguf`: Jan links the file in place without copying; deleting from Jan leaves the original.
- Bulk delete is in the model manager.

## llama.cpp (stable, all platforms)

- Built into the app since v0.8.5 (llama.cpp 0.5.0, build b11146 in that release); updates with Jan. Older downloaded backends in `llamacpp/backends` (and `llamacpp/lib`) are unused and safe to delete.
- Since v0.8.0 a single router process (`llama-server --models-preset ... --models-max N --no-webui`) loads and unloads models on demand. **Max Concurrent Models**: 0 = unlimited, 1 = strict single model.
- Settings changed by v0.8.5: Parallel Sequences 1 becomes 0 (llama.cpp picks slots); stale `n_gpu_layers: 100` removed from `model.yml`; prompt caches persisted in `llamacpp/thread-cache` (limit 8192 MiB default, toggle "Remember Conversations Between Sessions").
- v0.8.6 note: with Parallel Sequences auto, MTP models can reserve extra slots and overflow 12 GB cards; lower Parallel Sequences if generation slows sharply.
- Different llama.cpp: run your own `llama-server -m model.gguf --alias my-model --port 8080 -ngl 99 --jinja` and add it as a custom provider.

## MLX (macOS, Apple Silicon, experimental)

macOS 14+. Limitations in the docs: no embeddings, reasoning not surfaced separately, some new architectures fail (use the GGUF). Use llama.cpp for RAG and embeddings.

## Model parameters

Per-model settings (context length, GPU layers, sampling) live in the model's edit panel; capabilities (tools, vision) can be edited per model, which MCP tool calling needs for local models.
