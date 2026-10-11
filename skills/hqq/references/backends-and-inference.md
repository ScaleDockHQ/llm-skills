# HQQ backends and fast inference

> Verified against hqq v0.2.8.post1 (README) and the Transformers HQQ guide (main), 2026-10-11

## Native dequantization backends

```python
from hqq.core.quantize import HQQLinear, HQQBackend
HQQLinear.set_backend(HQQBackend.PYTORCH)          # default
HQQLinear.set_backend(HQQBackend.PYTORCH_COMPILE)  # compiled PyTorch
HQQLinear.set_backend(HQQBackend.ATEN)             # CUDA kernels; axis=0 only
```

The PyTorch backend suits older GPUs and PEFT or QLoRA-style training. `ATEN` is where `axis=0` runs fastest.

## Optimized inference (fused kernels)

Call after quantization:

```python
from hqq.utils.patching import prepare_for_inference
prepare_for_inference(model)                          # PyTorch backend, fullgraph torch.compile friendly, any settings
prepare_for_inference(model, backend="gemlite")       # nbits 4/2/1, compute fp16, axis=1
prepare_for_inference(model, backend="torchao_int4")  # nbits 4, compute bf16, axis=1, fast for batch size < 4
```

- These backends only work with `axis=1`, and extra group-size restrictions apply per backend.
- If the config is unsupported, HQQ falls back to the native backend without failing. Benchmark to confirm the fused path is active.
- Upstream expects about 158 tokens/s for a 4-bit Llama3-8B on an RTX 4090 (README); Transformers docs say up to about 200 tokens/s with torchao and Marlin kernels. Treat both as hardware-specific.
- Patching changes the model; save it first (`serving-and-training.md`).
- GemLite is a separate package (`pip install gemlite`).
