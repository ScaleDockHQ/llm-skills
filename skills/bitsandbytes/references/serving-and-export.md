# Saving, merging and serving bitsandbytes models

> Verified against bitsandbytes 0.50.2, Transformers bitsandbytes guide (main), vLLM docs features/quantization/bnb.md (main), 2026-10-11

## Save and push

4-bit and 8-bit models serialize with `save_pretrained` and `push_to_hub` when bitsandbytes and Transformers are recent (upstream: use the latest versions). The `quantization_config` goes into `config.json`, so loading needs no `quantization_config`. Pushing to the Hub needs the user's approval and a token in the environment, never in output.

```python
model.save_pretrained("out/model-nf4")
tok.save_pretrained("out/model-nf4")
```

## Merge a LoRA adapter

Merge into 16-bit base weights, not into the 4-bit model: load the base in bf16 (or `dequantize()` a quantized copy, accepting some loss), attach the adapter, `merge_and_unload()`, save. Then quantize the merged model with the format that fits the engine (`model-quantization`).

## vLLM

Per vLLM docs, BitsAndBytes support is provided by the out-of-tree `vllm-bnb-plugin`:

```bash
uv pip install vllm-bnb-plugin
vllm serve <pre-quantized-bnb-repo>                      # quantization inferred from config.json
vllm serve <bf16-model> --quantization bitsandbytes      # in-flight 4-bit
```

Pre-quantized checkpoints are detected from `quantization_config`; in-flight 4-bit needs `--quantization bitsandbytes`. No calibration is needed. Check the vLLM docs for feature limits with your vLLM version (parallelism, LoRA) before relying on it, and see `vllm` for engine tuning. Throughput of bnb kernels is usually below FP8 or AWQ.

## Other engines

GGUF, EXL3, AWQ and GPTQ do not read bnb checkpoints: convert from the bf16 original (`gguf-quantization`, `exl3-quantization`, `gptqmodel`, `llm-compressor`).
