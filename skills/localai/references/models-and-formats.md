# Models, backends and formats in LocalAI

> Verified against LocalAI v4.11.0, 2026-10-11

## Install a model

```bash
local-ai models list | head                          # gallery entries
local-ai models install qwen3-4b                     # gallery name (used in upstream quick start)
local-ai models install <name> --variant <variant>   # pick a quantization variant when the entry offers one
local-ai run huggingface://TheBloke/phi-2-GGUF/phi-2.Q8_0.gguf   # <repo>/<file>, file is optional
local-ai run ollama://gemma:2b
local-ai run oci://localai/phi-2:latest
local-ai run https://example.com/phi-2.yaml          # a model config URL
```

Accepted URI schemes: `huggingface://` (also `hf://`, full Hugging Face URLs), `https://`, `file://` (only paths inside the models dir), `oci://`, `ocifile://`, `ollama://`. Installing inside a container: `docker exec local-ai local-ai models install <name>`.

Downloads run through a pre-download security scan unless disabled. Gated Hugging Face repos need `HF_TOKEN` in the environment. For private registries and credentials see upstream `advanced/private-sources`.

The web UI **Models** page has an import form that previews the request, checks free disk and memory and auto-detects the backend; `mlx-community` repos go to the MLX backends, others to what matches the modality. Override the backend explicitly when auto-detect picks wrong.

## Backends

Backends are separate gRPC runtimes (60+ upstream) downloaded to the backends dir. The catalog recommends `llama-cpp` for most text models.

```bash
local-ai backends list | head
local-ai backends install llama-cpp
local-ai backends upgrade                    # all backends to latest
local-ai backends uninstall <name>
```

- `LOCALAI_EXTERNAL_BACKENDS` installs a list on boot; `LOCALAI_AUTO_UPGRADE_BACKENDS=true` upgrades automatically (default off, so a restart does not change engines).
- Meta backends such as `llama-cpp` resolve to a hardware-specific build. Override detection with `LOCALAI_FORCE_META_BACKEND_CAPABILITY=nvidia|amd|intel|default` when it picks the wrong one.
- LocalAI keeps no earlier version of a backend. To roll back, pin the image tag and reinstall the backend from the matching release.
- `LOCALAI_REQUIRE_BACKEND_INTEGRITY=true` rejects installs without a signature policy or SHA256.

Text backends named in upstream docs: `llama-cpp` (GGUF), `ik-llama-cpp` (aliases `ik-llama`, `ik_llama`; needs AVX2), `turboquant` (llama.cpp fork with TurboQuant KV types), `vllm`, `sglang`, `vllm.cpp`, `transformers`, `mlx`, `mlx-vlm`, `rwkv`. Others cover whisper, TTS, diffusers, rerankers and more; see the upstream compatibility table.

Container images named `core` are small and lack Python backends; use the full GPU images for Python backends such as `rerankers`.

## Model YAML

A file `<models dir>/<name>.yaml`. The API model id is `name`.

```yaml
name: qwen3-4b
backend: llama-cpp
parameters:
  model: Qwen3-4B-Q4_K_M.gguf # relative to the models dir, never absolute
context_size: 8192
threads: 8
gpu_layers: 99 # offload all layers; lower it when VRAM is short
known_usecases:
  - chat
template:
  use_tokenizer_template: true # use the model's embedded chat template
options: # backend specific, see features and performance refs
  - use_jinja:true
download_files:
  - filename: Qwen3-4B-Q4_K_M.gguf
    uri: huggingface://Qwen/Qwen3-4B-GGUF/Qwen3-4B-Q4_K_M.gguf
    sha256: <hash> # optional but recommended
```

Frequent fields: `mmproj` (vision projector file), `stopwords`, `embeddings: true` (embedding models), `f16`, `mmap`, `function:` (tool-call parsing), `mcp:`, `pipeline:` (voice chains), `overrides:` and `failover:`. See upstream `advanced/model-configuration` for the full list. Template file: `templates/model.yaml`.

Pitfalls:

- `parameters.model` is relative to the models dir. An absolute path fails.
- `threads` above physical cores causes contention.
- A too-large `context_size` for the RAM or VRAM causes OOM at load.
- The `ggml` format is deprecated; use GGUF.
- Gallery updates do not rewrite model YAMLs already installed. Migrate by editing the file and reloading the model.

## Formats by backend

| Backend                                   | Weights                                                                                              |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `llama-cpp`, `ik-llama-cpp`, `turboquant` | GGUF                                                                                                 |
| `vllm`, `sglang`, `transformers`          | Hugging Face repo (safetensors); parser options like `tool_parser:` and `reasoning_parser:` for vLLM |
| `mlx`, `mlx-vlm`, `mlx-audio`             | MLX-quantized Hugging Face repos (Apple silicon)                                                     |

Quantize and convert GGUF elsewhere (`model-quantization`, `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`); LocalAI also has a quantization API for GGUF (`features/quantization` upstream).
