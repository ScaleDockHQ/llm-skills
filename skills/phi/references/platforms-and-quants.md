# Phi: platforms and quantizations

> Verified against Hugging Face Hub listings and cards (`microsoft/`, `nvidia/`, `RedHatAI/`, `unsloth/`, `mlx-community/`, `lmstudio-community/`), Ollama library pages and the Phi-4-reasoning-vision-15B card, 2026-10-11

Memory figures marked "estimate" are plain arithmetic (parameters x bytes per weight), not measurements. Add KV cache
and activations on top, and measure with the `bench.sh` workflow in `self-hosted-llms`.

## Official and vendor quantizations that exist

| Model                                              | Format                   | Repo                                                                                                                                                                                | Publisher                          | Engine named on the card                                   |
| -------------------------------------------------- | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- | ---------------------------------------------------------- |
| Phi-4-reasoning-plus                               | FP8                      | `nvidia/Phi-4-reasoning-plus-FP8`                                                                                                                                                   | NVIDIA ModelOpt 0.35.0             | TensorRT-LLM, vLLM; Blackwell and Hopper                   |
| Phi-4-reasoning-plus                               | NVFP4                    | `nvidia/Phi-4-reasoning-plus-NVFP4`                                                                                                                                                 | NVIDIA ModelOpt 0.35.0             | TensorRT-LLM; Blackwell; tested on B200                    |
| Phi-4-multimodal-instruct                          | FP8                      | `nvidia/Phi-4-multimodal-instruct-FP8`                                                                                                                                              | NVIDIA                             | TensorRT-LLM (NVIDIA Open Model License)                   |
| Phi-4-multimodal-instruct                          | NVFP4                    | `nvidia/Phi-4-multimodal-instruct-NVFP4`                                                                                                                                            | NVIDIA                             | TensorRT-LLM; Blackwell; B200 test "coming soon"           |
| phi-4                                              | GGUF Q2_K to Q8_0, bf16  | `microsoft/phi-4-gguf`                                                                                                                                                              | Microsoft                          | llama.cpp                                                  |
| phi-4, mini, reasoning, mini-reasoning, multimodal | ONNX int4 (CPU/GPU)      | `microsoft/*-onnx`                                                                                                                                                                  | Microsoft                          | ONNX Runtime                                               |
| phi-4, Phi-4-mini-instruct, Phi-4-reasoning        | FP8-dynamic, W8A8, W4A16 | `RedHatAI/phi-4-FP8-dynamic`, `RedHatAI/phi-4-quantized.w8a8`, `RedHatAI/phi-4-quantized.w4a16`, `RedHatAI/Phi-4-mini-instruct-FP8-dynamic`, `RedHatAI/Phi-4-reasoning-FP8-dynamic` | Red Hat AI                         | vLLM (compressed-tensors; engine not re-read on each card) |
| Phi-4-reasoning-vision-15B                         | FP8-dynamic              | `inference-optimization/Phi-4-reasoning-vision-15B-FP8-dynamic`                                                                                                                     | Third party (listed in Hub search) | **unverified**                                             |

Both NVIDIA reasoning-plus cards say "Context length up to 64k". The NVIDIA cards say the model is "not owned or
developed by NVIDIA"; the weights stay MIT for reasoning-plus. The multimodal FP8/NVFP4 repos use the NVIDIA Open Model
License (`license: other`), not MIT: read it before redistributing.

Not found: any NVIDIA or Microsoft FP8/NVFP4/MXFP4 checkpoint for Phi-4-mini-instruct, Phi-4-mini-reasoning,
Phi-4-mini-flash-reasoning or Phi-4-reasoning-vision-15B. Official GGUF exists only for `phi-4`.

Community GGUF and MLX (not official; check each repo): `unsloth/phi-4-GGUF`, `unsloth/Phi-4-mini-instruct-GGUF`,
`unsloth/Phi-4-mini-reasoning-GGUF`, `unsloth/Phi-4-reasoning-plus-GGUF`, `dranger003/Phi-4-reasoning-vision-15B-GGUF`
(with an `mmproj` file), `mlx-community/phi-4-4bit`, `mlx-community/Phi-4-mini-instruct-4bit` and `-8bit`,
`lmstudio-community/Phi-4-reasoning-plus-MLX-4bit`, `lmstudio-community/Phi-4-mini-reasoning-MLX-4bit`,
`mlx-community/Phi-4-reasoning-vision-15B-4bit`.

## Recommendation by platform

| Platform                                  | Pick                                                                                                                                                                              | Why / caveat                                                                                                                                                                                                                                                                        |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **NVIDIA DGX Spark GB10 (128GB unified)** | vLLM bf16 for any Phi-4 model; 14B bf16 is about 28GB (estimate), vision 15B about 30GB (estimate). All fit with large KV headroom                                                | No Phi-specific Spark recipe or GB10 benchmark was found. Spark's unified memory is bandwidth-bound, so the small FP8/NVFP4 checkpoints are the speed lever; NVFP4 cards name "Blackwell" and test B200 only, so GB10 support is **unverified**. Start with FP8 or bf16 and measure |
| **Consumer RTX (8-24GB)**                 | Phi-4-mini family: Ollama `phi4-mini` (2.5GB) or llama.cpp GGUF Q4_K_M/Q8_0. Phi-4 14B: `microsoft/phi-4-gguf` Q4_K or Ollama `phi4` (9.1GB); `phi4-reasoning` Ollama tag is 11GB | `--jinja` with the Hub template in llama.cpp. Reasoning models need room for long chains: set 16K+ context                                                                                                                                                                          |
| **Apple Silicon**                         | MLX 4-bit (`mlx-community`, `lmstudio-community`) or GGUF via llama.cpp/Ollama                                                                                                    | Community conversions only. `Phi-4-reasoning-vision-15B-4bit` exists on `mlx-community`; read its card for the required `mlx-vlm` version (not checked)                                                                                                                             |
| **Datacenter H100 / B200**                | vLLM bf16 or FP8 (`nvidia/...-FP8`, `RedHatAI/...-FP8-dynamic`). B200: TensorRT-LLM with NVFP4 for reasoning-plus                                                                 | Microsoft tested the vision model on A6000, A100, H100, B200 in bf16 and recommends vLLM with bf16                                                                                                                                                                                  |
| **CPU / Windows / mobile**                | ONNX Runtime int4 (`microsoft/*-onnx`)                                                                                                                                            | Phi-4-mini-instruct, mini-reasoning, reasoning, reasoning-plus, multimodal and phi-4 have ONNX repos                                                                                                                                                                                |

## Context and memory notes

- Phi-4 (16K) and Phi-4-reasoning-vision (16,384) have short windows; do not raise `--max-model-len` past the card.
- Phi-4-reasoning/-plus: card context 32K; plus was tested to 64K by Microsoft and NVIDIA's cards say "up to 64k". Treat 64K
  as an extension that the card reports working, not a native guarantee, and verify quality with your own long prompts.
- Phi-4-mini family: 128K via longrope. See known-issues.md for a llama.cpp long-context RoPE bug.
- Reasoning chains are long: budget `max_tokens` of 4096 minimum, 32768 for hard problems (card guidance).

## Sources

- https://huggingface.co/nvidia/Phi-4-reasoning-plus-NVFP4
- https://huggingface.co/nvidia/Phi-4-reasoning-plus-FP8
- https://huggingface.co/nvidia/Phi-4-multimodal-instruct-NVFP4
- https://huggingface.co/nvidia/Phi-4-multimodal-instruct-FP8
- https://huggingface.co/microsoft/phi-4-gguf
- https://huggingface.co/microsoft/phi-4-onnx
- https://huggingface.co/RedHatAI/phi-4-FP8-dynamic
- https://huggingface.co/unsloth/Phi-4-mini-instruct-GGUF
- https://huggingface.co/dranger003/Phi-4-reasoning-vision-15B-GGUF
- https://huggingface.co/mlx-community/Phi-4-reasoning-vision-15B-4bit
- https://huggingface.co/lmstudio-community/Phi-4-reasoning-plus-MLX-4bit
- https://ollama.com/library/phi4
- https://ollama.com/library/phi4-reasoning
