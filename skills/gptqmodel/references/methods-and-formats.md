# GPT-QModel: methods, formats and kernels

> Verified against GPT-QModel v7.5.0 and main, 2026-10-11

One lifecycle for every method: calibrate, quantize, validate, save, load, serve. Concrete config classes: `GPTQConfig`, `AWQConfig`, `ParoConfig`, `QQQConfig`, `RTNConfig`, `GGUFConfig`, `FP8Config`, `BitsAndBytesConfig`, `EXL3Config`; `QuantizeConfig` is the broad factory.

## Methods and what they need

| Method             | Calibration                 | Saved formats                                               | Use it when                                                                                                        |
| ------------------ | --------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `GPTQ`             | yes (Hessians)              | `gptq`, `gptq_v2`, `gptq_p` (planar), `marlin`, `bitblas`   | The default 4-bit weight-only path for vLLM, SGLang, Transformers                                                  |
| `AWQ`              | yes (scale and clip search) | `gemm`, `gemv`, `gemv_fast`, `llm-awq`, `marlin`, `bitblas` | AWQ checkpoints; `gemm` is the default format                                                                      |
| `PARO` (ParoQuant) | yes                         | `paroquant`                                                 | Pairwise-rotation 4-bit; native GPT-QModel path (not in vLLM/SGLang/Transformers per the README table)             |
| `QQQ`              | yes                         | `qqq`                                                       | Meituan W4A8 style; native path                                                                                    |
| `GGUF`             | no: `calibration=None`      | `gguf`                                                      | Weight-only GGUF tensors from Python; for llama.cpp pipelines use `gguf-quantization`                              |
| `FP8`              | no: `calibration=None`      | `fp8`                                                       | Weight-only FP8 (`float8_e4m3fn` or `float8_e5m2`)                                                                 |
| `EXL3`             | yes                         | `exl3`                                                      | EXL3 through `EXL3Config` (`bits`, `head_bits`, `codebook`); for ExLlamaV3's own converter use `exl3-quantization` |
| `BITSANDBYTES`     | no                          | `bitsandbytes`                                              | bitsandbytes-format weights                                                                                        |
| RTN                | no                          |                                                             | Round-to-nearest weight-only baseline, also used as the low-sample fallback                                        |

Upstream: `GGUF`, `FP8`, `EXL3` and `ParoQuant` are native GPT-QModel paths, not loadable in Transformers/vLLM/SGLang through this library's table. The README's compatibility table also marks GPTQ, AWQ, EoRA, GAR, GPTAQ and FOEM as working with Transformers, vLLM, SGLang and LoRA training. SGLang loading is limited to GPTQ with `gptq`, `gptq_v2` or `marlin`, and AWQ with `gemm` or `marlin`.

## Choosing

1. **Serving on vLLM/SGLang/Transformers:** GPTQ 4-bit, `group_size=128`, `sym=True` (the dataclass defaults are `bits=4`, `group_size=128`, `sym=True`), saved as `gptq` and let the engine pick Marlin on NVIDIA. AWQ `gemm` is the alternative.
2. **Max throughput on NVIDIA:** `marlin` formats or the Marlin/Machete/Swordfish kernels (Swordfish targets Blackwell `>= sm100`; its kernel sources are AGPL-3.0-or-later per upstream).
3. **Accuracy first:** larger `bits`/smaller `group_size`; `desc_act` or group-aware reordering (`act_group_aware`); see `quantize.md`.
4. **No calibration data or a quick artifact:** FP8 or GGUF weight-only.
5. **Apple Silicon:** `GPTQModel.quantize_mlx(...)` writes an MLX-LM checkpoint (`quantize.md`).

## Backends (kernels)

Pass `backend=BACKEND.<NAME>` to `load()`/`quantize()`; `BACKEND.AUTO` (default) picks one. Canonical names from the README matrix:

- GPTQ `gptq`: `GPTQ_TORCH_ATEN`, `GPTQ_MACHETE`, `GPTQ_MARLIN`, `GPTQ_EXLLAMA_V2`, `GPTQ_TORCH_FUSED`, `GPTQ_TRITON`, `GPTQ_BITBLAS`, `GPTQ_TORCH`, `GPTQ_TORCH_INT8`; `gptq_v2` has the same set minus Machete and Marlin; `marlin` format uses `GPTQ_MARLIN`; `bitblas` uses `GPTQ_BITBLAS`.
- AWQ: `AWQ_TORCH_ATEN`, `AWQ_MACHETE`, `AWQ_MARLIN`, `AWQ_EXLLAMA_V2`, `AWQ_GEMM`, `AWQ_GEMM_TRITON`, `AWQ_TORCH_FUSED`, `AWQ_TORCH`, `AWQ_TORCH_INT8`, `AWQ_BITBLAS` for `gemm`; `AWQ_GEMV` for `gemv`; `AWQ_GEMV_FAST` for `gemv_fast` and `llm-awq`.
- `PAROQUANT_CUDA`, `PAROQUANT_TRITON`; `QQQ`, `QQQ_TORCH`; `GGUF_TRITON`, `GGUF_CPP_CUDA`, `GGUF_CPP_CPU`, `GGUF_TORCH`; `FP8_TORCH`; `BITSANDBYTES`; `EXL3_EXLLAMA_V3`, `EXL3_TORCH`.
- External runtimes `BACKEND.VLLM`, `BACKEND.SGLANG`, `BACKEND.MLX` are not part of the native kernel matrix.

Hardware determines availability (`models-and-hardware.md`). Prefer `AUTO` unless benchmarking; an explicit backend that does not fit the format or hardware is expected to fail at load ((unverified) exact error).

## Experimental: W4A on GB10

Experimental "W4A" keeps GPTQ INT4 weights and quantizes activations (FP8 E4M3 or NVFP4) on NVIDIA GB10 (SM121) for Llama decoder models only, with `bits=4`, `group_size=128`, `sym=True`, `desc_act=False`, `pack_dtype="int32"`, `lm_head=False` and Triton. See upstream `docs/gptq-w4a-gb10.md`. Upstream's measured result: `w4afp8` matches W4A16 within noise; the balanced NVFP4-MLP/FP8-attention setup costs about 2.3 percentage points on full GSM8K Platinum. Treat as research.
