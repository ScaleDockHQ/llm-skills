# Quantization formats and the engines that run them

> Verified against llama.cpp v0.6.0, exllamav3 v1.6.1, llm-compressor 0.14.0, NVIDIA Model Optimizer 0.47.0, mlx-lm v0.31.3, vLLM v0.31.0, SGLang v0.5.21, TensorRT-LLM v1.2.1, 2026-10-11

Use this file to pick a target format **after** you know the serving engine and the hardware. Producing each format is covered in the sibling files (`gguf.md`, `exl3.md`, `llm-compressor.md`, `modelopt-nvfp4.md`, `mlx.md`).

## The formats

| Format                      | What it is                                                                                                                            | Produced by                                                                     | Typical bit widths          |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | --------------------------- |
| **GGUF**                    | Single-file (or split) container with tensors plus tokenizer and chat-template metadata. Quant types like `Q4_K_M`, `IQ4_XS`, `Q8_0`. | llama.cpp `convert_hf_to_gguf.py` + `llama-quantize` (optional `llama-imatrix`) | 1.5 to 8 bpw, plus F16/BF16 |
| **EXL3**                    | ExLlamaV3's trellis-coded format (a QTIP variant). Any fractional average bitrate. HF-style directory of safetensors.                 | exllamav3 `convert.py`                                                          | ~2 to 8 bpw (`-b`)          |
| **AWQ / GPTQ (INT4 W4A16)** | 4-bit integer weights, 16-bit activations, group-wise scales.                                                                         | llm-compressor (`AWQModifier`, `GPTQModifier`), or ModelOpt `int4_awq`          | 4 bpw (+ scales)            |
| **FP8 (W8A8)**              | 8-bit float weights and activations (dynamic or static scales, per-tensor/channel/block).                                             | llm-compressor `FP8_DYNAMIC` / `FP8_BLOCK`, ModelOpt `fp8`                      | 8                           |
| **NVFP4**                   | NVIDIA 4-bit float (E2M1) with FP8 block scales (block 16) and a per-tensor scale. Native tensor-core support on Blackwell.           | llm-compressor `NVFP4` / `NVFP4A16`, ModelOpt `nvfp4*`                          | ~4.5 effective              |
| **MXFP4 / MXFP8**           | OCP microscaling floats (block 32, E8M0 scales).                                                                                      | llm-compressor, ModelOpt, mlx-lm (`--q-mode mxfp4/mxfp8`)                       | 4 / 8                       |
| **MLX**                     | Apple MLX safetensors with affine group quantization (or mxfp4/nvfp4/mxfp8 modes).                                                    | mlx-lm `mlx_lm.convert -q`                                                      | 2 to 8 (`--q-bits`)         |

Checkpoint containers on the Hub:

- **compressed-tensors**: what llm-compressor writes (`quantization_config` in `config.json`). vLLM reads it natively; SGLang also accepts it.
- **ModelOpt unified HF checkpoint**: what ModelOpt `hf_ptq.py` writes (`hf_quant_config.json`). Loaded by TensorRT-LLM, vLLM (`--quantization modelopt` / `modelopt_fp4`) and SGLang (`--quantization modelopt_fp8` / `modelopt_fp4`).

## Format -> engine matrix

`Y` = supported path, `~` = works with caveats (see notes), `-` = not supported / not the intended path.

| Format                               | llama.cpp / llama-server | Ollama | LM Studio         | ExLlamaV3 / TabbyAPI | vLLM                           | SGLang                             | TensorRT-LLM | mlx-lm / LM Studio (MLX) |
| ------------------------------------ | ------------------------ | ------ | ----------------- | -------------------- | ------------------------------ | ---------------------------------- | ------------ | ------------------------ |
| GGUF                                 | Y                        | Y      | Y                 | -                    | ~ (1)                          | ~ (2)                              | -            | -                        |
| EXL3                                 | -                        | -      | -                 | Y                    | -                              | -                                  | -            | -                        |
| AWQ / GPTQ INT4 (compressed-tensors) | -                        | -      | -                 | -                    | Y                              | Y                                  | ~ (3)        | -                        |
| FP8 (compressed-tensors)             | -                        | -      | -                 | -                    | Y                              | Y                                  | ~ (3)        | -                        |
| FP8 / NVFP4 (ModelOpt)               | -                        | -      | -                 | -                    | Y (`modelopt`, `modelopt_fp4`) | Y (`modelopt_fp8`, `modelopt_fp4`) | Y            | -                        |
| NVFP4 (compressed-tensors)           | -                        | -      | -                 | -                    | Y                              | Y                                  | -            | -                        |
| MLX                                  | -                        | -      | Y (Apple Silicon) | -                    | -                              | ~ (4)                              | -            | Y                        |

Notes:

1. vLLM moved GGUF to the out-of-tree `vllm-gguf-plugin` and calls it experimental and under-optimized. Do not produce GGUF _for_ vLLM.
2. SGLang lists `gguf` in its `--quantization` choices; prefer llama.cpp for GGUF.
3. TensorRT-LLM's documented quantization path is ModelOpt checkpoints; produce those instead for TRT-LLM.
4. SGLang has an experimental MLX backend (`SGLANG_USE_MLX=1`, `mlx_q4`/`mlx_q8` on-the-fly quantization). Use mlx-lm for MLX checkpoints.

Ollama and LM Studio consume GGUF (LM Studio also MLX on Macs). Their own commands and import steps live in the `local-llms` skill.

## Hardware notes

Find the GPU and its compute capability first: `nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv`.

| Hardware                                          | Good targets                   | Why                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Apple Silicon (M-series)                          | MLX, GGUF                      | Metal backends in mlx-lm and llama.cpp. No CUDA formats (EXL3, AWQ/GPTQ kernels, FP8, NVFP4) run here.                                                                                                                                                                                                                                                                               |
| CPU-only x86/arm64                                | GGUF                           | llama.cpp CPU backend. vLLM's table shows AWQ/GPTQ on x86 CPU, but GGUF is the practical choice.                                                                                                                                                                                                                                                                                     |
| NVIDIA Ampere (SM 8.x)                            | GGUF, EXL3, AWQ/GPTQ INT4      | No FP8 tensor cores. vLLM FP8 needs compute capability >= 8.9. NVFP4 runs only as weight-only (Marlin) fallback.                                                                                                                                                                                                                                                                     |
| NVIDIA Ada / Hopper (SM 8.9 / 9.0)                | FP8, AWQ/GPTQ INT4, EXL3, GGUF | Native FP8. NVFP4 falls back to weight-only W4A16 (Marlin) in vLLM and SGLang.                                                                                                                                                                                                                                                                                                       |
| NVIDIA Blackwell datacenter (SM 10.0 / 10.3)      | NVFP4, FP8                     | Native FP4 tensor cores; llm-compressor notes vLLM only runs NVFP4 activation quantization on >= SM100.                                                                                                                                                                                                                                                                              |
| NVIDIA Blackwell consumer / workstation (SM 12.0) | NVFP4, FP8, GGUF, EXL3         | TensorRT-LLM's table lists NVFP4 and FP8 per-tensor on sm120.                                                                                                                                                                                                                                                                                                                        |
| NVIDIA DGX Spark (GB10, unified LPDDR5x memory)   | NVFP4, FP8, GGUF               | Blackwell-class GPU. llama.cpp builds a `121a-real` CUDA target for it, which implies compute capability 12.1 (confirm with `nvidia-smi`). Whether a given vLLM / SGLang / TRT-LLM build uses native FP4 GEMM on sm121 or falls back to Marlin W4A16 is (unverified): read the engine's startup log. CPU and GPU share one memory pool, so cap conversion jobs (`memory-safety.md`). |

Rules of thumb:

- Memory-bound single-user decode (laptops, Spark, one GPU): GGUF / EXL3 / MLX at 4-6 bpw give the most model per GB.
- Throughput serving with batching on Hopper/Blackwell: FP8 or NVFP4 checkpoints on vLLM / SGLang / TRT-LLM.
- If an engine already has an official quant from the model vendor or a trusted quantizer, use that and skip producing your own (choosing and downloading quants: `self-hosted-llms`, models-and-weights reference).

## Known pitfalls

- Format names collide: "Q4" in GGUF, "4.0bpw" in EXL3, "W4A16" in llm-compressor and "q4" in MLX are different encodings. Pick by engine.
- Pre-quantized checkpoints usually carry their quantization config; SGLang docs warn not to add `--quantization` for online quantization on top of an offline-quantized model. vLLM reads `quantization_config` when `--quantization` is unset.
- NVFP4 on pre-Blackwell GPUs loads but runs weight-only, so throughput gains disappear.
- MoE models: quantizers often keep router/gate layers and `lm_head` unquantized (the upstream examples `ignore` them). Keep that.

## Official links

- llama.cpp quantize: https://github.com/ggml-org/llama.cpp/tree/master/tools/quantize
- ExLlamaV3: https://github.com/turboderp-org/exllamav3
- LLM Compressor: https://github.com/vllm-project/llm-compressor
- NVIDIA Model Optimizer: https://github.com/NVIDIA/Model-Optimizer
- mlx-lm: https://github.com/ml-explore/mlx-lm
- vLLM quantization: https://docs.vllm.ai/en/latest/features/quantization/
- SGLang quantization: https://github.com/sgl-project/sglang/blob/main/docs/docs/advanced_features/quantization.mdx
- TensorRT-LLM quantization: https://github.com/NVIDIA/TensorRT-LLM/blob/main/docs/source/features/quantization.md
