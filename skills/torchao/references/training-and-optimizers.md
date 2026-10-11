# Quantized training and optimizers

> Verified against torchao v0.18.0 (docs workflows/training.md, torchao/optim/README.md, README, release notes), 2026-10-11

## Float8 training (stable)

For `torch.nn.Linear` layers; forward and backward matmuls run in float8. Needs `torch.compile`, bf16 model, and a float8-capable GPU (H100, B200, AMD supported). Upstream: up to 1.5x pretraining throughput at 512 GPU, 405B scale; about 1.25x at 8 GPU, 8B scale (torchtitan Llama3-8B on H100: tensorwise 25%, rowwise 10% over bf16).

```python
from torchao.float8 import convert_to_float8_training
convert_to_float8_training(model)       # then torch.compile(model) and train
```

Recipes: `tensorwise` (fastest), `rowwise`, `rowwise_with_gw_hp` (most accurate). Rowwise handles outliers better. Speed-ups grow with GEMM size (M, K, N); small models may not gain. FSDP2 composes with float8 all-gather; torchtitan has the integration (`docs/float8.md`).

## Prototype training workflows

- mxfp8 dense Linear (`torchao.prototype.mx_formats`), mxfp8 MoE (`torchao.prototype.moe_training`), int8 (`torchao.prototype.quantized_training`).
- NVFP4 dense Linear training, new in 0.18.0, Blackwell (SM100+), bf16 model with Linear dims divisible by 128: `quantize_(model, NVFP4TrainingConfig())` from `torchao.prototype.moe_training.nvfp4_training.nvfp4_training`. Upstream flags the API as changeable without notice.

Pin the torchao version and say the workflow is prototype in any output.

## Low-bit optimizers

```python
from torchao.optim import AdamW8bit        # also AdamW4bit, AdamWFp8, Adam8bit, Adam4bit, AdamFp8
optim = AdamW8bit(model.parameters())
```

- Drop-in for `torch.optim.Adam(W)`. Implemented in Python with tensor subclasses and relies on `torch.compile` for fused kernels, so the platform must support compile.
- Default block size 256 (8-bit, FP8) and 128 (4-bit); change with `block_size=`.
- FP8 optimizers need compute capability 8.9+ on CUDA. Tested only on CPU and CUDA.
- Upstream Llama2-7B bf16 fine-tune on A100: fused AdamW 51.6 GB, ao 8-bit 39.1 GB, ao 4-bit 33.2 GB, bnb 8-bit 39.3 GB, with similar throughput.
- BF16 weight stochastic rounding (experimental) helps full-bf16 training when updates underflow.
- CPU offload for single GPU: `CPUOffloadOptimizer(model.parameters(), torch.optim.AdamW, fused=True)` moves optimizer state and gradients to CPU; upstream claims about 60% VRAM reduction with minor throughput impact.

For the bitsandbytes equivalent see the `bitsandbytes` skill.
