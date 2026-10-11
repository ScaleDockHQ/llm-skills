# GPT-QModel: supported models and hardware

> Verified against GPT-QModel v7.5.0 and main, 2026-10-11

## Models

The README table mirrors `gptqmodel.models.auto.MODEL_MAP` (every explicit registration, including aliases). Check your model with:

```bash
jq -r .model_type ~/models/<model>/config.json
curl -s https://raw.githubusercontent.com/ModelCloud/GPTQModel/main/README.md | grep -n '`<model_type>`'
python -c "from gptqmodel.models.auto import MODEL_MAP; print(sorted(MODEL_MAP)[:20])"
```

Families registered at the time of writing include (not exhaustive): Llama 1-4, Mistral/Mixtral/Mistral3/Ministral3, Qwen 1 to 3.8 (dense, MoE, Next, VL, Omni), Gemma 1-4/3n/Unified, GLM (4, 4V, 5), DeepSeek V2/V3/V3.2/V4/VL, Kimi K2/K2.5, GPT-OSS, MiniMax M2/M3-VL, Phi (including PhiMoE), Granite, OLMo 2/3/OLMoE, Nemotron (NAS, H), Cohere, ERNIE 4.5, EXAONE, Falcon, InternLM/InternVL, LFM2, SmolLM3/SmolVLM, StarCoder2, Yi, and many VLMs and OCR models. Notes from upstream:

- Qwen 3.5 registrations need Transformers 5.2.0 or newer (the install already requires 5.14+).
- New architectures land on `main` first (for example `jamba`, `smolvlm`, `granitemoe`, `intervl` were added on `main` between 2026-09-23 and 2026-10-09 for 7.6.0-dev); a release may not have them yet.
- Prism/Bonsai GGUF checkpoints load for inference through a native GGUF path, no `gguf` PyPI package needed.

Unsupported model: stop; adding one means writing a model definition (`gptqmodel/models/llama.py` is upstream's documented example with comments). Do not edit a definition to force an unknown architecture.

## Platforms

| Platform   | Device                                | Notes (README)                                                                                                        |
| ---------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Linux      | NVIDIA GPU, `Turing+` (`sm_75+`)      | Machete, Marlin, Exllama V3/V2, AWQ GEMM/GEMV, ParoQuant, GGUF CUDA/Triton, QQQ, BitBLAS, Triton, BitsAndBytes, Torch |
| Linux      | AMD GPU (`7900XT+`, ROCm 6.2+)        | Exllama V2, AWQ GEMM/GEMV, QQQ, FP8 Torch, Torch                                                                      |
| Linux      | Huawei Ascend 910B (`torch-npu`/CANN) | Native Torch kernels for GPTQ, AWQ, ParoQuant, GGUF, QQQ, EXL3                                                        |
| Linux      | Intel XPU (Arc, Datacenter Max)       | TorchFused, TorchFusedAWQ, FP8 Torch, Torch                                                                           |
| Linux      | Intel/AMD CPU (`avx`, `amx`)          | TorchFused, TorchFusedAWQ, TorchAten int4, TorchInt8, GGUF C++, BitsAndBytes, Torch                                   |
| macOS      | Apple Silicon (M1+)                   | Torch, FP8 Torch, MLX via conversion                                                                                  |
| Windows 11 | NVIDIA GPU / CPU                      | Torch                                                                                                                 |

Marlin and the JIT CUDA kernels support NVIDIA `Turing+`. The Blackwell Swordfish kernel targets `>= sm100`.

## Sizing for quantization

Quantization runs layer by layer; peak GPU memory is about one layer plus its calibration activations and Hessians, not the whole model, and `offload_to_disk` (default `True` in the dataclass) moves completed modules to disk to save host RAM. Estimate the time and memory on your model with a short dry run (`mock_quantization=True` skips heavy computation to validate loading), then record the real numbers. Multi-GPU quantization (`auto_forward_data_parallel`, VRAM strategies) is in `quantize.md`.
