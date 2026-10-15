# Export and deployment (TensorRT-LLM, vLLM, SGLang)

> Verified against NVIDIA Model Optimizer 0.47.0 (examples/hf_ptq/README.md, docs/source/deployment/3_unified_hf.rst), vLLM v0.31.0 (docs/features/quantization/modelopt.md, modelopt.py), SGLang v0.5.21 (docs/docs/advanced_features/quantization.mdx), TensorRT-LLM v1.2.1 (docs/source/features/quantization.md, docs/source/commands/trtllm-serve/trtllm-serve.rst), 2026-10-11

## The unified Hugging Face checkpoint

`hf_ptq.py` exports a unified checkpoint: layer structure and tensor names stay aligned with the original Hugging Face checkpoint, so the same directory deploys on TensorRT-LLM (PyTorch and C++ backends), vLLM and SGLang without changes. It contains:

1. safetensors files with quantized weights and scaling factors;
2. `hf_quant_config.json` with the quantization configuration (`quantization.quant_algo`, KV cache algo, group size, excluded modules);
3. the usual `config.json`, tokenizer files and metadata.

Python API behind it (also usable in your own script):

```python
import torch
import modelopt.torch.quantization as mtq
from modelopt.torch.export import export_hf_checkpoint

model = mtq.quantize(model, mtq.NVFP4_DEFAULT_CFG, forward_loop)   # calibration loop of your own
with torch.inference_mode():
    export_hf_checkpoint(model, export_dir)
```

Supported formats in the unified export (3_unified_hf.rst): FP8, FP8_PB (per-block), NVFP4, NVFP4_AWQ, INT4_AWQ, W4A8_AWQ. Unified export does not support sparsity; speculative decoding is supported only in the unified export.

Inspect an export with `scripts/inspect-checkpoint.sh <dir>`.

## Minimum engine versions (upstream's stated oldest versions)

| Engine       | Minimum |
| ------------ | ------- |
| TensorRT-LLM | v1.2.0  |
| vLLM         | v0.10.1 |
| SGLang       | v0.4.10 |

These are the oldest versions "expected to load a unified HF checkpoint"; the upstream deployment suite targets newer ones. Use the latest stable engine release for new model families. ModelOpt's per-model deployment matrix is at https://nvidia.github.io/Model-Optimizer/deployment/3_unified_hf.html#model-support-matrix. It is a release suite of load-and-generate smoke checks on the text path, not PR-gated, not accuracy or multimodal verification, and "unlisted models frequently deploy without any modelopt change".

## vLLM

vLLM detects ModelOpt checkpoints through `hf_quant_config.json` and picks the method itself (`override_quantization_method` in v0.31.0), so `--quantization` is optional. Method names registered in v0.31.0: `modelopt` (FP8 family), `modelopt_fp4` (NVFP4, W4A16_NVFP4), `modelopt_mxfp8`, `modelopt_mixed` (`MIXED_PRECISION` checkpoints). Supported `quant_algo` values per vLLM's doc: `FP8`, `FP8_PER_CHANNEL_PER_TOKEN`, `FP8_PB_WO`, `NVFP4`, `W4A16_NVFP4`, `MXFP8`.

```bash
vllm serve ~/models/<model>-NVFP4 --host 127.0.0.1 --port 8000 --served-model-name <model>-nvfp4
vllm serve ~/models/<model>-FP8   --host 127.0.0.1 --port 8000 --quantization modelopt   # explicit form from vLLM's doc
curl -s http://127.0.0.1:8000/health; curl -s http://127.0.0.1:8000/v1/models | jq -r '.data[].id'
```

NVFP4 kernel selection (vLLM doc): chosen at load time from the available backends (CUTLASS, FlashInfer, Marlin, others). On GPUs without a supported native FP4 GEMM vLLM falls back to weight-only W4A16 through Marlin and logs a warning, which may reduce throughput on compute-heavy workloads. Override with `--linear-backend` (replaces the deprecated `VLLM_NVFP4_GEMM_BACKEND`); NVFP4 values include `cutlass`, `flashinfer_cutlass`, `flashinfer_cutedsl`, `flashinfer_trtllm`, `flashinfer_cudnn`, `marlin`; list them with `vllm serve --help=KernelConfig`. For `W4A16_NVFP4`, `auto` currently selects Marlin. MXFP8 with BF16 activations on SM100-family GPUs: `--linear-backend flashinfer_trtllm`.

Engine tuning belongs to the `vllm` skill (`npx skills add ScaleDockHQ/llm-skills --skill vllm`). Python API: `LLM(model=..., quantization="modelopt")`.

## SGLang

SGLang's quantization doc lists `modelopt` / `modelopt_fp8` for FP8 and `modelopt_fp4` for NVFP4 (Marlin W4A16 fallback on SM80 to SM90, native FP4 on SM100 and newer, requires NVIDIA hardware):

```bash
python3 -m sglang.launch_server --model-path ~/models/<model>-NVFP4 --quantization modelopt_fp4 --host 127.0.0.1 --port 30000
python3 -m sglang.launch_server --model-path ~/models/<model>-FP8   --quantization modelopt_fp8 --host 127.0.0.1 --port 30000
```

ModelOpt's own README uses `sgl.Engine(model_path=..., quantization="modelopt")`. SGLang also documents an online path (apply ModelOpt quantization at startup: high startup time and extra VRAM risk) and an example `examples/usage/modelopt_quantize_and_export.py` in its repo; prefer the offline checkpoint. FP4 and FP8 GEMM backends are selectable with `--fp4-gemm-backend` and `--fp8-gemm-backend`; on SM80 to SM90 `auto` picks Marlin for NVFP4. Tuning: `sglang` skill (`npx skills add ScaleDockHQ/llm-skills --skill sglang`).

## TensorRT-LLM

```bash
trtllm-serve ~/models/<model>-NVFP4 --host 127.0.0.1 --port 8000
curl -s http://127.0.0.1:8000/health; curl -s http://127.0.0.1:8000/v1/models | jq -r '.data[].id'
```

or Python: `from tensorrt_llm import LLM; LLM(model="<export dir>")`. `trtllm-serve <model> [--tp_size N --pp_size N --ep_size N --host H --port P]` starts an OpenAI-compatible server with `/v1/models`, `/v1/completions`, `/v1/chat/completions`, `/health`, `/metrics`, `/version`.

TensorRT-LLM's PyTorch backend supports FP4 and FP8 on Blackwell and Hopper; its hardware matrix (v1.2.1) shows NVFP4 on Blackwell sm120 and sm100/103, FP8 on Hopper and Ada, W4A16 AWQ on Ampere. KV cache dtype can be set at load: `LLM(model=..., kv_cache_config=KvCacheConfig(dtype='fp8'))` (or `'nvfp4'` after offline ModelOpt quantization with an NVFP4 KV cache). DGX Spark support is listed as beta in the 1.2.1 release notes. Tuning: `tensorrt-llm` skill (`npx skills add ScaleDockHQ/llm-skills --skill tensorrt-llm`).

Legacy (C++ backend only): `export_tensorrt_llm_checkpoint(model, decoder_type, dtype, export_dir, inference_tensor_parallel, inference_pipeline_parallel, use_nfs_workspace)` then `trtllm-build` to build engines; prefer the unified checkpoint.

## Verify before declaring done

1. `/health` and `/v1/models` respond, and the model id is the one you expect.
2. The startup log names the quantization method and GEMM backend you intended (not an unexpected weight-only fallback).
3. Smoke prompts return sane text with `finish_reason` `stop` (`model-quantization`, quality-checks reference).
4. Same prompts and an eval on the base model for comparison (`llm-evals`).
5. Record ModelOpt version and tag, qformat or recipe, KV format, calibration dataset, size and sequence length, the engine and its version.

## Pre-quantized checkpoints

NVIDIA publishes ready-to-deploy ModelOpt checkpoints (`nvidia/*-FP8`, `*-NVFP4`) in the Hugging Face collection linked from the upstream README: https://huggingface.co/collections/nvidia/inference-optimized-checkpoints-with-model-optimizer. Check them first before spending GPU hours (`self-hosted-llms`).
