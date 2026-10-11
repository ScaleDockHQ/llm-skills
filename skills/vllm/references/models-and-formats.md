# Models, checkpoints and quantization formats

> Verified against vLLM v0.31.0 (docs `models/`, `features/quantization/*`, `configuration/model_resolution.md`), NVIDIA dgx-spark-playbooks `nvidia/vllm` (main, 2026-10-08

), 2026-10-11

vLLM serves Hugging Face-format checkpoints (safetensors, `config.json` with `architectures`). It resolves the
implementation from `architectures`; the supported list is in `docs/models/supported_models.md` (generative
and pooling models, text and multimodal). If an architecture is not native, the **Transformers modeling
backend** can run encoder-only, decoder-only and MoE models, with TP/PP/EP/DP support.

Model resolution fails when `config.json` has no `architectures`, a repo uses an unknown alias, or a name is
ambiguous. Override with `--hf-overrides '{"architectures": ["GPT2LMHeadModel"]}'`. Error strings:
`Model architectures ['<arch>'] failed to be inspected` (read the log for the root cause) and
`Model architectures ['<arch>'] are not supported for now` (upgrade vLLM or use the Transformers backend).

## Getting weights

- Download first, serve from a local path: `hf download <repo>` then `vllm serve /path` (isolates download
  hangs and is required for offline or multi-node setups where every node needs the same path).
- Gated models need an accepted license and `HF_TOKEN`. Set `HF_HUB_OFFLINE=1` once weights are cached so a
  health check cannot time out mid-download.
- Mount the Hugging Face cache into containers (`-v ~/.cache/huggingface:/root/.cache/huggingface`).
- On multi-node, put weights at the same path on every node or on a shared file system. Slow network file
  systems are a common cause of load hangs; local NVMe is better.

## Format guide

| Format                                                    | How to serve                                         | Notes                                                                                                                                                                    |
| --------------------------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| BF16 / FP16 safetensors                                   | default                                              | Reference quality. `--dtype auto` follows the checkpoint.                                                                                                                |
| FP8 W8A8 (llm-compressor, compressed-tensors, vendor FP8) | auto-detected                                        | Hardware FP8 on compute capability 8.9+ (Ada, Hopper, Blackwell) and AMD MI300. Turing/Ampere run W8A16 through Marlin. About 2x smaller weights.                        |
| Online FP8 from a BF16 checkpoint                         | `--quantization fp8_per_tensor` (or `fp8_per_block`) | No calibration data; weights quantized at load. v0.31.0 replaced `quantization="fp8"` for this.                                                                          |
| NVFP4 (NVIDIA Model Optimizer, `hf_quant_config.json`)    | auto-detected; explicit `modelopt_fp4`               | Native FP4 GEMM on Blackwell; otherwise weight-only W4A16 via Marlin with a warning. Select kernels with `--linear-backend` / `--moe-backend`.                           |
| MXFP4 (gpt-oss, Quark exports)                            | auto-detected, or online `--quantization mxfp4`      | gpt-oss ships MXFP4 weights.                                                                                                                                             |
| MXFP8                                                     | `mxfp8`, `modelopt_mxfp8`                            | W8A8 needs SM100+, other GPUs use a W8A16 fallback.                                                                                                                      |
| AWQ / GPTQ (INT4)                                         | auto-detected                                        | Marlin kernels on Ampere+. AWQ is not supported on AMD GPUs; GPTQ neither (per the hardware table).                                                                      |
| bitsandbytes                                              | auto-detected                                        | Small footprint, lower speed.                                                                                                                                            |
| TorchAO, Quark (AMD), Intel Neural Compressor             | auto-detected                                        | See `docs/features/quantization/`.                                                                                                                                       |
| GGUF                                                      | `vllm serve repo:Q4_K_M --tokenizer <base-repo>`     | Highly experimental and under-optimized; moved to the out-of-tree `vllm-gguf-plugin` (`uv pip install vllm-gguf-plugin`). Prefer llama.cpp for GGUF (skill `llama-cpp`). |

Selecting kernels: `--linear-backend` selects one backend for all quantized linear layers; per-scheme
overrides use `--kernel-config '{"linear_backend_per_quant":{"nvfp4_w4a16":"humming"}}'`. NVFP4 values
include `cutlass`, `flashinfer_cutlass`, `flashinfer_cutedsl`, `flashinfer_trtllm`, `flashinfer_cudnn`,
`marlin`. For FP8 hangs with no error try `VLLM_USE_DEEP_GEMM=0` or `--linear-backend cutlass`. vLLM logs
`Selected <kernel> for <module>` at startup; read it to see what actually runs.

Producing quantized checkpoints: FP8 with llm-compressor (`references/combos/llm-compressor-fp8.md`, skill
`llm-compressor`), NVFP4 with NVIDIA Model Optimizer (skill `nvidia-modelopt`), general guidance in
`model-quantization`. Use separate Python environments for vLLM and llm-compressor.

## KV cache dtype

`--kv-cache-dtype fp8` (alias `fp8_e4m3`), `fp8_e5m2`, `nvfp4`, `nvfp4_4over6`, and others in the config
literal. CUDA 11.8+ supports fp8; ROCm supports `fp8` (e4m3). Some models (for example DeepSeek V3.2) default to
fp8 KV; set `bfloat16` to override where allowed. Numerics change, so evaluate before promoting
(skill `llm-evals`).

## Models NVIDIA validated on DGX Spark (playbook table)

From the NVIDIA `vllm` playbook (last updated 2026-06-12 in that README), all marked supported on Spark:
gpt-oss-20b and 120b (MXFP4), Gemma 4 (E2B, E4B, 26B-A4B, 31B; base and NVFP4), Nemotron-3-Nano-30B-A3B
(BF16, FP8), Nemotron-3-Nano-Omni-30B-A3B-Reasoning (BF16, FP8, NVFP4), Nemotron-3-Super-120B NVFP4,
Llama 3.1 8B (FP8, NVFP4), Llama 3.3 70B NVFP4, Qwen3 8B/14B/32B (FP8/NVFP4), Qwen2.5-VL-7B NVFP4,
Qwen3-VL embedding and reranker 2B/8B, Phi-4 multimodal and reasoning-plus (FP8, NVFP4), DiffusionGemma
26B-A4B (BF16, NVFP4). Phi-4-multimodal needs `--trust-remote-code`. NVIDIA says some models need their model
card's special flags (Nemotron-3-Nano-Omni). Gemma 4 and DiffusionGemma use custom upstream image tags
(`vllm/vllm-openai:gemma4-cu130`, `vllm/vllm-openai:gemma`); treat them as recipe-owned.

## Memory budget (rule of thumb)

```text
weights (checkpoint size) + KV = 2 x layers x kv_heads x head_dim x bytes x tokens x sequences
+ CUDA graph / activation overhead (several GB) + OS and co-resident services
```

At startup vLLM logs `GPU KV cache size: N tokens` and `Maximum concurrency for M tokens per request: Nx`.
If concurrency is below your need, add GPUs/nodes, quantize, shorten `--max-model-len`, or use an fp8 KV cache.
Hybrid (Mamba/linear-attention) models have different KV math; trust the log, not the formula.
