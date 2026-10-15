# MLX LoRA to GGUF (mlx-lm fuse export)

> Verified against mlx-lm 0.32.0 (mlx_lm/fuse.py, mlx_lm/LORA.md, mlx_lm/gguf.py on main), 2026-10-11

Loading the produced GGUF in llama.cpp or Ollama was **not tested** here.

Goal: train a LoRA on a Mac with `mlx_lm.lora`, merge it, and get a single GGUF file for llama.cpp or Ollama.

## What upstream supports

`mlx_lm.fuse --export-gguf` merges the adapter and writes `fused_model/ggml-model-f16.gguf` (name via `--gguf-path`). Limits:

- LORA.md: "GGUF support is limited to Mistral, Mixtral, and Llama style models in fp16 precision."
- `fuse.py` raises `ValueError: Model type <x> not supported for GGUF conversion.` unless the config's `model_type` is `llama`, `mixtral` or `mistral`. Qwen, Gemma, Phi and others fail.
- The writer emits llama-architecture metadata, so it is not a general converter.

## Steps (supported model types only)

```bash
# 1. Train on a full-precision (not quantized) base so the merge stays fp16
mlx_lm.lora --model <org>/<llama-or-mistral-model> --train --data ./data --iters 600 --adapter-path ./adapters

# 2. Fuse and export (writes a new directory; no upload)
mlx_lm.fuse --model <org>/<llama-or-mistral-model> --adapter-path ./adapters \
  --save-path ./fused_model --export-gguf --gguf-path ggml-model-f16.gguf

# 3. Check the file before sharing it
ls -lh ./fused_model/ggml-model-f16.gguf
llama-cli -m ./fused_model/ggml-model-f16.gguf -p "Hello" -n 32     # llama-cpp skill; confirms it loads
```

If you trained QLoRA (quantized base), fuse with `--dequantize` first, which restores fp16 weights at full size; quality is that of the quantized base. Quantize the GGUF afterwards with llama.cpp's `llama-quantize` (`model-quantization` skill: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`).

## Not covered by this route

- Other architectures (Qwen, Gemma, ...): there is no mlx-lm export. Use a Hugging Face PEFT/TRL adapter and llama.cpp's own conversion instead (`fine-tuning-llms` skill: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`, which also covers serving adapters).
- Serving an MLX adapter directly needs no GGUF: `mlx_lm.server --model <base> --adapter-path ./adapters` (`serving.md`).
- Upload: `mlx_lm.fuse --upload-repo` pushes to the Hub; ask first.

## Pitfalls

- Fusing into a model that differs from the one you trained on corrupts output; use the identical `--model`.
- `--export-gguf` is fp16 only, so the file is about 2 bytes per parameter; check disk space.
- Chat templates travel with the tokenizer metadata only to the extent the exporter writes them (unverified): test a chat prompt in llama.cpp (`--jinja`) before relying on it.

## Official links

- https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md#fuse
- https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/fuse.py
