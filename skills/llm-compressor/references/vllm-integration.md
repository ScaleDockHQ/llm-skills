# Serving LLM Compressor checkpoints with vLLM

> Verified against vLLM v0.31.0 (docs/features/quantization/README.md, llm_compressor/README.md, llm_compressor/fp8.md, quantized_kvcache.md, quantization/**init**.py, compressed_tensors.py), llm-compressor 0.14.0 (docs/steps/deploy.md, docs/faq/faq.md), compressed-tensors 0.19.0, SGLang v0.5.21 (docs/docs/advanced_features/quantization.mdx), 2026-10-11

vLLM is the supported and tested runtime for LLM Compressor output (upstream FAQ). Install vLLM in its own venv or container, not in the venv that holds `llmcompressor` (`install.md`).

## Serve

vLLM reads the `quantization_config` in `config.json` and picks the compressed-tensors method itself, so `--quantization` is not required. Passing `--quantization compressed-tensors` is a valid explicit value (registered method name in vLLM v0.31.0).

```bash
vllm serve ~/models/<model>-FP8-Dynamic \
  --served-model-name <model>-fp8 \
  --host 127.0.0.1 --port 8000 \
  --max-model-len 8192 --gpu-memory-utilization 0.85

curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/v1/models | jq -r '.data[].id'
jq -n '{model:"<model>-fp8",messages:[{role:"user",content:"Reply with exactly: OK"}],max_tokens:20,temperature:0}' |
  curl -s http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' -d @- |
  jq -r '.choices[0].message.content'
```

The default port is 8000 on localhost, changed with `--host` and `--port` (upstream deploy guide). Use `vllm serve --help` for the flags of your installed version before adding others; engine tuning belongs to the `vllm` skill (`npx skills add ScaleDockHQ/llm-skills --skill vllm`).

Python API from upstream's guide:

```python
from vllm import LLM, SamplingParams
model = LLM("<dir-or-hub-id>")
print(model.generate("What is machine learning?", SamplingParams(max_tokens=256))[0].outputs[0].text)
```

## Check what vLLM actually does

Read the startup log, not just "it loaded".

- FP8: vLLM logs a `Selected <kernel> for <module>` line at startup. For block-quantized checkpoints on CUDA it tries, in order, a FlashInfer/DeepGEMM hybrid (Hopper only), DeepGEMM, CUTLASS, Marlin, Triton, Humming, then a PyTorch fallback. GPUs without native FP8 (Turing, Ampere) land on weight-only W8A16 Marlin.
- FP8 compute needs compute capability 8.9 or newer; models still run on 7.5 or newer as weight-only through FP8 Marlin (vLLM FP8 docs).
- If inference hangs with no error, vLLM's docs suggest `VLLM_USE_DEEP_GEMM=0` or `--linear-backend cutlass`.
- `--linear-backend` affects only quantized linear layers; MoE experts use `--moe-backend`. An explicit backend unsupported on your hardware raises an error instead of falling back. `vllm serve --help=KernelConfig` lists the values.
- NVFP4 without a native FP4 GEMM (anything below Blackwell SM100) runs weight-only (W4A16) through Marlin and logs a warning, so expect memory savings, not speed (this is vLLM's NVFP4 behaviour documented for ModelOpt checkpoints; the compressed-tensors NVFP4 path was not separately verified).
- Mismatched hardware and scheme (for example `W4AFP8` on Ampere) fails at load or is slow: check the scheme table in `recipes.md`.

## KV cache

- No calibration: `--kv-cache-dtype fp8` (all scales 1.0).
- Calibrated (recommended by vLLM's docs): quantize the KV cache with LLM Compressor (`recipes.md`), then serve; scales are stored in the checkpoint. Per-attention-head scales work only with the Flash Attention backend and need LLM Compressor's calibration.
- `--kv-cache-dtype-skip-layers` keeps listed layers (indices or `sliding_window`) in the native dtype.
- Choices and trade-offs: the `kv-cache-quantization` skill (`npx skills add ScaleDockHQ/llm-skills --skill kv-cache-quantization`).

## Evaluate

Compare the quant with its base on the same data through the same endpoint (`model-quantization`, quality-checks reference; `llm-evals`). Upstream's vLLM guide evaluates with `lm-eval[api]>=0.4.12` installed in the vLLM venv.

## SGLang and others

Upstream's FAQ: SGLang has "minimal support" for compressed-tensors models that the LLM Compressor team does not maintain or test, and much of it relies on vLLM; vLLM is recommended. SGLang's own table lists `compressed-tensors` as supported with partial coverage on some hardware. If you must use SGLang, run the smoke prompts and read its startup log. Checkpoints made with plain transformers loading run decompressed with no speedup (upstream FAQ 1).

## Version skew

A checkpoint made with a newer compressed-tensors may need a newer vLLM. Record `pip show llmcompressor compressed-tensors transformers torch` next to the checkpoint and the `vllm --version` used for the smoke test. vLLM v0.31.0's FP8 doc recommends separate environments for vLLM and llm-compressor.
