# Saving and serving torchao models

> Verified against torchao v0.18.0 (docs eager_tutorials serving, serialization, vLLM integration), vLLM docs features/quantization/torchao.md (main), 2026-10-11

## Save

- Transformers: `model.save_pretrained(dir)` or `push_to_hub`; the torchao config is written to `config.json`. vLLM's doc example pushes with `safe_serialization=False`; check whether your Transformers version supports safetensors for torchao tensors before choosing.
- Plain PyTorch: `torch.save(model.state_dict(), path)`. Load by building the float model on the `meta` device and `load_state_dict(sd, assign=True)`, because the weights are tensor subclasses.
- Quantized weights are subclass tensors; compare file size with `torchao.utils.get_model_size_in_bytes`.
- The `config.json` records the quantization as `quant_type` with `_type` (for example `Int4WeightOnlyConfig`) and `_data` (its arguments).
- A no-code option: the `medmekk/TorchAO_Quantization` Hugging Face Space (linked from the vLLM docs).

## vLLM

vLLM uses torchao kernels for checkpoints quantized with torchao. Upstream README example (1xH100):

```bash
VLLM_DISABLE_COMPILE_CACHE=1 vllm serve pytorch/Qwen3-32B-FP8 --tokenizer Qwen/Qwen3-32B -O3
```

Published checkpoints live under https://huggingface.co/pytorch. Upstream reports for float8 dynamic on H100: 36% VRAM reduction and 1.15x to 1.2x speed-up with little accuracy impact (Phi-4-mini example). vLLM docs recommend a recent torchao nightly for newest features. Pin the vLLM and torchao pair that you tested; engine tuning belongs to `vllm`.

## Transformers inference

`AutoModelForCausalLM.from_pretrained("pytorch/Phi-4-mini-instruct-float8dq", device_map="auto", dtype="auto")` loads a published checkpoint without any `quantization_config`.

## ExecuTorch (mobile)

The 8da4w scheme (`Int8DynamicActivationIntxWeightConfig` with int4 weights) targets ExecuTorch. Tied embedding and `lm_head` can be untied first so they get different configs (`IntxWeightOnlyConfig` for embeddings); the serving tutorial lists the steps. Optionally fine-tune with QAT before lowering.

## SGLang

The serving tutorial marks SGLang as coming soon; the README reports GemLite and SGLang integration for int4 and float8. Check SGLang's docs before relying on it (`sglang`).
