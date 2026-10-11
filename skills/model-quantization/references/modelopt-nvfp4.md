# NVFP4 and FP8 with NVIDIA Model Optimizer

> Verified against NVIDIA/Model-Optimizer 0.47.0 (README.md, examples/hf_ptq/README.md, examples/hf_ptq/hf_ptq.py, modelopt_recipes/), vLLM v0.31.0 (docs/features/quantization/modelopt.md), SGLang v0.5.21 (quantization docs), TensorRT-LLM v1.2.1, 2026-10-11

## What it is and when to choose it

[NVIDIA Model Optimizer](https://github.com/NVIDIA/Model-Optimizer) ("ModelOpt", PyPI `nvidia-modelopt`; formerly `NVIDIA/TensorRT-Model-Optimizer`, which now redirects) does post-training quantization (PTQ), QAT, pruning and distillation. Its `examples/hf_ptq/hf_ptq.py` script quantizes a Hugging Face model and exports a **unified HF checkpoint** (`hf_quant_config.json` + safetensors) that TensorRT-LLM, vLLM and SGLang load.

Choose it when:

- The target is TensorRT-LLM (its documented quantization path).
- You want NVFP4 for Blackwell (B200/GB200, RTX PRO/50-series, DGX Spark GB10) or FP8 for Hopper/Ada, with NVIDIA's recipes (MLP-only / experts-only NVFP4, FP8 or NVFP4 KV cache).
- You want parity with NVIDIA's published `nvidia/*-FP8` / `*-NVFP4` checkpoints.

For vLLM-first workflows, `llm-compressor.md` produces equivalent schemes in compressed-tensors; either works.

ModelOpt's README states NVFP4 inference requires Blackwell GPUs (and TensorRT-LLM v1.2 or later for TRT-LLM). Calibration itself runs on any supported CUDA GPU.

## Install

x86_64 or DGX Spark (arm64), in a venv with a CUDA PyTorch:

```bash
python3 -m venv ~/venvs/modelopt && . ~/venvs/modelopt/bin/activate
pip install -U "nvidia-modelopt[hf]"
git clone https://github.com/NVIDIA/Model-Optimizer ~/src/Model-Optimizer
cd ~/src/Model-Optimizer && git checkout <release-tag>
pip install -r examples/hf_ptq/requirements.txt
```

Or use an NVIDIA container that ships ModelOpt (`nvcr.io/nvidia/tensorrt-llm/release:<version>`, `nvcr.io/nvidia/pytorch:<version>-py3`, `nvcr.io/nvidia/nemo:<version>`) and upgrade `nvidia-modelopt` inside it. Which container tags have arm64 builds for DGX Spark is (unverified) here: check the NGC catalog.

## Minimal working config/command

```bash
cd ~/src/Model-Optimizer/examples/hf_ptq

# NVFP4 weights+activations, FP8 KV cache (default kv format is fp8_cast)
systemd-run --user --scope -p MemoryMax=100G -p MemorySwapMax=0 -- \
  python hf_ptq.py --pyt_ckpt_path ~/models/<model> --qformat nvfp4 \
    --export_path ~/models/<model>-NVFP4

# FP8
python hf_ptq.py --pyt_ckpt_path ~/models/<model> --qformat fp8 \
  --kv_cache_qformat fp8_cast --export_path ~/models/<model>-FP8

# Recipe instead of --qformat (recipe wins over --qformat)
python hf_ptq.py --pyt_ckpt_path ~/models/<model> \
  --recipe general/ptq/nvfp4_default-kv_fp8_cast --export_path ~/models/<model>-NVFP4
```

Wrapper script alternative: `scripts/huggingface_example.sh --model <path> --quant nvfp4 --tp 1`.

### hf_ptq.py arguments (0.47.0)

| Arg                                                              | Default          | Meaning                                                                                        |
| ---------------------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------- |
| `--pyt_ckpt_path` / `--model`                                    | required         | Local path or Hub id                                                                           |
| `--qformat`                                                      | `fp8`            | Preset name from `modelopt_recipes/configs/ptq/presets/model/`                                 |
| `--recipe`                                                       | none             | PTQ / AutoQuantize recipe name or YAML path; overrides `--qformat`                             |
| `--kv_cache_qformat`                                             | `fp8_cast`       | `none`, `fp8`, `fp8_affine`, `fp8_cast`, `nvfp4`, `nvfp4_affine`, `nvfp4_cast`, `nvfp4_rotate` |
| `--export_path`                                                  | `exported_model` | Output dir                                                                                     |
| `--calib_size`                                                   | `1024`           | Calibration samples (comma list per dataset)                                                   |
| `--calib_seq`                                                    | `512`            | Max calibration sequence length                                                                |
| `--batch_size`                                                   | `0` (auto)       | Calibration batch size                                                                         |
| `--dataset`                                                      | none             | Calibration dataset name(s); `--help` lists choices                                            |
| `--trust_remote_code`                                            | off              | For custom-code models                                                                         |
| `--low_memory_mode`                                              | off              | Compress weights before calibration (FP8 / NVFP4 with max calibration only)                    |
| `--use_seq_device_map`, `--gpu_max_mem_percentage`               | off, 80%         | Sequential device map to avoid GPU OOM                                                         |
| `--offload_folder`, `--max_cpu_memory_gb`, `--max_gpu_memory_gb` | none             | Disk offload with RAM/GPU budgets (not with `--low_memory_mode`)                               |
| `--inference_tensor_parallel`                                    | `1`              | TP size baked into export                                                                      |
| `--cast_mxfp4_to_nvfp4`                                          | off              | Bit-exact MXFP4 -> NVFP4 for gpt-oss style checkpoints                                         |

`--qformat` presets include `fp8`, `fp8_per_channel_per_token`, `fp8_2d_blockwise_weight_only`, `int4_awq`, `int8_smoothquant`, `w4a8_awq_beta`, `nvfp4`, `nvfp4_awq_lite`, `nvfp4_mlp_only`, `nvfp4_experts_only`, `nvfp4_omlp_only`, `w4a16_nvfp4`, `w4a8_nvfp4_fp8`, `mxfp8`.

## How it plugs into the stack

- In: HF checkpoint. Out: unified HF checkpoint dir with `hf_quant_config.json`.
- vLLM: detects ModelOpt via `hf_quant_config.json`; NVFP4 uses `modelopt_fp4`, FP8 uses `modelopt`:
  ```bash
  vllm serve ~/models/<model>-NVFP4 --quantization modelopt_fp4 --host 127.0.0.1 --port 8000
  vllm serve ~/models/<model>-FP8 --quantization modelopt --host 127.0.0.1 --port 8000
  ```
  On GPUs without a native FP4 GEMM, vLLM falls back to weight-only W4A16 (Marlin) and logs a warning.
- SGLang:
  ```bash
  python3 -m sglang.launch_server --model-path ~/models/<model>-NVFP4 --quantization modelopt_fp4 --port 30000
  ```
  SGLang documents native FP4 on Blackwell SM100/SM103 and a Marlin W4A16 fallback on Ampere/Hopper.
- TensorRT-LLM: `trtllm-serve ~/models/<model>-NVFP4 --host 127.0.0.1 --port 8000`. TRT-LLM's support table lists NVFP4 on sm100/103 and sm120.

## Operating

- Calibration is GPU-heavy and loads the full BF16 model; on a DGX Spark stop serving models first and cap the scope.
- The export writes ModelOpt version info; still record the ModelOpt tag, qformat/recipe, KV format, calib dataset/size/seq in the model card.
- Smoke-test in the exact engine you will serve with; vLLM, SGLang and TRT-LLM have different kernel coverage per architecture.

## Tuning knobs worth knowing

- Accuracy-first NVFP4: upstream recommends `nvfp4_mlp_only`, `nvfp4_experts_only` or `nvfp4_omlp_only`, which keep attention QKV in higher precision.
- KV cache: `--kv_cache_qformat none` if long-context quality drops; `fp8_cast` sets scales without data calibration.
- Larger `--calib_size` / `--calib_seq` for long-context or reasoning models (costs time).
- AutoQuantize recipes (`general/auto_quantize/...`) search per-layer formats to hit an effective bit budget.

## Known pitfalls

- NVFP4 on Hopper/Ada/Ampere loads but runs weight-only; no speedup over INT4.
- GB10 (DGX Spark) reports compute capability 12.1 (check with `nvidia-smi --query-gpu=compute_cap --format=csv`); engine kernel tables name sm100/103/120, so native FP4 GEMM on sm121 in a given engine build is (unverified). Read the engine's startup log for the selected GEMM backend.
- Multi-GPU calibration with mismatched placement: set `CUDA_VISIBLE_DEVICES` to fewer GPUs or use `--use_seq_device_map`.
- `--export_fmt` is deprecated; do not use it.
- Model support is per architecture; check ModelOpt's support matrix before a long run.

## Official links

- Repo: https://github.com/NVIDIA/Model-Optimizer
- hf_ptq example: https://github.com/NVIDIA/Model-Optimizer/tree/main/examples/hf_ptq
- Docs: https://nvidia.github.io/Model-Optimizer/
- Unified HF checkpoint deployment matrix: https://nvidia.github.io/Model-Optimizer/deployment/3_unified_hf.html
- vLLM ModelOpt docs: https://docs.vllm.ai/en/latest/features/quantization/modelopt/
- TensorRT-LLM quantization: https://github.com/NVIDIA/TensorRT-LLM/blob/main/docs/source/features/quantization.md
