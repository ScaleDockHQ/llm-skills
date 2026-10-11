# LocalAI with the ik-llama-cpp backend

> Verified against LocalAI v4.11.0 and ik_llama.cpp pinned commit 04b4ebc2 (backend Makefile), 2026-10-11

LocalAI ships `ik-llama-cpp` as a gallery backend, so GGUF models can run on the ik_llama.cpp fork behind the normal LocalAI API. Use it for CPU-heavy or quantization-specific (IQK quants) models where plain `llama-cpp` is slower. For GPU or hybrid offload tuning, run ik_llama.cpp directly instead (skill `ik-llama-cpp`, `npx skills add ScaleDockHQ/llms-skills --skill ik-llama-cpp`).

## Facts that decide the choice

- The backend gallery entry lists only a CPU variant (`default: cpu-ik-llama-cpp`, tagged CPU). There is no CUDA, ROCm or Vulkan gallery variant, so through LocalAI this backend is CPU-only. Check `local-ai backends list` on your version before assuming otherwise.
- It needs a CPU with AVX2; the IQK kernels do not run on older CPUs.
- LocalAI builds a pinned ik_llama.cpp commit (`04b4ebc2` in the backend Makefile), not the fork's `main`. Flags and features that landed later on the fork are not in LocalAI's backend; the LocalAI backend also exposes only the options LocalAI maps, not arbitrary `llama-server` flags.
- Aliases `ik-llama` and `ik_llama` are accepted in YAML.
- Features upstream names for it: text generation, embeddings, IQK quants, multimodal (clip/llava).
- Unverified: whether LocalAI maps ik_llama.cpp hybrid-offload flags such as `--fit` or `-sm graph`. Test before relying on them.

## Setup

```bash
local-ai backends install ik-llama-cpp
```

```yaml
# models/ik-model.yaml
name: ik-model
backend: ik-llama-cpp
parameters:
  model: model-IQ4_KS.gguf # relative to the models dir; an IQK quant is the point of using it
context_size: 8192
threads: 16 # physical cores
```

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"ik-model","messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

## Pitfalls

- `all backends returned error` or an illegal-instruction crash on load: the CPU lacks AVX2, or the prebuilt backend uses instructions the CPU does not have. Rebuild the backend for the CPU (`REBUILD=true` with a matching `CMAKE_ARGS`, see `references/troubleshooting.md`).
- A model loads but is slow on a GPU host: this backend does not use the GPU. Use `llama-cpp` for GPU offload.
- Quantizations made by other fork versions may not load on the pinned commit; requantize or use the matching tools from that commit.
